//! Pictures: app icons (JPEG XL from AppStream, PNG from icon themes) and
//! screenshots from the web, decoded on worker threads and uploaded as
//! textures on the UI thread.

use egui::{ColorImage, TextureHandle, TextureOptions};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Mutex};

pub enum Src {
    File(PathBuf),
    /// An installed package without AppStream data: its desktop file's icon,
    /// then the web.
    Installed(String),
    /// A package AppStream does not know (mostly the AUR): the icon of the
    /// app with the same name in Flathub's catalog, kept on disk.
    Web(String),
    Url(String),
}

enum Slot {
    Waiting,
    Ready(TextureHandle),
    Missing,
}

pub struct Icons {
    slots: HashMap<String, Slot>,
    tx: Sender<(String, Src)>,
    rx: Receiver<(String, Option<ColorImage>)>,
}

impl Icons {
    pub fn new(ctx: &egui::Context) -> Icons {
        let (tx, jobs) = channel::<(String, Src)>();
        let (done, rx) = channel();
        let jobs = Arc::new(Mutex::new(jobs));
        for _ in 0..3 {
            let jobs = jobs.clone();
            let done = done.clone();
            let ctx = ctx.clone();
            std::thread::spawn(move || {
                loop {
                    let next = jobs.lock().ok().and_then(|r| r.recv().ok());
                    let Some((key, src)) = next else { return };
                    let img = load(&src);
                    if done.send((key, img)).is_err() {
                        return;
                    }
                    ctx.request_repaint();
                }
            });
        }
        Icons { slots: HashMap::new(), tx, rx }
    }

    pub fn poll(&mut self, ctx: &egui::Context) {
        while let Ok((key, img)) = self.rx.try_recv() {
            let slot = match img {
                Some(img) => Slot::Ready(ctx.load_texture(&key, img, TextureOptions::LINEAR)),
                None => Slot::Missing,
            };
            self.slots.insert(key, slot);
        }
    }

    pub fn get(&mut self, key: &str, src: impl FnOnce() -> Option<Src>) -> Option<TextureHandle> {
        match self.slots.get(key) {
            Some(Slot::Ready(t)) => Some(t.clone()),
            Some(_) => None,
            None => {
                match src() {
                    Some(s) => {
                        self.slots.insert(key.to_string(), Slot::Waiting);
                        let _ = self.tx.send((key.to_string(), s));
                    }
                    None => {
                        self.slots.insert(key.to_string(), Slot::Missing);
                    }
                }
                None
            }
        }
    }

    pub fn waiting(&self, key: &str) -> bool {
        matches!(self.slots.get(key), Some(Slot::Waiting))
    }

    /// Forget a package's icon, after it was installed or removed.
    pub fn forget(&mut self, key: &str) {
        self.slots.remove(key);
    }
}

fn load(src: &Src) -> Option<ColorImage> {
    match src {
        Src::File(p) => load_file(p),
        Src::Installed(pkg) => crate::catalog::desktop_entry(pkg)
            .and_then(|(_, icon)| icon)
            .and_then(|icon| find_theme_icon(&icon))
            .and_then(|f| load_file(&f))
            .or_else(|| web_icon(pkg)),
        Src::Web(pkg) => web_icon(pkg),
        Src::Url(url) => {
            let mut resp = crate::aur::agent(20).get(url).call().ok()?;
            let bytes = resp.body_mut().with_config().limit(25 << 20).read_to_vec().ok()?;
            let img = image::load_from_memory(&bytes).ok()?;
            let img = if img.width() > 1400 { img.resize(1400, 1400 * 4, image::imageops::FilterType::Triangle) } else { img };
            let rgba = img.to_rgba8();
            Some(ColorImage::from_rgba_unmultiplied([rgba.width() as usize, rgba.height() as usize], &rgba))
        }
    }
}

fn load_file(path: &Path) -> Option<ColorImage> {
    if path.extension().and_then(|e| e.to_str()) == Some("jxl") {
        let img = jxl_oxide::JxlImage::builder().open(path).ok()?;
        let render = img.render_frame(0).ok()?;
        let mut stream = render.stream();
        let (w, h, ch) = (stream.width() as usize, stream.height() as usize, stream.channels() as usize);
        let mut buf = vec![0u8; w * h * ch];
        stream.write_to_buffer::<u8>(&mut buf);
        let mut rgba = Vec::with_capacity(w * h * 4);
        for px in buf.chunks_exact(ch) {
            match ch {
                1 => rgba.extend_from_slice(&[px[0], px[0], px[0], 255]),
                2 => rgba.extend_from_slice(&[px[0], px[0], px[0], px[1]]),
                3 => rgba.extend_from_slice(&[px[0], px[1], px[2], 255]),
                _ => rgba.extend_from_slice(&px[..4]),
            }
        }
        return Some(ColorImage::from_rgba_unmultiplied([w, h], &rgba));
    }
    let bytes = std::fs::read(path).ok()?;
    let img = image::load_from_memory(&bytes).ok()?;
    let img = if img.width() > 256 { img.resize(256, 256, image::imageops::FilterType::Lanczos3) } else { img };
    let rgba = img.to_rgba8();
    Some(ColorImage::from_rgba_unmultiplied([rgba.width() as usize, rgba.height() as usize], &rgba))
}

/// PNG icons only: the hicolor theme and pixmaps hold one for most apps.
pub fn find_theme_icon(name: &str) -> Option<PathBuf> {
    let p = Path::new(name);
    if p.is_absolute() {
        return p.is_file().then(|| p.to_path_buf());
    }
    let home = crate::theme::home();
    let bases = [
        home.join(".local/share/icons/hicolor"),
        PathBuf::from("/usr/share/icons/hicolor"),
    ];
    for size in ["128x128", "256x256", "96x96", "64x64", "512x512", "48x48"] {
        for base in &bases {
            let f = base.join(size).join("apps").join(format!("{name}.png"));
            if f.is_file() {
                return Some(f);
            }
        }
    }
    let f = PathBuf::from(format!("/usr/share/pixmaps/{name}.png"));
    f.is_file().then_some(f)
}

/// Whether a package name looks like an app, not a library, font or
/// language module: only those are looked up on the web.
pub fn app_like(name: &str) -> bool {
    const PRE: &[&str] = &[
        "lib", "python", "perl-", "ruby-", "haskell-", "ttf-", "otf-", "noto-fonts", "texlive-", "r-", "php", "lua",
        "nodejs-", "go-", "rust-", "ocaml-", "java-", "mingw-", "gst-", "qt5-", "qt6-", "kf5-", "kf6-", "xorg-", "linux-",
        "vim-", "emacs-", "fcitx", "ibus-", "tree-sitter", "gnome-shell-extension", "plasma5-applets", "cachyos-",
    ];
    const POST: &[&str] = &[
        "-docs", "-doc", "-debug", "-headers", "-dkms", "-data", "-common", "-libs", "-dev", "-devel", "-fonts", "-font",
        "-theme", "-themes", "-icons", "-cursors", "-plugin", "-plugins", "-keyring", "-utils", "-tools", "-cli", "-i18n",
    ];
    !PRE.iter().any(|p| name.starts_with(p)) && !POST.iter().any(|p| name.ends_with(p)) && !name.contains("-i18n-")
}

fn norm(s: &str) -> String {
    s.chars().filter(|c| c.is_alphanumeric()).flat_map(char::to_lowercase).collect()
}

/// The name an app is known by, from its package name:
/// `visual-studio-code-bin` → `visual studio code`.
fn app_words(pkg: &str) -> String {
    const TAILS: &[&str] = &[
        "-bin", "-git", "-appimage", "-desktop", "-stable", "-beta", "-nightly", "-electron", "-wayland", "-latest",
        "-qt", "-gtk", "-native", "-launcher-bin", "-x11", "-official", "-linux",
    ];
    let mut base = pkg.to_lowercase();
    loop {
        match TAILS.iter().find(|t| base.ends_with(*t) && base.len() > t.len() + 2) {
            Some(t) => base.truncate(base.len() - t.len()),
            None => break,
        }
    }
    base.replace(['-', '_', '.'], " ")
}

fn web_dir() -> PathBuf {
    let dir = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| crate::theme::home().join(".cache"))
        .join("archmarket/icons");
    let _ = std::fs::create_dir_all(&dir);
    dir
}

fn web_icon(pkg: &str) -> Option<ColorImage> {
    if pkg.contains('/') || !app_like(pkg) {
        return None;
    }
    let dir = web_dir();
    let file = dir.join(format!("{pkg}.png"));
    if file.is_file() {
        return load_file(&file);
    }
    // a miss is remembered for a month, so the same name is not asked again
    let miss = dir.join(format!("{pkg}.none"));
    let recent = std::fs::metadata(&miss)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.elapsed().ok())
        .map(|age| age.as_secs() < 30 * 24 * 3600)
        .unwrap_or(false);
    if recent {
        return None;
    }
    match fetch_web_icon(pkg) {
        Ok(Some(bytes)) => {
            let _ = std::fs::write(&file, &bytes);
            load_file(&file)
        }
        Ok(None) => {
            let _ = std::fs::write(&miss, b"");
            None
        }
        Err(()) => None, // offline: try again next time
    }
}

fn fetch_web_icon(pkg: &str) -> Result<Option<Vec<u8>>, ()> {
    let words = app_words(pkg);
    let want = norm(&words);
    if want.len() < 3 {
        return Ok(None);
    }
    let agent = crate::aur::agent(12);
    let mut resp = agent
        .post("https://flathub.org/api/v2/search")
        .send_json(serde_json::json!({ "query": words, "hits_per_page": 6 }))
        .map_err(|_| ())?;
    let v: serde_json::Value = resp.body_mut().read_json().map_err(|_| ())?;
    let hits = v["hits"].as_array().cloned().unwrap_or_default();
    let score = |h: &serde_json::Value| -> u8 {
        let name = norm(h["name"].as_str().unwrap_or(""));
        let id = norm(h["app_id"].as_str().unwrap_or("").rsplit('.').next().unwrap_or(""));
        if name == want || id == want {
            3
        } else if name.len() >= 4 && want.len() >= 4 && (name.starts_with(&want) || want.starts_with(&name)) {
            2
        } else if id.len() >= 4 && want.starts_with(&id) {
            1
        } else {
            0
        }
    };
    let best = hits.iter().map(|h| (score(h), h)).filter(|(s, _)| *s > 0).max_by_key(|(s, _)| *s);
    let Some((_, hit)) = best else { return Ok(None) };
    let Some(url) = hit["icon"].as_str().filter(|u| u.starts_with("https://")) else { return Ok(None) };
    let mut img = agent.get(url).call().map_err(|_| ())?;
    let bytes = img.body_mut().with_config().limit(4 << 20).read_to_vec().map_err(|_| ())?;
    Ok(image::load_from_memory(&bytes).is_ok().then_some(bytes))
}
