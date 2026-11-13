//! Whether the internet is reachable, watched in the background.
//!
//! Everything that needs the network (the AUR, Flathub icons, screenshots,
//! the AppStream catalog, installs) asks here first, so an offline store
//! answers at once with a plain sentence instead of spinning, and comes back
//! by itself: each return of the connection bumps `generation()`, and the
//! window then repeats what failed.

use std::net::{TcpStream, ToSocketAddrs};
use std::sync::atomic::{AtomicU8, AtomicU64, Ordering};
use std::sync::mpsc::{Sender, channel};
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

const UNKNOWN: u8 = 0;
const ONLINE: u8 = 1;
const OFFLINE: u8 = 2;

static STATE: AtomicU8 = AtomicU8::new(UNKNOWN);
static GENERATION: AtomicU64 = AtomicU64::new(0);
static KICK: OnceLock<Mutex<Sender<()>>> = OnceLock::new();

/// Hosts the store talks to; one answering is enough.
const PROBES: &[&str] = &["aur.archlinux.org:443", "geo.mirror.pkgbuild.com:443", "flathub.org:443"];

/// Start watching. Repaints the window on every change.
pub fn start(ctx: egui::Context) {
    let (tx, rx) = channel::<()>();
    if KICK.set(Mutex::new(tx)).is_err() {
        return;
    }
    std::thread::spawn(move || {
        loop {
            let now = if probe() { ONLINE } else { OFFLINE };
            let before = STATE.swap(now, Ordering::SeqCst);
            if before != now {
                if now == ONLINE && before == OFFLINE {
                    GENERATION.fetch_add(1, Ordering::SeqCst);
                }
                ctx.request_repaint();
            }
            // offline: look often, so the store wakes up soon after the
            // connection is back; online: only a light check now and then
            let wait = if now == ONLINE { 30 } else { 4 };
            let _ = rx.recv_timeout(Duration::from_secs(wait));
            while rx.try_recv().is_ok() {}
        }
    });
}

fn probe() -> bool {
    if let Ok(v) = std::env::var("ARCHMARKET_OFFLINE") {
        // testing: a file that exists means offline
        return !std::path::Path::new(&v).exists();
    }
    // NetworkManager knows without any traffic when nothing is connected
    if let Ok(out) = std::process::Command::new("nmcli")
        .args(["-t", "-f", "STATE", "general"])
        .env("LC_ALL", "C")
        .output()
    {
        let s = String::from_utf8_lossy(&out.stdout);
        if out.status.success() && matches!(s.trim(), "disconnected" | "asleep") {
            return false;
        }
    }
    PROBES.iter().any(|host| {
        host.to_socket_addrs()
            .map(|addrs| addrs.take(2).any(|a| TcpStream::connect_timeout(&a, Duration::from_secs(4)).is_ok()))
            .unwrap_or(false)
    })
}

/// True only once a check found no connection. Before the first answer the
/// store behaves as online, so nothing is refused on a guess.
pub fn offline() -> bool {
    STATE.load(Ordering::SeqCst) == OFFLINE
}

/// Bumped each time the connection comes back after being lost.
pub fn generation() -> u64 {
    GENERATION.load(Ordering::SeqCst)
}

/// A request just failed for lack of network: look again now.
pub fn lost() {
    if let Some(k) = KICK.get() {
        if let Ok(tx) = k.lock() {
            let _ = tx.send(());
        }
    }
}

/// Agent for small requests: gives up fast when the network hangs.
pub fn agent(secs: u64) -> ureq::Agent {
    ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(secs)))
        .timeout_resolve(Some(Duration::from_secs(6)))
        .timeout_connect(Some(Duration::from_secs(6)))
        .user_agent(concat!("archmarket/", env!("CARGO_PKG_VERSION")))
        .build()
        .into()
}

/// Agent for big downloads: no total limit, but a stalled transfer ends.
pub fn download_agent() -> ureq::Agent {
    ureq::Agent::config_builder()
        .timeout_global(None)
        .timeout_resolve(Some(Duration::from_secs(8)))
        .timeout_connect(Some(Duration::from_secs(10)))
        .timeout_recv_response(Some(Duration::from_secs(30)))
        .timeout_per_read(Some(Duration::from_secs(30)))
        .user_agent(concat!("archmarket/", env!("CARGO_PKG_VERSION")))
        .build()
        .into()
}

/// Whether an error means the network, not the server, failed.
pub fn is_network(e: &ureq::Error) -> bool {
    !matches!(
        e,
        ureq::Error::StatusCode(_) | ureq::Error::Json(_) | ureq::Error::BodyExceedsLimit(_) | ureq::Error::BadUri(_)
    )
}
