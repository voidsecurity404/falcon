//! One password for a whole queue of jobs.
//!
//! yay calls its sudo command once for every pacman step of an AUR install
//! (dependencies, the package, marking, removing make dependencies), and
//! pkexec asks for the password each time. Instead, the store starts one
//! root helper through pkexec when a job needs root: that is the only
//! password prompt. yay is then given this same program as its sudo
//! (`--sudo archmarket --sudoflags --sudo-proxy`), and each call is passed
//! to the helper over a Unix socket.
//!
//! The helper runs nothing but /usr/bin/pacman, refuses options that point
//! pacman at another root, config or database, answers only the user who
//! started it (SO_PEERCRED against PKEXEC_UID) and only with the random
//! token the store gave it, and exits as soon as the store closes its
//! stdin: when the queue is empty, or when the store itself goes away.

use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};

/// A pacman run is in progress: the helper must not exit under it.
static BUSY: AtomicBool = AtomicBool::new(false);

pub const ENV_SOCK: &str = "ARCHMARKET_BROKER";
pub const ENV_TOKEN: &str = "ARCHMARKET_TOKEN";

const REFUSED: &[&str] = &[
    "--root", "-r", "--dbpath", "-b", "--config", "--hookdir", "--gpgdir", "--cachedir", "--logfile", "--sysroot",
    "--arch", "--overwrite",
];

fn peer_uid(s: &UnixStream) -> Option<u32> {
    use std::os::fd::AsRawFd;
    let mut cred: libc::ucred = unsafe { std::mem::zeroed() };
    let mut len = std::mem::size_of::<libc::ucred>() as libc::socklen_t;
    let rc = unsafe {
        libc::getsockopt(
            s.as_raw_fd(),
            libc::SOL_SOCKET,
            libc::SO_PEERCRED,
            &mut cred as *mut libc::ucred as *mut libc::c_void,
            &mut len,
        )
    };
    (rc == 0).then_some(cred.uid)
}

fn same(a: &str, b: &str) -> bool {
    a.len() == b.len() && a.bytes().zip(b.bytes()).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

/// Whether pacman may be run with these arguments.
pub fn allowed(args: &[String]) -> bool {
    if args.is_empty() || !(args[0] == "pacman" || args[0] == "/usr/bin/pacman") {
        return false;
    }
    let mut after_dashes = false;
    let mut i = 1;
    while i < args.len() {
        let a = &args[i];
        i += 1;
        if a == "--" {
            after_dashes = true;
            continue;
        }
        if after_dashes {
            continue;
        }
        // yay always names the system's own config: that one is fine
        if a == "--config" && args.get(i).map(String::as_str) == Some("/etc/pacman.conf") {
            i += 1;
            continue;
        }
        if a == "--config=/etc/pacman.conf" {
            continue;
        }
        let key = a.split('=').next().unwrap_or("");
        if REFUSED.contains(&key) {
            return false;
        }
        // short options packed together, such as -Syr: refuse r and b
        if a.starts_with('-') && !a.starts_with("--") && a[1..].chars().any(|c| c == 'r' || c == 'b') {
            return false;
        }
    }
    true
}

/// The root side, started as `pkexec archmarket --root-helper DIR`.
pub fn serve(dir: &str) -> i32 {
    let Some(uid) = std::env::var("PKEXEC_UID").ok().and_then(|v| v.parse::<u32>().ok()) else {
        eprintln!("archmarket: --root-helper only runs through pkexec");
        return 1;
    };
    let mut token = String::new();
    if std::io::stdin().lock().read_line(&mut token).is_err() || token.trim().len() < 32 {
        return 1;
    }
    let token = token.trim().to_string();
    let dir = Path::new(dir);
    // The folder must be the user's own, private, and not a link.
    match std::fs::symlink_metadata(dir) {
        Ok(m) if m.is_dir() && m.uid() == uid && m.mode() & 0o077 == 0 => {}
        _ => {
            eprintln!("archmarket: unsafe helper folder");
            return 1;
        }
    }
    let path = dir.join("root.sock");
    let _ = std::fs::remove_file(&path);
    let Ok(listener) = UnixListener::bind(&path) else { return 1 };
    if std::os::unix::fs::chown(&path, Some(uid), None).is_err()
        || std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600)).is_err()
    {
        let _ = std::fs::remove_file(&path);
        return 1;
    }
    println!("ready");
    let _ = std::io::stdout().flush();
    {
        let path = path.clone();
        std::thread::spawn(move || {
            let mut sink = Vec::new();
            let _ = std::io::stdin().lock().read_to_end(&mut sink);
            let _ = std::fs::remove_file(&path);
            // never leave pacman in the middle of a transaction
            while BUSY.load(Ordering::SeqCst) {
                std::thread::sleep(std::time::Duration::from_millis(200));
            }
            std::process::exit(0);
        });
    }
    for conn in listener.incoming() {
        let Ok(conn) = conn else { continue };
        if peer_uid(&conn) != Some(uid) {
            continue;
        }
        handle(conn, &token);
    }
    0
}

fn handle(conn: UnixStream, token: &str) {
    let mut reader = BufReader::new(match conn.try_clone() {
        Ok(c) => c,
        Err(_) => return,
    });
    let mut out = conn;
    let mut line = String::new();
    if reader.read_line(&mut line).is_err() {
        return;
    }
    let Ok(req) = serde_json::from_str::<serde_json::Value>(&line) else { return };
    let args: Vec<String> = req["args"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|v| v.as_str().map(str::to_string))
        .collect();
    if !same(req["token"].as_str().unwrap_or(""), token) {
        let _ = writeln!(out, "x 1");
        return;
    }
    if !allowed(&args) {
        let _ = writeln!(out, "o archmarket: refused: {}", args.join(" "));
        let _ = writeln!(out, "x 1");
        return;
    }
    let cwd = req["cwd"].as_str().map(PathBuf::from).filter(|p| p.is_dir()).unwrap_or_else(|| PathBuf::from("/"));
    BUSY.store(true, Ordering::SeqCst);
    let Ok((mut child, master)) = spawn_in_pty(&args[1..], &cwd) else {
        BUSY.store(false, Ordering::SeqCst);
        let _ = writeln!(out, "x 1");
        return;
    };
    // pacman draws its bars with \r; they pass through as they are and the
    // store splits them. Read until the pty reports EIO: pacman has exited.
    for chunk in BufReader::new(master).split(b'\n') {
        let Ok(chunk) = chunk else { break };
        let _ = out.write_all(b"o ");
        let _ = out.write_all(&chunk);
        let _ = out.write_all(b"\n");
    }
    let code = child.wait().ok().and_then(|s| s.code()).unwrap_or(1);
    BUSY.store(false, Ordering::SeqCst);
    let _ = writeln!(out, "x {code}");
}

/// Runs pacman with its output on a pseudo terminal, so it prints its real
/// progress bars (it shows no percentages when writing to a pipe).
fn spawn_in_pty(args: &[String], cwd: &Path) -> std::io::Result<(Child, std::fs::File)> {
    use std::os::fd::FromRawFd;
    let mut master: libc::c_int = -1;
    let mut slave: libc::c_int = -1;
    let ws = libc::winsize { ws_row: 40, ws_col: 120, ws_xpixel: 0, ws_ypixel: 0 };
    let rc = unsafe { libc::openpty(&mut master, &mut slave, std::ptr::null_mut(), std::ptr::null(), &ws) };
    if rc != 0 {
        return Err(std::io::Error::last_os_error());
    }
    unsafe {
        libc::fcntl(master, libc::F_SETFD, libc::FD_CLOEXEC);
    }
    let master = unsafe { std::fs::File::from_raw_fd(master) };
    let slave = unsafe { std::fs::File::from_raw_fd(slave) };
    let child = {
        let mut cmd = Command::new("/usr/bin/pacman");
        cmd.args(args)
            .current_dir(cwd)
            .env_clear()
            .env("PATH", "/usr/local/sbin:/usr/local/bin:/usr/bin")
            .env("LC_ALL", "C")
            .env("TERM", "xterm-256color")
            .env("COLUMNS", "120")
            .stdin(Stdio::null())
            .stdout(slave.try_clone()?)
            .stderr(slave);
        cmd.spawn()?
        // `cmd` drops here with its copies of the slave, so the pty ends
        // when pacman does
    };
    Ok((child, master))
}

/// The user side: `archmarket --sudo-proxy pacman ARGS…`, which yay runs in
/// place of sudo.
pub fn proxy(args: Vec<String>) -> i32 {
    let (Ok(sock), Ok(token)) = (std::env::var(ENV_SOCK), std::env::var(ENV_TOKEN)) else {
        eprintln!("archmarket: no root helper is running");
        return 1;
    };
    let Ok(mut s) = UnixStream::connect(&sock) else {
        eprintln!("archmarket: the root helper is gone");
        return 1;
    };
    let mut env = serde_json::Map::new();
    for k in ["LANG", "LC_ALL", "LC_MESSAGES", "TERM"] {
        if let Ok(v) = std::env::var(k) {
            env.insert(k.into(), v.into());
        }
    }
    let req = serde_json::json!({
        "token": token,
        "args": args,
        "cwd": std::env::current_dir().ok().map(|p| p.to_string_lossy().into_owned()),
        "env": env,
    });
    if writeln!(s, "{req}").is_err() {
        return 1;
    }
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    for chunk in BufReader::new(s).split(b'\n') {
        let Ok(chunk) = chunk else { break };
        if let Some(rest) = chunk.strip_prefix(b"o ") {
            let _ = out.write_all(rest);
            let _ = out.write_all(b"\n");
            let _ = out.flush();
        } else if let Some(code) = chunk.strip_prefix(b"x ") {
            return String::from_utf8_lossy(code).trim().parse().unwrap_or(1);
        }
    }
    1
}

/// The running helper, owned by the job worker.
pub struct Broker {
    child: Child,
    stdin: Option<ChildStdin>,
    dir: PathBuf,
    pub sock: PathBuf,
    pub token: String,
}

impl Broker {
    /// Starts the helper; this is where the password is asked. The error is
    /// pkexec's exit code (126: cancelled, 127: not authorized).
    pub fn start(runtime: &Path) -> Result<Broker, i32> {
        let exe = std::env::current_exe().map_err(|_| 1)?;
        let dir = runtime.join(format!("broker-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).map_err(|_| 1)?;
        std::fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o700)).map_err(|_| 1)?;
        let mut raw = [0u8; 32];
        std::fs::File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut raw)).map_err(|_| 1)?;
        let token: String = raw.iter().map(|b| format!("{b:02x}")).collect();
        let mut child = Command::new("pkexec")
            .arg(&exe)
            .arg("--root-helper")
            .arg(&dir)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|_| 1)?;
        let mut stdin = child.stdin.take().ok_or(1)?;
        writeln!(stdin, "{token}").map_err(|_| 1)?;
        let mut line = String::new();
        let stdout = child.stdout.take().ok_or(1)?;
        let _ = BufReader::new(stdout).read_line(&mut line);
        if line.trim() != "ready" {
            drop(stdin);
            let code = child.wait().ok().and_then(|s| s.code()).unwrap_or(1);
            let _ = std::fs::remove_dir_all(&dir);
            return Err(if code == 0 { 1 } else { code });
        }
        let sock = dir.join("root.sock");
        Ok(Broker { child, stdin: Some(stdin), dir, sock, token })
    }

    pub fn alive(&mut self) -> bool {
        matches!(self.child.try_wait(), Ok(None)) && self.sock.exists()
    }
}

impl Drop for Broker {
    fn drop(&mut self) {
        drop(self.stdin.take()); // the helper exits on end of input
        let _ = self.child.wait();
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

#[cfg(test)]
mod tests {
    use super::allowed;
    fn v(s: &str) -> Vec<String> {
        s.split_whitespace().map(str::to_string).collect()
    }
    #[test]
    fn pacman_only() {
        assert!(allowed(&v("pacman -S --needed --noconfirm -- spotify")));
        assert!(allowed(&v("pacman -U --noconfirm /home/u/.cache/yay/x/x.pkg.tar.zst")));
        assert!(allowed(&v("pacman -D --asdeps -- libfoo")));
        assert!(allowed(&v("/usr/bin/pacman -Rns --noconfirm -- -rootish-name")));
        assert!(!allowed(&v("sh -c id")));
        assert!(!allowed(&v("pacman --root /tmp/x -S foo")));
        assert!(!allowed(&v("pacman --config=/tmp/c -S foo")));
        assert!(!allowed(&v("pacman --config /tmp/c -S foo")));
        assert!(allowed(&v("pacman -S -y --noconfirm --config /etc/pacman.conf --")));
        assert!(!allowed(&v("pacman -Syr /tmp/x foo")));
        assert!(!allowed(&v("pacman --hookdir /tmp/h -S foo")));
        assert!(!allowed(&[]));
    }
}
