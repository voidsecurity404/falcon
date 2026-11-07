//! A TLS 1.3 client that proves itself to a Reality server.
//!
//! The server forwards strangers to the site it imitates. The client marks itself in the session id
//! of its hello, sealed with a key shared with the server's public key. The server answers with a
//! short certificate signed by that same key, which is what tells the two cases apart.
use crate::crypto::{random, Aead, Cipher, Hash, X25519};
use std::io::{self, Error, ErrorKind, Read, Write};
use std::net::TcpStream;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub struct Settings {
    pub public_key: [u8; 32],
    pub short_id: [u8; 8],
    pub server_name: String,
}

const REJECTED: &str = "The server did not accept this link. Its public key, short id or server name does not match the server.";
const VERSION: [u8; 3] = [26, 3, 0];
const RECORD_MAX: usize = 16384;
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(15);

fn fail<T>(text: &str) -> io::Result<T> {
    Err(Error::new(ErrorKind::InvalidData, text))
}

fn put16(out: &mut Vec<u8>, value: usize) {
    out.extend_from_slice(&(value as u16).to_be_bytes());
}

fn extension(out: &mut Vec<u8>, kind: u16, body: &[u8]) {
    out.extend_from_slice(&kind.to_be_bytes());
    put16(out, body.len());
    out.extend_from_slice(body);
}

fn grease() -> u16 {
    let mut pick = [0u8; 1];
    random(&mut pick);
    let byte = (pick[0] & 0xf0) | 0x0a;
    u16::from_be_bytes([byte, byte])
}

/// A hello shaped like a browser's, with an empty session id for now.
fn client_hello(random_bytes: &[u8; 32], name: &str, share: &[u8; 32]) -> Vec<u8> {
    let g = grease().to_be_bytes();
    let mut exts = Vec::new();
    let first_grease = grease();
    extension(&mut exts, first_grease, &[]);

    let mut sni = Vec::new();
    put16(&mut sni, name.len() + 3);
    sni.push(0);
    put16(&mut sni, name.len());
    sni.extend_from_slice(name.as_bytes());
    extension(&mut exts, 0, &sni);

    extension(&mut exts, 23, &[]);
    extension(&mut exts, 0xff01, &[0]);
    extension(&mut exts, 10, &[0, 8, g[0], g[1], 0, 29, 0, 23, 0, 24]);
    extension(&mut exts, 11, &[1, 0]);
    extension(&mut exts, 35, &[]);
    extension(&mut exts, 16, b"\x00\x0c\x02h2\x08http/1.1");
    extension(&mut exts, 5, &[1, 0, 0, 0, 0]);
    extension(&mut exts, 13, &[0, 16, 4, 3, 8, 4, 4, 1, 5, 3, 8, 5, 5, 1, 8, 6, 6, 1]);
    extension(&mut exts, 18, &[]);

    let mut keys = Vec::new();
    put16(&mut keys, 5 + 4 + 32);
    keys.extend_from_slice(&g);
    keys.extend_from_slice(&[0, 1, 0]);
    keys.extend_from_slice(&[0, 29, 0, 32]);
    keys.extend_from_slice(share);
    extension(&mut exts, 51, &keys);

    extension(&mut exts, 45, &[1, 1]);
    extension(&mut exts, 43, &[6, g[0], g[1], 3, 4, 3, 3]);
    extension(&mut exts, 27, &[2, 0, 2]);
    extension(&mut exts, 0x4469, b"\x00\x03\x02h2");
    // Two extensions of one type would be refused.
    extension(&mut exts, first_grease ^ 0x1010, &[0]);

    let mut body = vec![3, 3];
    body.extend_from_slice(random_bytes);
    body.push(32);
    body.extend_from_slice(&[0; 32]);
    let suites: [u16; 15] = [
        u16::from_be_bytes(g), 0x1301, 0x1302, 0x1303, 0xc02b, 0xc02f, 0xc02c, 0xc030, 0xcca9, 0xcca8, 0xc013, 0xc014, 0x009c, 0x009d, 0x002f,
    ];
    put16(&mut body, suites.len() * 2);
    for suite in suites {
        body.extend_from_slice(&suite.to_be_bytes());
    }
    body.extend_from_slice(&[1, 0]);

    // Browsers pad short hellos to 512 bytes.
    let plain = body.len() + 2 + exts.len() + 4;
    if plain < 512 {
        let room = 512 - plain;
        if room >= 4 {
            extension(&mut exts, 21, &vec![0; room - 4]);
        }
    }
    put16(&mut body, exts.len());
    body.extend_from_slice(&exts);

    let mut hello = vec![1, 0];
    put16(&mut hello, body.len());
    hello.extend_from_slice(&body);
    hello
}

/// Fills the session id, which is sealed over the hello with that field still empty.
fn seal_session_id(hello: &mut [u8], random_bytes: &[u8; 32], key: &X25519, settings: &Settings) -> io::Result<Vec<u8>> {
    let shared = key.shared(&settings.public_key).ok_or_else(|| Error::new(ErrorKind::InvalidData, "the public key of the link is not valid"))?;
    let prk = Hash::Sha256.hmac(&random_bytes[..20], &shared);
    let auth = Hash::Sha256.hkdf_expand(&prk, b"REALITY", 32);

    let mut plain = [0u8; 16];
    plain[..3].copy_from_slice(&VERSION);
    let now = SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs()) as u32;
    plain[4..8].copy_from_slice(&now.to_be_bytes());
    plain[8..16].copy_from_slice(&settings.short_id);

    let nonce: [u8; 12] = random_bytes[20..32].try_into().unwrap();
    let sealed = Aead::new(Cipher::Aes256Gcm, &auth, true).seal(&nonce, hello, &plain);
    hello[39..71].copy_from_slice(&sealed);
    Ok(auth)
}

fn label(hash: Hash, secret: &[u8], name: &str, context: &[u8], len: usize) -> Vec<u8> {
    let mut info = Vec::new();
    put16(&mut info, len);
    info.push(6 + name.len() as u8);
    info.extend_from_slice(b"tls13 ");
    info.extend_from_slice(name.as_bytes());
    info.push(context.len() as u8);
    info.extend_from_slice(context);
    hash.hkdf_expand(secret, &info, len)
}

/// The receiving half of the connection.
pub struct Reader {
    sock: TcpStream,
    aead: Option<Aead>,
    iv: [u8; 12],
    seq: u64,
    buffer: Vec<u8>,
}

impl Reader {
    fn fill(&mut self, need: usize) -> io::Result<()> {
        let mut chunk = [0u8; 32768];
        while self.buffer.len() < need {
            let got = self.sock.read(&mut chunk)?;
            if got == 0 {
                return Err(ErrorKind::UnexpectedEof.into());
            }
            self.buffer.extend_from_slice(&chunk[..got]);
        }
        Ok(())
    }

    /// The next record as it came: its type and body.
    fn raw_record(&mut self) -> io::Result<(u8, Vec<u8>, [u8; 5])> {
        self.fill(5)?;
        let head: [u8; 5] = self.buffer[..5].try_into().unwrap();
        let len = u16::from_be_bytes([head[3], head[4]]) as usize;
        self.fill(5 + len)?;
        let body = self.buffer[5..5 + len].to_vec();
        self.buffer.drain(..5 + len);
        Ok((head[0], body, head))
    }

    fn open(&mut self, body: &[u8], head: &[u8; 5]) -> io::Result<(u8, Vec<u8>)> {
        let aead = self.aead.as_mut().expect("keys are set");
        let mut nonce = self.iv;
        for (byte, seq) in nonce[4..].iter_mut().zip(self.seq.to_be_bytes()) {
            *byte ^= seq;
        }
        self.seq += 1;
        let Some(mut plain) = aead.open(&nonce, head, body) else {
            return fail("a record did not decrypt");
        };
        while plain.last() == Some(&0) {
            plain.pop();
        }
        match plain.pop() {
            Some(kind) => Ok((kind, plain)),
            None => fail("an empty record"),
        }
    }

    /// The next piece of application data. An empty result means the server closed the connection.
    pub fn next(&mut self) -> io::Result<Vec<u8>> {
        loop {
            let (kind, body, head) = match self.raw_record() {
                Ok(record) => record,
                Err(err) if err.kind() == ErrorKind::UnexpectedEof => return Ok(Vec::new()),
                Err(err) => return Err(err),
            };
            if kind == 20 {
                continue;
            }
            let (inner, plain) = self.open(&body, &head)?;
            match inner {
                23 if !plain.is_empty() => return Ok(plain),
                21 => return Ok(Vec::new()),
                _ => {}
            }
        }
    }

    /// After Vision switches to direct copy, the bytes that follow are no longer TLS records.
    pub fn next_raw(&mut self) -> io::Result<Vec<u8>> {
        if !self.buffer.is_empty() {
            return Ok(std::mem::take(&mut self.buffer));
        }
        let mut chunk = vec![0u8; 32768];
        let got = self.sock.read(&mut chunk)?;
        chunk.truncate(got);
        Ok(chunk)
    }
}

/// The sending half of the connection.
pub struct Writer {
    sock: TcpStream,
    aead: Aead,
    iv: [u8; 12],
    seq: u64,
}

impl Writer {
    fn record(&mut self, kind: u8, data: &[u8]) -> Vec<u8> {
        let mut plain = data.to_vec();
        plain.push(kind);
        let mut head = [23, 3, 3, 0, 0];
        head[3..5].copy_from_slice(&((plain.len() + 16) as u16).to_be_bytes());
        let mut nonce = self.iv;
        for (byte, seq) in nonce[4..].iter_mut().zip(self.seq.to_be_bytes()) {
            *byte ^= seq;
        }
        self.seq += 1;
        let sealed = self.aead.seal(&nonce, &head, &plain);
        let mut out = head.to_vec();
        out.extend_from_slice(&sealed);
        out
    }

    pub fn write(&mut self, data: &[u8]) -> io::Result<()> {
        let mut out = Vec::with_capacity(data.len() + 64);
        for piece in data.chunks(RECORD_MAX) {
            out.extend_from_slice(&self.record(23, piece));
        }
        self.sock.write_all(&out)
    }
}

fn keys(cipher: Cipher, hash: Hash, secret: &[u8], sealing: bool) -> (Aead, [u8; 12]) {
    let key = label(hash, secret, "key", &[], cipher.key_len());
    let iv = label(hash, secret, "iv", &[], 12);
    (Aead::new(cipher, &key, sealing), iv.try_into().unwrap())
}

/// The server's X25519 share and the chosen suite, out of its hello.
fn read_server_hello(body: &[u8]) -> Option<(u16, Vec<u8>)> {
    let mut at = 4 + 2 + 32;
    let id_len = *body.get(at)? as usize;
    at += 1 + id_len;
    let suite = u16::from_be_bytes(body.get(at..at + 2)?.try_into().ok()?);
    at += 3;
    let total = u16::from_be_bytes(body.get(at..at + 2)?.try_into().ok()?) as usize;
    at += 2;
    let end = at + total;
    while at + 4 <= end {
        let kind = u16::from_be_bytes(body.get(at..at + 2)?.try_into().ok()?);
        let len = u16::from_be_bytes(body.get(at + 2..at + 4)?.try_into().ok()?) as usize;
        at += 4;
        if kind == 51 {
            if body.get(at..at + 2)? != [0, 29] {
                return None;
            }
            return Some((suite, body.get(at + 4..at + len)?.to_vec()));
        }
        at += len;
    }
    None
}

/// Whether the first certificate carries this connection's signature instead of a real site's.
fn certificate_is_reality(message: &[u8], auth: &[u8]) -> bool {
    let Some(&context) = message.get(4) else { return false };
    let start = 4 + 1 + context as usize + 3;
    let Some(head) = message.get(start..start + 3) else { return false };
    let len = (head[0] as usize) << 16 | (head[1] as usize) << 8 | head[2] as usize;
    let Some(cert) = message.get(start + 3..start + 3 + len) else { return false };
    if cert.len() < 64 {
        return false;
    }
    const KEY: [u8; 8] = [0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00];
    let Some(place) = cert.windows(KEY.len()).position(|w| w == KEY) else { return false };
    let Some(public) = cert.get(place + KEY.len()..place + KEY.len() + 32) else { return false };
    Hash::Sha512.hmac(auth, public) == cert[cert.len() - 64..]
}

/// Connects over a socket that is already open.
pub fn handshake(sock: TcpStream, settings: &Settings) -> io::Result<(Reader, Writer)> {
    sock.set_read_timeout(Some(HANDSHAKE_TIMEOUT))?;
    let key = X25519::generate();
    let mut random_bytes = [0u8; 32];
    random(&mut random_bytes);

    let mut hello = client_hello(&random_bytes, &settings.server_name, &key.public);
    let auth = seal_session_id(&mut hello, &random_bytes, &key, settings)?;

    let mut first = vec![22, 3, 1];
    put16(&mut first, hello.len());
    first.extend_from_slice(&hello);
    let mut send = sock.try_clone()?;
    send.write_all(&first)?;

    let mut reader = Reader { sock: sock.try_clone()?, aead: None, iv: [0; 12], seq: 0, buffer: Vec::new() };
    let mut transcript = hello;

    let server_hello = loop {
        let (kind, body, _) = reader.raw_record()?;
        match kind {
            22 => break body,
            21 => return fail(REJECTED),
            _ => {}
        }
    };
    let Some((suite, share)) = read_server_hello(&server_hello) else {
        return fail(REJECTED);
    };
    transcript.extend_from_slice(&server_hello);

    let (cipher, hash) = match suite {
        0x1301 => (Cipher::Aes128Gcm, Hash::Sha256),
        0x1302 => (Cipher::Aes256Gcm, Hash::Sha384),
        0x1303 => (Cipher::Chacha20, Hash::Sha256),
        _ => return fail(REJECTED),
    };
    let Some(shared) = key.shared(&share) else { return fail(REJECTED) };

    let zero = vec![0u8; hash.len()];
    let empty = hash.digest(&[]);
    let early = hash.hmac(&zero, &zero);
    let derived = label(hash, &early, "derived", &empty, hash.len());
    let handshake_secret = hash.hmac(&derived, &shared);
    let context = hash.digest(&transcript);
    let client_secret = label(hash, &handshake_secret, "c hs traffic", &context, hash.len());
    let server_secret = label(hash, &handshake_secret, "s hs traffic", &context, hash.len());

    let (aead, iv) = keys(cipher, hash, &server_secret, false);
    reader.aead = Some(aead);
    reader.iv = iv;
    reader.seq = 0;

    // Encrypted extensions, certificate, its proof and finished may share or split records.
    let mut messages: Vec<u8> = Vec::new();
    let mut seen_certificate = false;
    loop {
        if messages.len() < 4 || messages.len() < 4 + ((messages[1] as usize) << 16 | (messages[2] as usize) << 8 | messages[3] as usize) {
            let (kind, body, head) = reader.raw_record()?;
            if kind == 20 {
                continue;
            }
            if kind != 23 {
                return fail(REJECTED);
            }
            let (inner, plain) = reader.open(&body, &head)?;
            if inner != 22 {
                return fail(REJECTED);
            }
            messages.extend_from_slice(&plain);
            continue;
        }
        let len = 4 + ((messages[1] as usize) << 16 | (messages[2] as usize) << 8 | messages[3] as usize);
        let message: Vec<u8> = messages.drain(..len).collect();
        match message[0] {
            11 => {
                if !certificate_is_reality(&message, &auth) {
                    return fail(REJECTED);
                }
                seen_certificate = true;
            }
            20 => {
                let finished_key = label(hash, &server_secret, "finished", &[], hash.len());
                if !seen_certificate || hash.hmac(&finished_key, &hash.digest(&transcript)) != message[4..] {
                    return fail("the server's finished message is wrong");
                }
                transcript.extend_from_slice(&message);
                break;
            }
            _ => {}
        }
        transcript.extend_from_slice(&message);
    }

    let context = hash.digest(&transcript);
    let derived = label(hash, &handshake_secret, "derived", &empty, hash.len());
    let master = hash.hmac(&derived, &zero);
    let client_app = label(hash, &master, "c ap traffic", &context, hash.len());
    let server_app = label(hash, &master, "s ap traffic", &context, hash.len());

    let finished_key = label(hash, &client_secret, "finished", &[], hash.len());
    let verify = hash.hmac(&finished_key, &context);
    let mut finished = vec![20, 0, 0, verify.len() as u8];
    finished.extend_from_slice(&verify);
    let (aead, iv) = keys(cipher, hash, &client_secret, true);
    let mut writer = Writer { sock: sock.try_clone()?, aead, iv, seq: 0 };
    let mut out = vec![20, 3, 3, 0, 1, 1];
    out.extend_from_slice(&writer.record(22, &finished));
    send.write_all(&out)?;

    let (aead, iv) = keys(cipher, hash, &client_app, true);
    writer.aead = aead;
    writer.iv = iv;
    writer.seq = 0;
    let (aead, iv) = keys(cipher, hash, &server_app, false);
    reader.aead = Some(aead);
    reader.iv = iv;
    reader.seq = 0;

    sock.set_read_timeout(None)?;
    Ok((reader, writer))
}

#[cfg(test)]
fn test_keys(sealing: bool) -> Aead {
    Aead::new(Cipher::Aes128Gcm, &[9; 16], sealing)
}

#[cfg(test)]
pub fn test_writer(sock: TcpStream) -> Writer {
    Writer { sock, aead: test_keys(true), iv: [3; 12], seq: 0 }
}

#[cfg(test)]
pub fn test_reader(sock: TcpStream) -> Reader {
    Reader { sock, aead: Some(test_keys(false)), iv: [3; 12], seq: 0, buffer: Vec::new() }
}
