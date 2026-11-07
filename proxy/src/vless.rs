//! VLESS over TCP, with the Vision framing the server's flow asks for.
use crate::crypto::random;
use crate::reality::{self, Reader, Settings, Writer};
use std::ffi::{c_int, c_void};
use std::io::{self, Error, ErrorKind};
use std::net::{SocketAddrV4, TcpStream};
use std::os::fd::{FromRawFd, RawFd};

extern "C" {
    fn socket(domain: c_int, kind: c_int, protocol: c_int) -> c_int;
    fn setsockopt(fd: c_int, level: c_int, name: c_int, value: *const c_void, len: u32) -> c_int;
    fn connect(fd: c_int, addr: *const c_void, len: u32) -> c_int;
}

/// nftables leaves sockets with this mark alone, so the way to the server does not loop.
pub const MARK: u32 = 0x464c;
const AF_INET: c_int = 2;
const SOCK_STREAM_CLOEXEC: c_int = 1 | 0o2000000;
const SOL_SOCKET: c_int = 1;
const SO_MARK: c_int = 36;
const SO_SNDTIMEO: c_int = 21;
const CONNECT_TIMEOUT_SECS: i64 = 10;

pub struct Link {
    pub server: SocketAddrV4,
    pub uuid: [u8; 16],
    pub vision: bool,
    pub reality: Settings,
    /// Without privileges there is no mark, which is only fine when testing with `forward`.
    pub marked: bool,
}

fn open_socket(addr: SocketAddrV4, marked: bool) -> io::Result<TcpStream> {
    unsafe {
        let fd: RawFd = socket(AF_INET, SOCK_STREAM_CLOEXEC, 0);
        if fd < 0 {
            return Err(Error::last_os_error());
        }
        let stream = TcpStream::from_raw_fd(fd);
        if marked && setsockopt(fd, SOL_SOCKET, SO_MARK, (&MARK as *const u32).cast(), 4) != 0 {
            return Err(Error::last_os_error());
        }
        // This timeout also limits connect, then writes must be free to wait.
        let limit = [CONNECT_TIMEOUT_SECS, 0i64];
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, limit.as_ptr().cast(), 16);
        let mut sockaddr = [0u8; 16];
        sockaddr[..2].copy_from_slice(&(AF_INET as u16).to_ne_bytes());
        sockaddr[2..4].copy_from_slice(&addr.port().to_be_bytes());
        sockaddr[4..8].copy_from_slice(&addr.ip().octets());
        if connect(fd, sockaddr.as_ptr().cast(), 16) != 0 {
            let err = Error::last_os_error();
            // What a connect stopped by the timeout above reports.
            return Err(if err.raw_os_error() == Some(115) { Error::new(ErrorKind::TimedOut, "The proxy does not answer.") } else { err });
        }
        let free = [0i64, 0i64];
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, free.as_ptr().cast(), 16);
        stream.set_nodelay(true)?;
        Ok(stream)
    }
}

/// Sends to the far end.
pub struct Up {
    writer: Writer,
}

impl Up {
    pub fn write(&mut self, data: &[u8]) -> io::Result<()> {
        self.writer.write(data)
    }
}

enum Stage {
    /// The two bytes of the VLESS answer, and what they say to skip.
    Answer,
    /// Vision's user id, sent once before the first frame.
    Id,
    Frame,
    Records,
    Direct,
}

/// Receives from the far end.
pub struct Down {
    reader: Reader,
    uuid: [u8; 16],
    vision: bool,
    stage: Stage,
    pending: Vec<u8>,
    frame_ended: Option<u8>,
    content: usize,
    padding: usize,
}

impl Down {
    /// The next piece of data. An empty result means the far end closed.
    pub fn next(&mut self) -> io::Result<Vec<u8>> {
        loop {
            match self.stage {
                Stage::Direct => return self.reader.next_raw(),
                Stage::Records if self.pending.is_empty() => return self.reader.next(),
                _ => {}
            }
            if let Some(out) = self.parse()? {
                return Ok(out);
            }
            let more = self.reader.next()?;
            if more.is_empty() {
                return Ok(Vec::new());
            }
            self.pending.extend_from_slice(&more);
        }
    }

    /// Takes what it can from `pending`. Returns data, or None when it needs more bytes.
    fn parse(&mut self) -> io::Result<Option<Vec<u8>>> {
        loop {
            match self.stage {
                Stage::Answer => {
                    let Some(&skip) = self.pending.get(1) else { return Ok(None) };
                    if self.pending.len() < 2 + skip as usize {
                        return Ok(None);
                    }
                    if self.pending[0] != 0 {
                        return Err(Error::new(ErrorKind::InvalidData, "the server answered with another VLESS version"));
                    }
                    self.pending.drain(..2 + skip as usize);
                    self.stage = if self.vision { Stage::Id } else { Stage::Records };
                }
                Stage::Id => {
                    if self.pending.len() < 16 {
                        return Ok(None);
                    }
                    if self.pending[..16] == self.uuid {
                        self.pending.drain(..16);
                        self.stage = Stage::Frame;
                    } else {
                        self.stage = Stage::Records;
                    }
                }
                Stage::Frame => {
                    if self.content > 0 {
                        if self.pending.is_empty() {
                            return Ok(None);
                        }
                        let take = self.content.min(self.pending.len());
                        self.content -= take;
                        return Ok(Some(self.pending.drain(..take).collect()));
                    }
                    if self.padding > 0 {
                        if self.pending.is_empty() {
                            return Ok(None);
                        }
                        let take = self.padding.min(self.pending.len());
                        self.padding -= take;
                        self.pending.drain(..take);
                        continue;
                    }
                    if let Some(command) = self.frame_ended.take() {
                        match command {
                            0 => {}
                            1 => {
                                self.stage = Stage::Records;
                                continue;
                            }
                            _ => {
                                // The rest of this record is the first of the bytes sent directly.
                                let rest = std::mem::take(&mut self.pending);
                                self.stage = Stage::Direct;
                                if rest.is_empty() {
                                    return self.reader.next_raw().map(Some);
                                }
                                return Ok(Some(rest));
                            }
                        }
                    }
                    if self.pending.len() < 5 {
                        return Ok(None);
                    }
                    self.frame_ended = Some(self.pending[0]);
                    self.content = u16::from_be_bytes([self.pending[1], self.pending[2]]) as usize;
                    self.padding = u16::from_be_bytes([self.pending[3], self.pending[4]]) as usize;
                    self.pending.drain(..5);
                }
                Stage::Records => {
                    return Ok(if self.pending.is_empty() { None } else { Some(std::mem::take(&mut self.pending)) });
                }
                Stage::Direct => return Ok(None),
            }
        }
    }
}

/// Opens a tunnel to `target`. The returned stream is there so the caller can close it.
pub fn open(link: &Link, target: SocketAddrV4) -> io::Result<(Up, Down, TcpStream)> {
    let sock = open_socket(link.server, link.marked)?;
    let (reader, mut writer) = reality::handshake(sock.try_clone()?, &link.reality)?;

    let mut first = vec![0u8];
    first.extend_from_slice(&link.uuid);
    if link.vision {
        const FLOW: &[u8] = b"xtls-rprx-vision";
        first.push(FLOW.len() as u8 + 2);
        first.extend_from_slice(&[0x0a, FLOW.len() as u8]);
        first.extend_from_slice(FLOW);
    } else {
        first.push(0);
    }
    first.push(1);
    first.extend_from_slice(&target.port().to_be_bytes());
    first.push(1);
    first.extend_from_slice(&target.ip().octets());

    if link.vision {
        // One padded frame that ends the padding, so what follows is plain data inside the records.
        let mut size = [0u8; 2];
        random(&mut size);
        let padding = 200 + (u16::from_be_bytes(size) as usize % 800);
        first.extend_from_slice(&link.uuid);
        first.push(1);
        first.extend_from_slice(&[0, 0]);
        first.extend_from_slice(&(padding as u16).to_be_bytes());
        let mut fill = vec![0u8; padding];
        random(&mut fill);
        first.extend_from_slice(&fill);
    }
    writer.write(&first)?;

    let down = Down {
        reader,
        uuid: link.uuid,
        vision: link.vision,
        stage: Stage::Answer,
        pending: Vec::new(),
        frame_ended: None,
        content: 0,
        padding: 0,
    };
    Ok((Up { writer }, down, sock))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::TcpListener;

    const UUID: [u8; 16] = [7; 16];

    fn frame(command: u8, content: &[u8], padding: usize) -> Vec<u8> {
        let mut out = vec![command];
        out.extend_from_slice(&(content.len() as u16).to_be_bytes());
        out.extend_from_slice(&(padding as u16).to_be_bytes());
        out.extend_from_slice(content);
        out.extend(std::iter::repeat(0xee).take(padding));
        out
    }

    /// A receiver whose server sends these records, then these bytes outside any record.
    fn down_from(records: Vec<Vec<u8>>, raw: Vec<u8>) -> Down {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let client = TcpStream::connect(listener.local_addr().unwrap()).unwrap();
        let (server, _) = listener.accept().unwrap();
        std::thread::spawn(move || {
            use std::io::Write;
            let mut server = server;
            let mut writer = reality::test_writer(server.try_clone().unwrap());
            for record in records {
                writer.write(&record).unwrap();
            }
            server.write_all(&raw).unwrap();
        });
        Down {
            reader: reality::test_reader(client),
            uuid: UUID,
            vision: true,
            stage: Stage::Answer,
            pending: Vec::new(),
            frame_ended: None,
            content: 0,
            padding: 0,
        }
    }

    fn read_all(down: &mut Down) -> Vec<u8> {
        let mut all = Vec::new();
        loop {
            let piece = down.next().unwrap();
            if piece.is_empty() {
                return all;
            }
            all.extend_from_slice(&piece);
        }
    }

    #[test]
    fn frames_split_over_records_then_plain_records() {
        let mut stream = vec![0, 0];
        stream.extend_from_slice(&UUID);
        stream.extend(frame(0, b"hello ", 30));
        stream.extend(frame(1, b"world", 9));
        let (first, second) = stream.split_at(13);
        let mut down = down_from(vec![first.to_vec(), second.to_vec(), b" and more".to_vec()], Vec::new());
        assert_eq!(read_all(&mut down), b"hello world and more");
    }

    #[test]
    fn direct_copy_leaves_the_records() {
        let mut stream = vec![0, 0];
        stream.extend_from_slice(&UUID);
        stream.extend(frame(2, b"last in tls|", 4));
        let mut down = down_from(vec![stream], b"raw bytes".to_vec());
        assert_eq!(read_all(&mut down), b"last in tls|raw bytes");
    }

    #[test]
    fn a_server_without_vision_is_read_as_it_is() {
        let mut stream = vec![0, 0];
        stream.extend_from_slice(b"plain answer that has no id");
        let mut down = down_from(vec![stream], Vec::new());
        assert_eq!(read_all(&mut down), b"plain answer that has no id");
    }
}
