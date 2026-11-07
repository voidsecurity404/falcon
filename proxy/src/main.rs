//! Sends this computer's TCP and DNS through a VLESS Reality server.
//!
//!   falcon-proxyd run LINK_FILE                       the service, loads its firewall rules
//!   falcon-proxyd check LINK_FILE                     asks the server one DNS question
//!   falcon-proxyd forward LINK_FILE PORT IP TARGET    a test: localhost:PORT reaches IP:TARGET
mod crypto;
mod reality;
mod vless;

use reality::Settings;
use std::ffi::{c_int, c_void};
use std::io::{self, Read, Write};
use std::net::{Ipv4Addr, Shutdown, SocketAddrV4, TcpListener, TcpStream, ToSocketAddrs, UdpSocket};
use std::os::fd::AsRawFd;
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::thread;
use vless::Link;

extern "C" {
    fn getsockopt(fd: c_int, level: c_int, name: c_int, value: *mut c_void, len: *mut u32) -> c_int;
}

const TCP_PORT: u16 = 12340;
const DNS_PORT: u16 = 12341;
const DNS_SERVER: SocketAddrV4 = SocketAddrV4::new(Ipv4Addr::new(1, 1, 1, 1), 53);
const SOL_IP: c_int = 0;
const SO_ORIGINAL_DST: c_int = 80;

fn hex(text: &str) -> Option<Vec<u8>> {
    if text.len() % 2 != 0 {
        return None;
    }
    (0..text.len()).step_by(2).map(|i| u8::from_str_radix(text.get(i..i + 2)?, 16).ok()).collect()
}

fn base64url(text: &str) -> Option<Vec<u8>> {
    let mut out = Vec::new();
    let (mut bits, mut count) = (0u32, 0);
    for byte in text.bytes() {
        let value = match byte {
            b'A'..=b'Z' => byte - b'A',
            b'a'..=b'z' => byte - b'a' + 26,
            b'0'..=b'9' => byte - b'0' + 52,
            b'-' | b'+' => 62,
            b'_' | b'/' => 63,
            b'=' => continue,
            _ => return None,
        };
        bits = (bits << 6) | value as u32;
        count += 6;
        if count >= 8 {
            count -= 8;
            out.push((bits >> count) as u8);
        }
    }
    Some(out)
}

fn parse_link(text: &str, marked: bool) -> Result<Link, &'static str> {
    let rest = text.trim().strip_prefix("vless://").ok_or("not a vless:// link")?;
    let rest = rest.split('#').next().unwrap_or(rest);
    let (user, rest) = rest.split_once('@').ok_or("the link has no user id")?;
    let (host, query) = rest.split_once('?').ok_or("the link has no settings")?;
    let find = |name: &str| query.split('&').find_map(|pair| pair.strip_prefix(name)?.strip_prefix('='));

    if find("security") != Some("reality") || find("type").is_some_and(|kind| kind != "tcp") {
        return Err("only VLESS over TCP with Reality is supported");
    }
    let uuid: [u8; 16] = hex(&user.replace('-', "")).and_then(|v| v.try_into().ok()).ok_or("the user id of the link is not valid")?;
    let public_key: [u8; 32] = find("pbk").and_then(base64url).and_then(|v| v.try_into().ok()).ok_or("the public key of the link is not valid")?;
    let id = hex(find("sid").unwrap_or("")).filter(|id| id.len() <= 8).ok_or("the short id of the link is not valid")?;
    let mut short_id = [0u8; 8];
    short_id[..id.len()].copy_from_slice(&id);
    let server = host.to_socket_addrs().map_err(|_| "the server of the link was not found")?.find_map(|addr| match addr {
        std::net::SocketAddr::V4(v4) => Some(v4),
        std::net::SocketAddr::V6(_) => None,
    });
    Ok(Link {
        server: server.ok_or("the server of the link has no IPv4 address")?,
        uuid,
        vision: find("flow") == Some("xtls-rprx-vision"),
        reality: Settings { public_key, short_id, server_name: find("sni").unwrap_or("").to_string() },
        marked,
    })
}

/// Copies both ways until either side ends, then closes both.
fn relay(link: &Link, mut local: TcpStream, target: SocketAddrV4) -> io::Result<()> {
    let (mut up, mut down, remote) = vless::open(link, target)?;
    local.set_nodelay(true)?;
    let mut local_out = local.try_clone()?;
    let close_remote = remote.try_clone()?;
    let close_local = local.try_clone()?;
    let downward = thread::spawn(move || {
        while let Ok(data) = down.next() {
            if data.is_empty() || local_out.write_all(&data).is_err() {
                break;
            }
        }
        let _ = close_local.shutdown(Shutdown::Both);
        let _ = close_remote.shutdown(Shutdown::Both);
    });
    let mut chunk = vec![0u8; 32768];
    loop {
        match local.read(&mut chunk) {
            Ok(got) if got > 0 && up.write(&chunk[..got]).is_ok() => {}
            _ => break,
        }
    }
    let _ = remote.shutdown(Shutdown::Both);
    let _ = local.shutdown(Shutdown::Both);
    let _ = downward.join();
    Ok(())
}

fn original_target(stream: &TcpStream) -> io::Result<SocketAddrV4> {
    let mut raw = [0u8; 16];
    let mut len = 16u32;
    let done = unsafe { getsockopt(stream.as_raw_fd(), SOL_IP, SO_ORIGINAL_DST, raw.as_mut_ptr().cast(), &mut len) };
    if done != 0 {
        return Err(io::Error::last_os_error());
    }
    let port = u16::from_be_bytes([raw[2], raw[3]]);
    Ok(SocketAddrV4::new(Ipv4Addr::new(raw[4], raw[5], raw[6], raw[7]), port))
}

/// Where a DNS question's type starts, after its name.
fn question_type(query: &[u8]) -> Option<u16> {
    let mut at = 12;
    loop {
        let len = *query.get(at)? as usize;
        at += 1;
        if len == 0 {
            break;
        }
        at += len;
    }
    Some(u16::from_be_bytes([*query.get(at)?, *query.get(at + 1)?]))
}

fn ask_dns(link: &Link, query: &[u8]) -> io::Result<Vec<u8>> {
    let (mut up, mut down, remote) = vless::open(link, DNS_SERVER)?;
    let mut framed = (query.len() as u16).to_be_bytes().to_vec();
    framed.extend_from_slice(query);
    up.write(&framed)?;
    let mut answer = Vec::new();
    loop {
        if answer.len() >= 2 && answer.len() >= 2 + u16::from_be_bytes([answer[0], answer[1]]) as usize {
            let _ = remote.shutdown(Shutdown::Both);
            let len = u16::from_be_bytes([answer[0], answer[1]]) as usize;
            return Ok(answer[2..2 + len].to_vec());
        }
        let more = down.next()?;
        if more.is_empty() {
            return Err(io::ErrorKind::UnexpectedEof.into());
        }
        answer.extend_from_slice(&more);
    }
}

/// The way out may have no IPv6, so a name is said to have none and apps do not wait for it.
fn no_ipv6_answer(query: &[u8]) -> Vec<u8> {
    let mut answer = query.to_vec();
    answer[2] = 0x81;
    answer[3] = 0x80;
    answer[6..12].fill(0);
    answer
}

fn serve_dns(link: Arc<Link>) -> io::Result<()> {
    let socket = Arc::new(UdpSocket::bind((Ipv4Addr::LOCALHOST, DNS_PORT))?);
    let mut buffer = [0u8; 4096];
    loop {
        let (len, from) = socket.recv_from(&mut buffer)?;
        let query = buffer[..len].to_vec();
        if query.len() < 12 {
            continue;
        }
        let (link, socket) = (link.clone(), socket.clone());
        thread::spawn(move || {
            let answer = if question_type(&query) == Some(28) { Ok(no_ipv6_answer(&query)) } else { ask_dns(&link, &query) };
            match answer {
                Ok(answer) => {
                    let _ = socket.send_to(&answer, from);
                }
                Err(err) => eprintln!("dns: {err}"),
            }
        });
    }
}

fn firewall_rules() -> String {
    const PRIVATE: &str = "{ 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 100.64.0.0/10, 224.0.0.0/4, 255.255.255.255 }";
    let mark = vless::MARK;
    format!(
        "destroy table inet falcon_proxy
table inet falcon_proxy {{
    chain nat_out {{
        type nat hook output priority -100;
        meta mark {mark} return
        udp dport 53 ip daddr != 127.0.0.0/8 redirect to :{DNS_PORT}
        ip daddr {PRIVATE} return
        ip protocol tcp redirect to :{TCP_PORT}
    }}
    chain filter_out {{
        type filter hook output priority 0;
        meta mark {mark} return
        ip daddr != {PRIVATE} udp dport 443 reject
        meta nfproto ipv6 ip6 daddr != {{ ::1, fe80::/10, fc00::/7, ff00::/8 }} reject
    }}
}}
"
    )
}

fn load_firewall() -> io::Result<()> {
    let mut nft = Command::new("nft").args(["-f", "-"]).stdin(Stdio::piped()).spawn()?;
    nft.stdin.take().expect("piped").write_all(firewall_rules().as_bytes())?;
    if nft.wait()?.success() {
        Ok(())
    } else {
        Err(io::Error::other("nft refused the rules"))
    }
}

fn accept_loop(listener: TcpListener, link: Arc<Link>, fixed: Option<SocketAddrV4>) -> Result<(), String> {
    loop {
        let (stream, _) = listener.accept().map_err(|err| err.to_string())?;
        let link = link.clone();
        thread::spawn(move || {
            let place = fixed.map_or_else(|| original_target(&stream), Ok);
            if let Err(err) = place.and_then(|place| relay(&link, stream, place)) {
                eprintln!("connection: {err}");
            }
        });
    }
}

fn read_link(path: &str, marked: bool) -> Result<Arc<Link>, String> {
    let text = std::fs::read_to_string(path).map_err(|err| format!("{path}: {err}"))?;
    parse_link(&text, marked).map(Arc::new).map_err(str::to_string)
}

fn run(path: &str) -> Result<(), String> {
    let link = read_link(path, true)?;
    let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, TCP_PORT)).map_err(|err| err.to_string())?;
    let dns_link = link.clone();
    thread::spawn(move || {
        if let Err(err) = serve_dns(dns_link) {
            eprintln!("dns: {err}");
            std::process::exit(1);
        }
    });
    load_firewall().map_err(|err| err.to_string())?;
    accept_loop(listener, link, None)
}

fn forward(path: &str, port: &str, ip: &str, target_port: &str) -> Result<(), String> {
    let link = read_link(path, false)?;
    let port: u16 = port.parse().map_err(|_| "bad port")?;
    let target = SocketAddrV4::new(ip.parse().map_err(|_| "bad address")?, target_port.parse().map_err(|_| "bad port")?);
    let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, port)).map_err(|err| err.to_string())?;
    accept_loop(listener, link, Some(target))
}

/// A question for example.com, type A.
fn check(path: &str) -> Result<(), String> {
    let link = read_link(path, false)?;
    let query = b"\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x07example\x03com\x00\x00\x01\x00\x01";
    ask_dns(&link, query).map(|_| ()).map_err(|err| err.to_string())
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    let result = match args.as_slice() {
        ["run", path] => run(path),
        ["check", path] => check(path),
        ["forward", path, port, ip, target] => forward(path, port, ip, target),
        _ => Err("usage: falcon-proxyd run LINK_FILE | check LINK_FILE | forward LINK_FILE PORT IP TARGET_PORT".to_string()),
    };
    if let Err(err) = result {
        eprintln!("{err}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_a_link() {
        let link = parse_link("vless://11223344-5566-7788-99aa-bbccddeeff00@127.0.0.1:443?security=reality&pbk=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&type=tcp&flow=xtls-rprx-vision&sni=a.example&sid=ab12#name", true).unwrap();
        assert_eq!(link.server.port(), 443);
        assert_eq!(link.uuid[0], 0x11);
        assert!(link.vision);
        assert_eq!(link.reality.server_name, "a.example");
        assert_eq!(link.reality.short_id, [0xab, 0x12, 0, 0, 0, 0, 0, 0]);
    }

    #[test]
    fn refuses_what_it_cannot_use() {
        assert!(parse_link("https://example.com", true).is_err());
        assert!(parse_link("vless://u@127.0.0.1:443?security=tls", true).is_err());
    }

    #[test]
    fn dns_question_type_and_empty_answer() {
        let query = b"\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x01a\x00\x00\x1c\x00\x01";
        assert_eq!(question_type(query), Some(28));
        let answer = no_ipv6_answer(query);
        assert_eq!(answer[..4], [0x12, 0x34, 0x81, 0x80]);
        assert_eq!(answer[6..8], [0, 0]);
    }
}
