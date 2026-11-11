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
    /// An installed package without AppStream data: its desktop file's icon.
    Installed(String),
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
        Src::Installed(pkg) => {
            let (_, icon) = crate::catalog::desktop_entry(pkg)?;
            let icon = icon?;
            load_file(&find_theme_icon(&icon)?)
        }
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
