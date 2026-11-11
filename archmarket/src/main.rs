#![allow(deprecated)]
//! archmarket: a graphical package store for Arch Linux.
//!
//! Official repositories through pacman, the AUR through yay. The window is
//! drawn with egui, entirely in Rust.

mod app;
mod appstream;
mod aur;
mod catalog;
mod fonts;
mod i18n;
mod icons;
mod jobs;
mod theme;
mod widgets;

use std::process::Command;

/// One window only: a second start focuses the open one, or closes it when
/// it already has the focus, so the same key opens and hides the store.
fn toggle_existing() -> bool {
    if std::env::var_os("NIRI_SOCKET").is_none() {
        return false;
    }
    let Ok(out) = Command::new("niri").args(["msg", "-j", "windows"]).output() else { return false };
    let Ok(v) = serde_json::from_slice::<serde_json::Value>(&out.stdout) else { return false };
    for w in v.as_array().into_iter().flatten() {
        if w["app_id"].as_str() == Some("archmarket") {
            let id = w["id"].as_u64().unwrap_or(0).to_string();
            let action = if w["is_focused"].as_bool() == Some(true) { "close-window" } else { "focus-window" };
            let _ = Command::new("niri").args(["msg", "action", action, "--id", &id]).status();
            return true;
        }
    }
    false
}

fn main() -> eframe::Result<()> {
    if std::env::args().any(|a| a == "--version") {
        println!("archmarket {}", env!("CARGO_PKG_VERSION"));
        return Ok(());
    }
    if toggle_existing() {
        return Ok(());
    }
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_app_id("archmarket")
            .with_title("Archmarket")
            .with_inner_size([1240.0, 790.0])
            .with_min_inner_size([900.0, 580.0])
            .with_transparent(true)
            .with_decorations(false),
        ..Default::default()
    };
    eframe::run_native("archmarket", options, Box::new(|cc| Ok(Box::new(app::Market::new(cc)))))
}
