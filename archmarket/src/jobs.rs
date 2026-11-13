//! Installs, removals and upgrades, one at a time (pacman holds one lock).
//!
//! Each command runs in its own process group with its output going to a
//! file, never to a pipe of ours: closing the window or a crash of the store
//! can then never break pacman in the middle of a transaction. The worker
//! follows that file for the progress shown in the window.
//!
//! Root goes through `pkexec`, so the desktop's own polkit dialog asks for
//! the password. AUR builds run as the user through yay, which calls pkexec
//! only for its pacman steps.

use crate::broker::{self, Broker};
use std::collections::VecDeque;
use std::io::{Read, Seek, SeekFrom};
use std::os::unix::process::CommandExt;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::{Arc, Condvar, Mutex};
use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Install,
    Remove,
    Upgrade,
}

#[derive(Clone, Debug, PartialEq)]
pub enum State {
    Queued,
    Waiting,
    Running,
    Done,
    Failed(String),
    Cancelled,
}

#[derive(Clone, Debug)]
pub struct Job {
    pub id: u64,
    pub kind: Kind,
    pub pkgs: Vec<String>,
    pub aur: bool,
    pub state: State,
    pub stage: String,
    pub progress: Option<f32>,
    pub log: Vec<String>,
    pub ended: Option<Instant>,
    pub seen: bool,
}

impl Job {
    pub fn active(&self) -> bool {
        matches!(self.state, State::Queued | State::Waiting | State::Running)
    }
}

#[derive(Default)]
struct Inner {
    jobs: Vec<Job>,
    queue: VecDeque<u64>,
    next: u64,
    /// Bumped each time a job ends, so the UI reloads what is installed.
    finished: u64,
}

#[derive(Clone)]
pub struct Jobs {
    inner: Arc<(Mutex<Inner>, Condvar)>,
}

fn runtime_dir() -> PathBuf {
    let base = std::env::var_os("XDG_RUNTIME_DIR").map(PathBuf::from).unwrap_or_else(std::env::temp_dir);
    let dir = base.join("archmarket");
    let _ = std::fs::create_dir_all(&dir);
    dir
}

impl Jobs {
    pub fn new(ctx: egui::Context) -> Jobs {
        let jobs = Jobs { inner: Arc::new((Mutex::new(Inner::default()), Condvar::new())) };
        let worker = jobs.clone();
        std::thread::spawn(move || worker.work(ctx));
        jobs
    }

    pub fn add(&self, kind: Kind, pkgs: Vec<String>, aur: bool) -> u64 {
        let (lock, cv) = &*self.inner;
        let mut g = lock.lock().unwrap();
        g.next += 1;
        let id = g.next;
        g.jobs.push(Job {
            id,
            kind,
            pkgs,
            aur,
            state: State::Queued,
            stage: String::new(),
            progress: None,
            log: Vec::new(),
            ended: None,
            seen: false,
        });
        g.queue.push_back(id);
        cv.notify_all();
        id
    }

    pub fn cancel_queued(&self, id: u64) {
        let mut g = self.inner.0.lock().unwrap();
        g.queue.retain(|&q| q != id);
        if let Some(j) = g.jobs.iter_mut().find(|j| j.id == id && j.state == State::Queued) {
            j.state = State::Cancelled;
            j.ended = Some(Instant::now());
        }
    }

    pub fn snapshot(&self) -> (Vec<Job>, u64) {
        let g = self.inner.0.lock().unwrap();
        (g.jobs.clone(), g.finished)
    }

    pub fn mark_seen(&self) {
        let mut g = self.inner.0.lock().unwrap();
        for j in g.jobs.iter_mut().filter(|j| !j.active()) {
            j.seen = true;
        }
    }

    pub fn clear_finished(&self) {
        let mut g = self.inner.0.lock().unwrap();
        g.jobs.retain(|j| j.active());
    }

    pub fn busy(&self) -> bool {
        self.inner.0.lock().unwrap().jobs.iter().any(|j| j.active())
    }

    /// The job working on (or waiting for) a package, if any.
    pub fn for_pkg(jobs: &[Job], name: &str) -> Option<Job> {
        jobs.iter().rev().find(|j| j.active() && j.pkgs.iter().any(|p| p == name)).cloned()
    }

    fn update(&self, id: u64, f: impl FnOnce(&mut Job)) {
        let mut g = self.inner.0.lock().unwrap();
        if let Some(j) = g.jobs.iter_mut().find(|j| j.id == id) {
            f(j);
        }
    }

    fn work(&self, ctx: egui::Context) {
        // One root helper serves the whole queue: one password.
        let mut helper: Option<Broker> = None;
        loop {
            let (job, _) = {
                let (lock, cv) = &*self.inner;
                let mut g = lock.lock().unwrap();
                if g.queue.is_empty() {
                    drop(helper.take());
                }
                while g.queue.is_empty() {
                    g = cv.wait(g).unwrap();
                }
                let id = g.queue.pop_front().unwrap();
                let job = g.jobs.iter().find(|j| j.id == id).cloned();
                (job, ())
            };
            let Some(job) = job else { continue };
            let result = self.run(&job, &ctx, &mut helper);
            {
                let mut g = self.inner.0.lock().unwrap();
                if let Some(j) = g.jobs.iter_mut().find(|j| j.id == job.id) {
                    j.state = match result {
                        Ok(()) => State::Done,
                        Err(e) => State::Failed(e),
                    };
                    j.progress = None;
                    j.ended = Some(Instant::now());
                }
                g.finished += 1;
            }
            ctx.request_repaint();
        }
    }

    fn run(&self, job: &Job, ctx: &egui::Context, helper: &mut Option<Broker>) -> Result<(), String> {
        // Another package manager holds the lock: wait for it, visibly.
        let lock = std::path::Path::new("/var/lib/pacman/db.lck");
        if lock.exists() {
            self.update(job.id, |j| j.state = State::Waiting);
            ctx.request_repaint();
            let start = Instant::now();
            while lock.exists() {
                if start.elapsed() > Duration::from_secs(600) {
                    return Err(crate::i18n::t("Another package manager kept pacman busy").into());
                }
                std::thread::sleep(Duration::from_millis(500));
            }
        }
        self.update(job.id, |j| j.state = State::Running);
        ctx.request_repaint();

        let dir = runtime_dir();
        if !helper.as_mut().map(|h| h.alive()).unwrap_or(false) {
            *helper = None;
            self.update(job.id, |j| j.stage = crate::i18n::t("Waiting for the password").into());
            ctx.request_repaint();
            match Broker::start(&dir) {
                Ok(h) => *helper = Some(h),
                Err(126) => return Err(crate::i18n::t("Password prompt was cancelled").into()),
                Err(127) => return Err(crate::i18n::t("Not authorized").into()),
                Err(_) => return Err(crate::i18n::t("Could not get administrator rights").into()),
            }
            self.update(job.id, |j| j.stage.clear());
        }
        let h = helper.as_ref().unwrap();
        let exe = std::env::current_exe().map_err(|e| e.to_string())?.to_string_lossy().into_owned();
        let argv = command(job, &exe);
        let log = dir.join(format!("job-{}-{}.log", std::process::id(), job.id));
        let code = dir.join(format!("job-{}-{}.code", std::process::id(), job.id));
        let _ = std::fs::remove_file(&code);
        std::fs::write(&log, b"").map_err(|e| e.to_string())?;
        // sh writes the exit code once the command ends; the command's output
        // goes to the file only.
        let script = r#"log="$1"; code="$2"; shift 2; "$@" >"$log" 2>&1 </dev/null; echo $? >"$code.tmp"; mv "$code.tmp" "$code""#;
        let mut child = Command::new("sh")
            .arg("-c")
            .arg(script)
            .arg("sh")
            .arg(&log)
            .arg(&code)
            .args(&argv)
            .env("LC_ALL", "C")
            .env(broker::ENV_SOCK, &h.sock)
            .env(broker::ENV_TOKEN, &h.token)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .process_group(0)
            .spawn()
            .map_err(|e| e.to_string())?;

        let mut file = std::fs::File::open(&log).map_err(|e| e.to_string())?;
        let mut pos = 0u64;
        let mut partial = String::new();
        let mut meter = crate::meter::Meter::new(job.aur || job.kind == Kind::Upgrade && argv.first().map(|a| a == "yay").unwrap_or(false));
        loop {
            let ended = code.exists();
            let mut chunk = Vec::new();
            if file.seek(SeekFrom::Start(pos)).is_ok() && file.read_to_end(&mut chunk).is_ok() && !chunk.is_empty() {
                pos += chunk.len() as u64;
                partial.push_str(&String::from_utf8_lossy(&chunk));
                let mut lines: Vec<String> = Vec::new();
                while let Some(nl) = partial.find(['\n', '\r']) {
                    let line: String = partial[..nl].to_string();
                    partial.drain(..=nl);
                    let clean = strip_ansi(&line);
                    if !clean.trim().is_empty() {
                        lines.push(clean);
                    }
                }
                if !lines.is_empty() {
                    self.update(job.id, |j| {
                        for l in lines {
                            let was_bar = meter.last_was_bar;
                            let is_bar = meter.feed(&l);
                            meter.last_was_bar = is_bar;
                            if meter.value() > 0.0 {
                                j.progress = Some(meter.value());
                            }
                            if let Some(s) = stage_of(&l) {
                                j.stage = s;
                            }
                            // a bar redraws itself many times: keep only its newest state
                            if is_bar && was_bar {
                                j.log.pop();
                            }
                            j.log.push(l.trim_end().to_string());
                        }
                        let n = j.log.len();
                        if n > 4000 {
                            j.log.drain(..n - 4000);
                        }
                    });
                    ctx.request_repaint();
                }
            }
            if ended {
                break;
            }
            std::thread::sleep(Duration::from_millis(120));
        }
        let _ = child.wait();
        let status: i32 = std::fs::read_to_string(&code).ok().and_then(|s| s.trim().parse().ok()).unwrap_or(1);
        let _ = std::fs::remove_file(&code);
        let _ = std::fs::remove_file(&log);
        match status {
            0 => Ok(()),
            126 => Err(crate::i18n::t("Password prompt was cancelled").into()),
            127 => Err(crate::i18n::t("Not authorized").into()),
            _ => {
                let tail = self.inner.0.lock().unwrap().jobs.iter().find(|j| j.id == job.id).map(|j| j.log.clone()).unwrap_or_default();
                Err(explain(&tail))
            }
        }
    }
}

fn yay_flags(exe: &str) -> Vec<String> {
    let mut v: Vec<String> = [
        "--noconfirm",
        "--answerdiff", "None",
        "--answerclean", "None",
        "--answeredit", "None",
        "--answerupgrade", "None",
        "--removemake",
        "--sudoflags", "--sudo-proxy",
    ]
    .iter()
    .map(|s| s.to_string())
    .collect();
    v.push("--sudo".into());
    v.push(exe.into());
    v
}

/// Root steps go through the helper: `archmarket --sudo-proxy pacman …`.
fn command(job: &Job, exe: &str) -> Vec<String> {
    let s = |v: &[&str]| v.iter().map(|x| x.to_string()).collect::<Vec<String>>();
    let root = |v: &[&str]| {
        let mut a = vec![exe.to_string(), "--sudo-proxy".to_string()];
        a.extend(v.iter().map(|x| x.to_string()));
        a
    };
    let mut argv = match job.kind {
        Kind::Install if job.aur => {
            let mut a = s(&["yay", "-S", "--needed"]);
            a.extend(yay_flags(exe));
            a
        }
        Kind::Install => root(&["pacman", "-S", "--needed", "--noconfirm"]),
        Kind::Remove => root(&["pacman", "-Rns", "--noconfirm"]),
        Kind::Upgrade if job.aur && crate::catalog::have("yay") => {
            let mut a = s(&["yay", "-Syu"]);
            a.extend(yay_flags(exe));
            a
        }
        Kind::Upgrade => root(&["pacman", "-Syu", "--noconfirm"]),
    };
    argv.push("--".into());
    argv.extend(job.pkgs.iter().cloned());
    if job.kind == Kind::Upgrade {
        argv.pop_if(|a| a == "--");
    }
    argv
}

fn strip_ansi(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\x1b' {
            if chars.peek() == Some(&'[') {
                chars.next();
                for c in chars.by_ref() {
                    if c.is_ascii_alphabetic() {
                        break;
                    }
                }
            }
            continue;
        }
        if c.is_control() && c != '\t' {
            continue;
        }
        out.push(c);
    }
    out
}

fn stage_of(line: &str) -> Option<String> {
    // drop a progress bar's tail: "(1/2) installing foo   [###--]  60%"
    let l = match line.find(" [") {
        Some(i) => line[..i].trim(),
        None => line.trim(),
    };
    if l.starts_with("::") || l.starts_with("==>") || l.starts_with('(') {
        let t = l.trim_start_matches(':').trim_start_matches("==>").trim();
        if !t.is_empty() && t.len() < 160 {
            return Some(t.to_string());
        }
    }
    None
}

fn explain(log: &[String]) -> String {
    let text = log.join("\n").to_lowercase();
    let t = crate::i18n::t;
    let network = [
        "could not resolve host",
        "failed to connect",
        "couldn't connect",
        "connection timed out",
        "operation too slow",
        "network is unreachable",
        "connection refused",
        "connection reset",
        "dial tcp",
        "no such host",
        "temporary failure in name resolution",
        "request failed",
    ];
    if network.iter().any(|n| text.contains(n)) || (text.contains("failed retrieving file") && crate::net::offline()) {
        crate::net::lost();
        return t("The internet connection was lost. Try again when it is back").into();
    }
    if text.contains("failed retrieving file") || text.contains("error: failed to retrieve some files") {
        return t("A file is missing on the mirror. Update the system first, then try again").into();
    }
    if text.contains("could not satisfy dependencies") || text.contains("breaks dependency") {
        return t("Other packages depend on it").into();
    }
    if text.contains("conflicting") || text.contains("are in conflict") {
        return t("It conflicts with an installed package").into();
    }
    if text.contains("unable to lock database") {
        return t("pacman is busy with something else").into();
    }
    if text.contains("target not found") || text.contains("could not find all required packages") {
        return t("Package not found").into();
    }
    if text.contains("failed to build") || text.contains("error making") {
        return t("The AUR package failed to build").into();
    }
    log.iter()
        .rev()
        .find(|l| l.to_lowercase().contains("error"))
        .cloned()
        .unwrap_or_else(|| t("Something went wrong, see the log").into())
}

#[cfg(test)]
mod tests {
    use super::explain;
    use crate::i18n::t;

    fn lines(v: &[&str]) -> Vec<String> {
        v.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn lost_connection_is_named() {
        let log = lines(&[
            ":: Retrieving packages...",
            "error: failed retrieving file 'gimp-3.2.0-1-x86_64.pkg.tar.zst' from mirror : Could not resolve host: mirror",
            "error: failed to commit transaction (failed to retrieve some files)",
        ]);
        let lost = t("The internet connection was lost. Try again when it is back");
        assert_eq!(explain(&log), lost);
        let yay = lines(&[" -> request failed: Get \"https://aur.archlinux.org/rpc\": dial tcp: connect: network is unreachable"]);
        assert_eq!(explain(&yay), lost);
    }

    #[test]
    fn missing_file_on_mirror_is_not_the_network() {
        let log = lines(&["error: failed retrieving file 'x.pkg.tar.zst' from mirror : The requested URL returned error: 404"]);
        assert_eq!(explain(&log), t("A file is missing on the mirror. Update the system first, then try again"));
    }
}
