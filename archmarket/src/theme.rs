//! Colors. On Falcon they come from the wallpaper (`colors.json` written by
//! matugen), so the store changes with the rest of the desktop. Anywhere else
//! a calm dark palette is used.

use egui::Color32;
use std::path::PathBuf;

#[derive(Clone, Debug)]
pub struct Pal {
    pub accent: Color32,
    pub accent_text: Color32,
    pub bg: Color32,
    pub pill: Color32,
    pub text: Color32,
    pub muted: Color32,
    pub outline: Color32,
    pub error: Color32,
    pub good: Color32,
    pub dark: bool,
}

pub fn hex(s: &str) -> Option<Color32> {
    let s = s.trim().trim_start_matches('#');
    if s.len() != 6 {
        return None;
    }
    let v = u32::from_str_radix(s, 16).ok()?;
    Some(Color32::from_rgb((v >> 16) as u8, (v >> 8) as u8, v as u8))
}

fn colors_file() -> PathBuf {
    let state = std::env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".local/state"));
    state.join("falcon/colors.json")
}

pub fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/tmp"))
}

impl Pal {
    pub fn load() -> Pal {
        let mut p = Pal {
            accent: Color32::from_rgb(0x9c, 0xc8, 0xff),
            accent_text: Color32::from_rgb(0x00, 0x31, 0x5c),
            bg: Color32::from_rgb(0x12, 0x14, 0x18),
            pill: Color32::from_rgb(0x0c, 0x0e, 0x11),
            text: Color32::from_rgb(0xe3, 0xe6, 0xec),
            muted: Color32::from_rgb(0xb8, 0xbf, 0xca),
            outline: Color32::from_rgb(0x44, 0x4a, 0x54),
            error: Color32::from_rgb(0xff, 0xb4, 0xab),
            good: Color32::from_rgb(0x8f, 0xd9, 0xa8),
            dark: true,
        };
        if let Ok(text) = std::fs::read_to_string(colors_file()) {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&text) {
                let get = |k: &str| v.get(k).and_then(|x| x.as_str()).and_then(hex);
                if let Some(c) = get("accent") { p.accent = c; }
                if let Some(c) = get("accentText") { p.accent_text = c; }
                if let Some(c) = get("surface") { p.bg = c; }
                if let Some(c) = get("pill") { p.pill = c; }
                if let Some(c) = get("text") { p.text = c; }
                if let Some(c) = get("muted") { p.muted = c; }
                if let Some(c) = get("outline") { p.outline = c; }
                if let Some(c) = get("error") { p.error = c; }
                if let Some(c) = get("good") { p.good = c; }
            }
        }
        p.dark = luma(p.bg) < 0.5;
        p
    }

    /// Color of a repository badge. Official repositories share the accent's
    /// family, the AUR is always warm so it is easy to tell apart.
    pub fn source(&self, repo: &str) -> Color32 {
        let (h, s) = match repo {
            "aur" => (28.0, 0.88),
            "core" | "cachyos-core-v3" | "cachyos-core-v4" | "cachyos-core-znver4" => (205.0, 0.75),
            "multilib" => (275.0, 0.62),
            r if r.starts_with("cachyos") => (168.0, 0.60),
            "extra" => return self.accent,
            _ => (130.0, 0.45),
        };
        hsl(h, s, if self.dark { 0.72 } else { 0.40 })
    }

    /// The window's own floor: translucent, so niri's blur shows through.
    pub fn floor(&self) -> Color32 {
        alpha(self.bg, if self.dark { 0.82 } else { 0.86 })
    }

    pub fn card(&self) -> Color32 {
        alpha(self.text, if self.dark { 0.045 } else { 0.06 })
    }

    pub fn card_hover(&self) -> Color32 {
        alpha(self.text, if self.dark { 0.085 } else { 0.10 })
    }

    pub fn line(&self) -> Color32 {
        alpha(self.text, 0.08)
    }
}

pub fn alpha(c: Color32, a: f32) -> Color32 {
    let [r, g, b, _] = c.to_srgba_unmultiplied();
    Color32::from_rgba_unmultiplied(r, g, b, (a.clamp(0.0, 1.0) * 255.0).round() as u8)
}

pub fn mix(a: Color32, b: Color32, t: f32) -> Color32 {
    let t = t.clamp(0.0, 1.0);
    let [ar, ag, ab, aa] = a.to_srgba_unmultiplied();
    let [br, bg, bb, ba] = b.to_srgba_unmultiplied();
    let l = |x: u8, y: u8| (x as f32 + (y as f32 - x as f32) * t).round() as u8;
    Color32::from_rgba_unmultiplied(l(ar, br), l(ag, bg), l(ab, bb), l(aa, ba))
}

pub fn luma(c: Color32) -> f32 {
    (0.2126 * c.r() as f32 + 0.7152 * c.g() as f32 + 0.0722 * c.b() as f32) / 255.0
}

pub fn hsl(h: f32, s: f32, l: f32) -> Color32 {
    let h = h.rem_euclid(360.0) / 360.0;
    let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s };
    let p = 2.0 * l - q;
    let f = |mut t: f32| {
        if t < 0.0 { t += 1.0; }
        if t > 1.0 { t -= 1.0; }
        let v = if t < 1.0 / 6.0 {
            p + (q - p) * 6.0 * t
        } else if t < 0.5 {
            q
        } else if t < 2.0 / 3.0 {
            p + (q - p) * (2.0 / 3.0 - t) * 6.0
        } else {
            p
        };
        (v * 255.0).round().clamp(0.0, 255.0) as u8
    };
    Color32::from_rgb(f(h + 1.0 / 3.0), f(h), f(h - 1.0 / 3.0))
}

pub fn hue_of(c: Color32) -> f32 {
    let (r, g, b) = (c.r() as f32 / 255.0, c.g() as f32 / 255.0, c.b() as f32 / 255.0);
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let d = max - min;
    if d < 1e-4 {
        return 0.0;
    }
    let h = if max == r {
        ((g - b) / d).rem_euclid(6.0)
    } else if max == g {
        (b - r) / d + 2.0
    } else {
        (r - g) / d + 4.0
    };
    h * 60.0
}

/// A stable color for a name, near the accent's hue so avatars belong to
/// the theme while still telling packages apart.
pub fn name_hue(pal: &Pal, name: &str) -> f32 {
    let mut h: u32 = 2166136261;
    for b in name.bytes() {
        h ^= b as u32;
        h = h.wrapping_mul(16777619);
    }
    hue_of(pal.accent) + ((h % 160) as f32 - 80.0)
}
