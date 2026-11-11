//! Fonts: Geist for text, Unbounded for headings, Geist Mono for logs, the
//! same faces the Falcon desktop uses. Found through fontconfig; egui's
//! built-in fonts stay as the fallback for anything missing.

use egui::epaint::text::{FontInsert, VariationCoords};
use egui::{FontData, FontDefinitions, FontFamily, FontTweak};
use std::process::Command;
use std::sync::Arc;

fn find(family: &str) -> Option<Vec<u8>> {
    let out = Command::new("fc-match").args(["-f", "%{file}", family]).output().ok()?;
    let path = String::from_utf8_lossy(&out.stdout).to_string();
    let file = path.rsplit('/').next().unwrap_or("").to_lowercase();
    let want = family.to_lowercase().replace(' ', "");
    if !file.replace([' ', '-', '_'], "").contains(&want) {
        return None;
    }
    std::fs::read(path).ok()
}

fn weighted(bytes: &Arc<Vec<u8>>, wght: f32) -> FontData {
    let blob: egui::epaint::text::Blob = bytes.clone();
    FontData::from_blob(blob, 0).tweak(FontTweak { coords: VariationCoords::new([("wght", wght)]), ..Default::default() })
}

pub fn install(ctx: &egui::Context) {
    let _ = FontInsert::new;
    let mut defs = FontDefinitions::default();
    let base_prop = defs.families.get(&FontFamily::Proportional).cloned().unwrap_or_default();
    let base_mono = defs.families.get(&FontFamily::Monospace).cloned().unwrap_or_default();
    let mut prop = base_prop.clone();
    let mut semi = base_prop.clone();
    let mut display = base_prop.clone();
    let mut mono = base_mono.clone();

    if let Some(b) = find("Geist") {
        let b = Arc::new(b);
        defs.font_data.insert("geist".into(), Arc::new(weighted(&b, 420.0)));
        defs.font_data.insert("geist-semi".into(), Arc::new(weighted(&b, 600.0)));
        prop.insert(0, "geist".into());
        semi.insert(0, "geist-semi".into());
        display.insert(0, "geist-semi".into());
    }
    if let Some(b) = find("Unbounded") {
        let b = Arc::new(b);
        defs.font_data.insert("unbounded".into(), Arc::new(weighted(&b, 600.0)));
        display.insert(0, "unbounded".into());
    }
    if let Some(b) = find("Geist Mono") {
        let b = Arc::new(b);
        defs.font_data.insert("geist-mono".into(), Arc::new(weighted(&b, 420.0)));
        mono.insert(0, "geist-mono".into());
    }
    defs.families.insert(FontFamily::Proportional, prop);
    defs.families.insert(FontFamily::Monospace, mono);
    defs.families.insert(FontFamily::Name("semi".into()), semi);
    defs.families.insert(FontFamily::Name("display".into()), display);
    ctx.set_fonts(defs);
}
