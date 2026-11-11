//! How far a job has got, from the output of pacman, yay and makepkg.
//!
//! pacman prints real percentages only on a terminal, so the root helper
//! runs it in a pty: the download shows as "Total ( 3/17) … 24%" (or the
//! single file's line), each package in a transaction as
//! "(n/m) installing foo […] 100%". A transaction is split into download,
//! checks, install and hooks. An AUR job is a row of steps: dependencies
//! from the repositories, the build (makepkg's "==>" stages, and curl's
//! meter while sources download), then installing the built package. The
//! value only ever grows, and stays under 100 % until the job ends.

#[derive(Clone, Copy, PartialEq, Debug)]
enum Phase {
    Idle,
    Download,
    Checks,
    Install,
    Hooks,
    Build,
}

#[derive(Clone, Debug)]
pub struct Meter {
    aur: bool,
    /// The part of the whole job the current pacman transaction covers.
    base: f32,
    span: f32,
    phase: Phase,
    downloads: bool,
    saw_total: bool,
    built: bool,
    sources: bool,
    value: f32,
    pub last_was_bar: bool,
}

const CHECKS: [&str; 5] = [
    "checking keys",
    "checking package integrity",
    "loading package files",
    "checking for file conflicts",
    "checking available disk space",
];

/// The trailing "NN%" of a progress line.
fn pct(line: &str) -> Option<f32> {
    let t = line.trim_end();
    let num = t.strip_suffix('%')?;
    let digits: String = num.chars().rev().take_while(|c| c.is_ascii_digit()).collect::<Vec<_>>().into_iter().rev().collect();
    let v: f32 = digits.parse().ok()?;
    (v <= 100.0).then_some(v / 100.0)
}

/// "(3/7) installing foo" → (3, 7, "installing foo").
fn step(line: &str) -> Option<(f32, f32, String)> {
    let inner = line.trim_start().strip_prefix('(')?;
    let close = inner.find(')')?;
    let (a, b) = inner[..close].split_once('/')?;
    let (a, b): (f32, f32) = (a.trim().parse().ok()?, b.trim().parse().ok()?);
    (b > 0.0).then(|| (a, b, inner[close + 1..].trim().to_lowercase()))
}

/// curl's meter: "100  120M  100  120M    0     0  10.1M      0  0:00:11 …".
fn curl_pct(line: &str) -> Option<f32> {
    let mut it = line.split_whitespace();
    let first: f32 = it.next()?.parse().ok()?;
    let second = it.next()?;
    let looks = second.chars().next()?.is_ascii_digit() && it.clone().count() >= 8;
    (looks && first <= 100.0).then_some(first / 100.0)
}

impl Meter {
    pub fn new(aur: bool) -> Meter {
        let (base, span) = if aur { (0.08, 0.20) } else { (0.0, 1.0) };
        Meter {
            aur,
            base,
            span,
            phase: Phase::Idle,
            downloads: false,
            saw_total: false,
            built: false,
            sources: false,
            value: 0.0,
            last_was_bar: false,
        }
    }

    pub fn value(&self) -> f32 {
        self.value
    }

    fn set(&mut self, v: f32) {
        let v = v.clamp(0.0, 0.99);
        if v > self.value {
            self.value = v;
        }
    }

    /// Progress inside the current transaction (0..1) → the whole job.
    fn inner(&mut self, phase: Phase, x: f32) {
        let x = x.clamp(0.0, 1.0);
        let (a, b) = if self.downloads {
            match phase {
                Phase::Download => (0.0, 0.45),
                Phase::Checks => (0.45, 0.10),
                Phase::Install => (0.55, 0.35),
                _ => (0.90, 0.10),
            }
        } else {
            match phase {
                Phase::Download => (0.0, 0.0),
                Phase::Checks => (0.0, 0.15),
                Phase::Install => (0.15, 0.65),
                _ => (0.80, 0.20),
            }
        };
        let v = self.base + self.span * (a + b * x);
        self.set(v);
    }

    fn new_transaction(&mut self, downloads: bool) {
        // An AUR job: dependencies first, the built package after the build.
        if self.aur && self.built {
            self.base = 0.76;
            self.span = 0.23;
        }
        self.downloads = downloads;
        self.saw_total = false;
    }

    /// Reads one line. Returns true when it is a progress bar, which the log
    /// keeps only once (the newest replaces the one before).
    pub fn feed(&mut self, line: &str) -> bool {
        let l = line.trim();
        let low = l.to_lowercase();
        let bar = pct(l).is_some() && (l.contains('[') || l.contains("B/s"));

        if low.starts_with(":: retrieving packages") {
            self.new_transaction(true);
            self.phase = Phase::Download;
            self.inner(Phase::Download, 0.0);
            return false;
        }
        if low.starts_with(":: processing package changes") {
            if self.phase == Phase::Idle || self.phase == Phase::Build {
                self.new_transaction(false);
            }
            self.phase = Phase::Install;
            self.inner(Phase::Install, 0.0);
            return false;
        }
        if low.starts_with(":: running post-transaction hooks") {
            self.phase = Phase::Hooks;
            self.inner(Phase::Hooks, 0.0);
            return false;
        }

        // makepkg
        if let Some(stage) = low.strip_prefix("==> ") {
            self.sources = false;
            let at = if stage.starts_with("making package") {
                Some(0.32)
            } else if stage.starts_with("retrieving sources") {
                self.sources = true;
                Some(0.34)
            } else if stage.starts_with("validating source") {
                Some(0.56)
            } else if stage.starts_with("extracting sources") {
                Some(0.58)
            } else if stage.starts_with("starting prepare") {
                Some(0.60)
            } else if stage.starts_with("starting build") {
                Some(0.62)
            } else if stage.starts_with("starting check") {
                Some(0.66)
            } else if stage.starts_with("entering fakeroot") || stage.starts_with("starting package") {
                Some(0.68)
            } else if stage.starts_with("tidying install") {
                Some(0.70)
            } else if stage.starts_with("creating package") {
                Some(0.72)
            } else if stage.starts_with("leaving fakeroot") || stage.starts_with("finished making") {
                self.built = true;
                Some(0.75)
            } else {
                None
            };
            if let Some(v) = at.filter(|_| self.aur) {
                self.phase = Phase::Build;
                self.set(v);
            }
            return false;
        }
        if self.aur && self.phase == Phase::Build && self.sources {
            if let Some(p) = curl_pct(l) {
                self.set(0.34 + 0.21 * p);
                return true;
            }
        }

        // pacman transaction
        if self.phase == Phase::Download {
            if low.starts_with("total (") {
                self.saw_total = true;
                if let Some(p) = pct(l) {
                    self.inner(Phase::Download, p);
                }
                return true;
            }
            if bar && !self.saw_total {
                if let Some(p) = pct(l) {
                    self.inner(Phase::Download, p);
                }
                return true;
            }
            if bar {
                return true;
            }
        }
        if let Some((n, m, what)) = step(l) {
            if let Some(k) = CHECKS.iter().position(|c| what.starts_with(c)) {
                if self.phase == Phase::Idle || self.phase == Phase::Build {
                    self.new_transaction(false);
                }
                self.phase = Phase::Checks;
                let p = pct(l).unwrap_or(n / m);
                self.inner(Phase::Checks, (k as f32 + p) / CHECKS.len() as f32);
                return bar;
            }
            if ["installing", "upgrading", "reinstalling", "downgrading", "removing"].iter().any(|w| what.starts_with(w)) {
                self.phase = Phase::Install;
                let p = pct(l).unwrap_or(1.0);
                self.inner(Phase::Install, (n - 1.0 + p) / m);
                return bar;
            }
            if self.phase == Phase::Hooks {
                self.inner(Phase::Hooks, n / m);
                return false;
            }
        }
        // yay itself, before anything else happens
        if self.aur && self.value < 0.08 && (low.starts_with(":: (") || low.contains("downloaded pkgbuild")) {
            self.set(0.05);
        }
        bar
    }
}

#[cfg(test)]
mod tests {
    use super::Meter;

    #[test]
    fn repo_install_grows_to_the_end() {
        let mut m = Meter::new(false);
        let mut last = 0.0;
        for l in [
            ":: Retrieving packages...",
            " Total ( 0/3)   0.0   B  0.00   B/s 00:00 [----] 0%",
            " Total ( 1/3)   2.0 MiB  3.35 MiB/s 00:10 [-c o] 40%",
            " Total ( 3/3)   5.0 MiB  3.35 MiB/s 00:00 [----] 100%",
            "(3/3) checking keys in keyring [####] 100%",
            "(3/3) checking package integrity [####] 100%",
            "(3/3) loading package files [####] 100%",
            "(3/3) checking for file conflicts [####] 100%",
            "(3/3) checking available disk space [####] 100%",
            ":: Processing package changes...",
            "(1/3) installing a [####] 100%",
            "(2/3) installing b [####] 100%",
            "(3/3) installing c [##--] 50%",
            ":: Running post-transaction hooks...",
            "(1/2) Arming ConditionNeedsUpdate...",
            "(2/2) Updating icon theme caches...",
        ] {
            m.feed(l);
            assert!(m.value() >= last, "{l}");
            last = m.value();
        }
        assert!(last > 0.95 && last < 1.0, "{last}");
    }

    #[test]
    fn aur_build_then_install() {
        let mut m = Meter::new(true);
        m.feed(":: (1/1) Downloaded PKGBUILD: spotify");
        m.feed("==> Making package: spotify 1:1.3-1");
        m.feed("==> Retrieving sources...");
        m.feed("  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current");
        m.feed(" 50  120M   50   60M    0     0  10.1M      0  0:00:11  0:00:05  0:00:06 10.1M");
        let mid = m.value();
        assert!(mid > 0.40 && mid < 0.50, "{mid}");
        m.feed("==> Leaving fakeroot environment.");
        m.feed("(1/1) checking keys in keyring [####] 100%");
        m.feed(":: Processing package changes...");
        m.feed("(1/1) installing spotify [####] 100%");
        assert!(m.value() > 0.9, "{}", m.value());
    }
}

#[cfg(test)]
mod sample {
    /// Feeds a real recorded pacman run: ARCHMARKET_SAMPLE=file cargo test -- --ignored
    #[test]
    #[ignore]
    fn recorded_output() {
        let Ok(path) = std::env::var("ARCHMARKET_SAMPLE") else { return };
        let raw = std::fs::read(path).unwrap();
        let text = String::from_utf8_lossy(&raw);
        let mut m = super::Meter::new(false);
        let mut shown = -1i32;
        for line in text.split(['\r', '\n']) {
            let clean: String = {
                let mut out = String::new();
                let mut it = line.chars().peekable();
                while let Some(c) = it.next() {
                    if c == '\x1b' {
                        if it.peek() == Some(&'[') {
                            it.next();
                            for c in it.by_ref() {
                                if c.is_ascii_alphabetic() {
                                    break;
                                }
                            }
                        }
                        continue;
                    }
                    out.push(c);
                }
                out
            };
            if clean.trim().is_empty() {
                continue;
            }
            m.feed(&clean);
            let p = (m.value() * 100.0) as i32;
            if p / 5 != shown / 5 {
                shown = p;
                println!("{p:3}%  {}", clean.trim().chars().take(70).collect::<String>());
            }
        }
    }
}
