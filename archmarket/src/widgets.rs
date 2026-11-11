//! Drawing: line icons, buttons, chips, badges, avatars and gradients, all
//! painted by hand so the store has one consistent look.

use crate::theme::{Pal, alpha, hsl, mix};
use egui::epaint::{Mesh, PathShape, PathStroke, Vertex, WHITE_UV};
use egui::{
    Align2, Color32, CornerRadius, FontFamily, FontId, Id, Pos2, Rect, Response, Sense, Shape, Stroke, StrokeKind,
    TextureHandle, Ui, pos2, vec2,
};
use std::f32::consts::{PI, TAU};

pub fn body(size: f32) -> FontId {
    FontId::new(size, FontFamily::Proportional)
}
pub fn semi(size: f32) -> FontId {
    FontId::new(size, FontFamily::Name("semi".into()))
}
pub fn display(size: f32) -> FontId {
    FontId::new(size, FontFamily::Name("display".into()))
}
pub fn mono(size: f32) -> FontId {
    FontId::new(size, FontFamily::Monospace)
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Glyph {
    Search,
    Compass,
    Package,
    Refresh,
    Globe,
    Palette,
    Play,
    Code,
    Doc,
    Gamepad,
    Gear,
    Tiles,
    Flask,
    Check,
    Close,
    Back,
    Download,
    Trash,
    Open,
    Star,
    Terminal,
    Spark,
    Link,
    Alert,
}

fn lerp(r: Rect, x: f32, y: f32) -> Pos2 {
    pos2(r.left() + r.width() * x, r.top() + r.height() * y)
}

fn arc(c: Pos2, rad: f32, a0: f32, a1: f32, n: usize) -> Vec<Pos2> {
    (0..=n)
        .map(|i| {
            let a = a0 + (a1 - a0) * i as f32 / n as f32;
            pos2(c.x + rad * a.cos(), c.y + rad * a.sin())
        })
        .collect()
}

pub fn glyph(p: &egui::Painter, r: Rect, g: Glyph, color: Color32) {
    let w = (r.width() / 13.0).clamp(1.3, 2.6);
    let st = Stroke::new(w, color);
    let line = |pts: Vec<Pos2>| {
        p.add(Shape::Path(PathShape::line(pts, PathStroke::new(w, color))));
    };
    let closed = |pts: Vec<Pos2>| {
        p.add(Shape::Path(PathShape::closed_line(pts, PathStroke::new(w, color))));
    };
    let s = r.width();
    let c = r.center();
    match g {
        Glyph::Search => {
            p.circle_stroke(lerp(r, 0.44, 0.44), s * 0.27, st);
            p.line_segment([lerp(r, 0.64, 0.64), lerp(r, 0.86, 0.86)], st);
        }
        Glyph::Compass => {
            p.circle_stroke(c, s * 0.40, st);
            let n = vec![lerp(r, 0.62, 0.38), lerp(r, 0.55, 0.55), lerp(r, 0.38, 0.62), lerp(r, 0.45, 0.45)];
            p.add(Shape::convex_polygon(n, color, Stroke::NONE));
        }
        Glyph::Package => {
            closed(vec![lerp(r, 0.5, 0.1), lerp(r, 0.88, 0.3), lerp(r, 0.88, 0.72), lerp(r, 0.5, 0.92), lerp(r, 0.12, 0.72), lerp(r, 0.12, 0.3)]);
            line(vec![lerp(r, 0.12, 0.3), lerp(r, 0.5, 0.5), lerp(r, 0.88, 0.3)]);
            p.line_segment([lerp(r, 0.5, 0.5), lerp(r, 0.5, 0.92)], st);
        }
        Glyph::Refresh => {
            line(arc(c, s * 0.34, -PI * 0.35, PI * 1.45, 28));
            let tip = pos2(c.x + s * 0.34 * (-PI * 0.35f32).cos(), c.y + s * 0.34 * (-PI * 0.35f32).sin());
            line(vec![tip + vec2(-s * 0.2, -s * 0.02), tip, tip + vec2(-s * 0.04, s * 0.18)]);
        }
        Glyph::Globe => {
            p.circle_stroke(c, s * 0.40, st);
            closed(arc(c, 1.0, 0.0, TAU, 40).iter().map(|q| pos2(c.x + (q.x - c.x) * s * 0.17, c.y + (q.y - c.y) * s * 0.40)).collect());
            p.line_segment([lerp(r, 0.1, 0.5), lerp(r, 0.9, 0.5)], st);
        }
        Glyph::Palette => {
            p.circle_stroke(c, s * 0.40, st);
            for (x, y) in [(0.36, 0.36), (0.6, 0.32), (0.32, 0.6)] {
                p.circle_filled(lerp(r, x, y), s * 0.065, color);
            }
            p.circle_filled(lerp(r, 0.62, 0.63), s * 0.1, color);
        }
        Glyph::Play => {
            p.circle_stroke(c, s * 0.40, st);
            p.add(Shape::convex_polygon(vec![lerp(r, 0.42, 0.33), lerp(r, 0.68, 0.5), lerp(r, 0.42, 0.67)], color, Stroke::NONE));
        }
        Glyph::Code => {
            line(vec![lerp(r, 0.34, 0.26), lerp(r, 0.1, 0.5), lerp(r, 0.34, 0.74)]);
            line(vec![lerp(r, 0.66, 0.26), lerp(r, 0.9, 0.5), lerp(r, 0.66, 0.74)]);
            p.line_segment([lerp(r, 0.56, 0.18), lerp(r, 0.44, 0.82)], st);
        }
        Glyph::Doc => {
            closed(vec![lerp(r, 0.2, 0.1), lerp(r, 0.62, 0.1), lerp(r, 0.8, 0.28), lerp(r, 0.8, 0.9), lerp(r, 0.2, 0.9)]);
            for y in [0.45, 0.6, 0.75] {
                p.line_segment([lerp(r, 0.33, y), lerp(r, 0.67, y)], st);
            }
        }
        Glyph::Gamepad => {
            p.rect_stroke(Rect::from_min_max(lerp(r, 0.08, 0.28), lerp(r, 0.92, 0.76)), CornerRadius::same((s * 0.2) as u8), st, StrokeKind::Middle);
            p.line_segment([lerp(r, 0.22, 0.52), lerp(r, 0.40, 0.52)], st);
            p.line_segment([lerp(r, 0.31, 0.43), lerp(r, 0.31, 0.61)], st);
            p.circle_filled(lerp(r, 0.64, 0.47), s * 0.05, color);
            p.circle_filled(lerp(r, 0.75, 0.57), s * 0.05, color);
        }
        Glyph::Gear => {
            p.circle_stroke(c, s * 0.15, st);
            p.circle_stroke(c, s * 0.30, st);
            for i in 0..8 {
                let a = i as f32 * TAU / 8.0;
                let d = vec2(a.cos(), a.sin());
                p.line_segment([c + d * s * 0.30, c + d * s * 0.42], Stroke::new(w * 1.6, color));
            }
        }
        Glyph::Tiles => {
            for (x, y) in [(0.12, 0.12), (0.54, 0.12), (0.12, 0.54), (0.54, 0.54)] {
                p.rect_stroke(Rect::from_min_size(lerp(r, x, y), vec2(s * 0.34, s * 0.34)), CornerRadius::same((s * 0.09) as u8), st, StrokeKind::Middle);
            }
        }
        Glyph::Flask => {
            closed(vec![lerp(r, 0.38, 0.1), lerp(r, 0.62, 0.1), lerp(r, 0.62, 0.38), lerp(r, 0.88, 0.86), lerp(r, 0.12, 0.86), lerp(r, 0.38, 0.38)]);
            p.line_segment([lerp(r, 0.26, 0.62), lerp(r, 0.74, 0.62)], st);
        }
        Glyph::Check => line(vec![lerp(r, 0.18, 0.52), lerp(r, 0.42, 0.75), lerp(r, 0.84, 0.28)]),
        Glyph::Close => {
            p.line_segment([lerp(r, 0.24, 0.24), lerp(r, 0.76, 0.76)], st);
            p.line_segment([lerp(r, 0.76, 0.24), lerp(r, 0.24, 0.76)], st);
        }
        Glyph::Back => line(vec![lerp(r, 0.62, 0.18), lerp(r, 0.3, 0.5), lerp(r, 0.62, 0.82)]),
        Glyph::Download => {
            p.line_segment([lerp(r, 0.5, 0.12), lerp(r, 0.5, 0.64)], st);
            line(vec![lerp(r, 0.28, 0.44), lerp(r, 0.5, 0.66), lerp(r, 0.72, 0.44)]);
            line(vec![lerp(r, 0.14, 0.7), lerp(r, 0.14, 0.86), lerp(r, 0.86, 0.86), lerp(r, 0.86, 0.7)]);
        }
        Glyph::Trash => {
            p.line_segment([lerp(r, 0.14, 0.26), lerp(r, 0.86, 0.26)], st);
            line(vec![lerp(r, 0.38, 0.26), lerp(r, 0.38, 0.12), lerp(r, 0.62, 0.12), lerp(r, 0.62, 0.26)]);
            line(vec![lerp(r, 0.24, 0.26), lerp(r, 0.3, 0.88), lerp(r, 0.7, 0.88), lerp(r, 0.76, 0.26)]);
        }
        Glyph::Open | Glyph::Link => {
            p.line_segment([lerp(r, 0.42, 0.58), lerp(r, 0.84, 0.16)], st);
            line(vec![lerp(r, 0.54, 0.16), lerp(r, 0.84, 0.16), lerp(r, 0.84, 0.46)]);
            line(vec![lerp(r, 0.7, 0.62), lerp(r, 0.7, 0.86), lerp(r, 0.16, 0.86), lerp(r, 0.16, 0.32), lerp(r, 0.4, 0.32)]);
        }
        Glyph::Star | Glyph::Spark => {
            let (points, inner) = if g == Glyph::Star { (5, 0.42) } else { (4, 0.28) };
            let mut pts = Vec::new();
            for i in 0..points * 2 {
                let a = -PI / 2.0 + i as f32 * PI / points as f32;
                let rad = if i % 2 == 0 { s * 0.44 } else { s * 0.44 * inner };
                pts.push(pos2(c.x + rad * a.cos(), c.y + rad * a.sin()));
            }
            if g == Glyph::Spark {
                for i in 0..points * 2 {
                    p.add(Shape::convex_polygon(vec![c, pts[i], pts[(i + 1) % (points * 2)]], color, Stroke::NONE));
                }
            } else {
                closed(pts);
            }
        }
        Glyph::Terminal => {
            p.rect_stroke(Rect::from_min_max(lerp(r, 0.08, 0.16), lerp(r, 0.92, 0.84)), CornerRadius::same((s * 0.12) as u8), st, StrokeKind::Middle);
            line(vec![lerp(r, 0.26, 0.38), lerp(r, 0.4, 0.5), lerp(r, 0.26, 0.62)]);
            p.line_segment([lerp(r, 0.48, 0.64), lerp(r, 0.7, 0.64)], st);
        }
        Glyph::Alert => {
            closed(vec![lerp(r, 0.5, 0.1), lerp(r, 0.92, 0.86), lerp(r, 0.08, 0.86)]);
            p.line_segment([lerp(r, 0.5, 0.38), lerp(r, 0.5, 0.6)], st);
            p.circle_filled(lerp(r, 0.5, 0.73), w * 0.8, color);
        }
    }
}

/// Four-corner gradient.
pub fn gradient(p: &egui::Painter, r: Rect, tl: Color32, tr: Color32, bl: Color32, br: Color32) {
    let mut m = Mesh::default();
    let v = |pos, color| Vertex { pos, uv: WHITE_UV, color };
    m.vertices.extend([v(r.left_top(), tl), v(r.right_top(), tr), v(r.left_bottom(), bl), v(r.right_bottom(), br)]);
    m.indices.extend([0, 1, 2, 1, 3, 2]);
    p.add(Shape::mesh(m));
}

/// A soft round glow: a fan of triangles fading to nothing.
pub fn glow(p: &egui::Painter, c: Pos2, radius: f32, color: Color32) {
    let mut m = Mesh::default();
    m.vertices.push(Vertex { pos: c, uv: WHITE_UV, color });
    let n = 48;
    for i in 0..=n {
        let a = i as f32 * TAU / n as f32;
        m.vertices.push(Vertex { pos: c + vec2(a.cos(), a.sin()) * radius, uv: WHITE_UV, color: Color32::TRANSPARENT });
    }
    for i in 1..=n as u32 {
        m.indices.extend([0, i, i + 1]);
    }
    p.add(Shape::mesh(m));
}

pub fn shadow(p: &egui::Painter, r: Rect, radius: f32, strength: f32) {
    for i in 0..6 {
        let grow = 2.0 + i as f32 * 3.0;
        let a = strength * (0.10 - i as f32 * 0.015).max(0.0);
        p.rect_filled(r.expand(grow).translate(vec2(0.0, grow * 0.6)), CornerRadius::same((radius + grow) as u8), Color32::from_black_alpha((a * 255.0) as u8));
    }
}

#[derive(Clone, Copy, PartialEq)]
pub enum Btn {
    Primary,
    Soft,
    Danger,
    Ghost,
}

/// A rounded button with an optional icon, sized to its text.
pub fn button(ui: &mut Ui, pal: &Pal, id: Id, text: &str, icon: Option<Glyph>, kind: Btn, height: f32) -> Response {
    let font = semi(height * 0.4);
    let galley = ui.painter().layout_no_wrap(text.to_string(), font, Color32::WHITE);
    let icon_w = if icon.is_some() { height * 0.48 + 7.0 } else { 0.0 };
    let width = galley.size().x + icon_w + height * 0.9;
    let (rect, resp) = ui.allocate_exact_size(vec2(width, height), Sense::click());
    paint_button(ui, pal, id, rect, &resp, galley, icon, kind);
    resp
}

pub fn button_at(ui: &mut Ui, pal: &Pal, id: Id, rect: Rect, text: &str, icon: Option<Glyph>, kind: Btn) -> Response {
    let resp = ui.interact(rect, id, Sense::click());
    let galley = ui.painter().layout_no_wrap(text.to_string(), semi(rect.height() * 0.4), Color32::WHITE);
    paint_button(ui, pal, id, rect, &resp, galley, icon, kind);
    resp
}

pub fn button_width(ui: &Ui, text: &str, icon: bool, height: f32) -> f32 {
    let galley = ui.painter().layout_no_wrap(text.to_string(), semi(height * 0.4), Color32::WHITE);
    galley.size().x + if icon { height * 0.48 + 7.0 } else { 0.0 } + height * 0.9
}

fn paint_button(ui: &Ui, pal: &Pal, id: Id, rect: Rect, resp: &Response, galley: std::sync::Arc<egui::Galley>, icon: Option<Glyph>, kind: Btn) {
    let hover = ui.ctx().animate_bool_with_time(id.with("h"), resp.hovered(), 0.14);
    let press = ui.ctx().animate_bool_with_time(id.with("p"), resp.is_pointer_button_down_on(), 0.08);
    let (fill, fg, border) = match kind {
        Btn::Primary => (mix(pal.accent, Color32::WHITE, hover * 0.12), pal.accent_text, Color32::TRANSPARENT),
        Btn::Soft => (alpha(pal.accent, 0.16 + hover * 0.10), pal.accent, Color32::TRANSPARENT),
        Btn::Danger => (alpha(pal.error, 0.10 + hover * 0.14), pal.error, alpha(pal.error, 0.35)),
        Btn::Ghost => (alpha(pal.text, 0.06 + hover * 0.06), pal.text, alpha(pal.text, 0.08)),
    };
    let r = rect.shrink(press * 1.2);
    let p = ui.painter();
    if kind == Btn::Primary {
        shadow(p, r, r.height() / 2.0, 0.5 + hover * 0.5);
    }
    let cr = CornerRadius::same((r.height() / 2.0) as u8);
    p.rect_filled(r, cr, fill);
    if border != Color32::TRANSPARENT {
        p.rect_stroke(r, cr, Stroke::new(1.0, border), StrokeKind::Inside);
    }
    let icon_w = if icon.is_some() { r.height() * 0.48 + 7.0 } else { 0.0 };
    let total = galley.size().x + icon_w;
    let mut x = r.center().x - total / 2.0;
    if let Some(g) = icon {
        let s = r.height() * 0.48;
        glyph(p, Rect::from_center_size(pos2(x + s / 2.0, r.center().y), vec2(s, s)), g, fg);
        x += icon_w;
    }
    p.galley(pos2(x, r.center().y - galley.size().y / 2.0), galley, fg);
    if resp.hovered() {
        ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand);
    }
}

/// A selectable chip with a sliding fill.
pub fn chip(ui: &mut Ui, pal: &Pal, id: Id, text: &str, selected: bool) -> Response {
    let galley = ui.painter().layout_no_wrap(text.to_string(), semi(13.0), Color32::WHITE);
    let size = vec2(galley.size().x + 26.0, 32.0);
    let (rect, resp) = ui.allocate_exact_size(size, Sense::click());
    let on = ui.ctx().animate_bool_with_time(id, selected, 0.18);
    let hover = ui.ctx().animate_bool_with_time(id.with("h"), resp.hovered(), 0.12);
    let p = ui.painter();
    p.rect_filled(rect, CornerRadius::same(16), alpha(pal.text, 0.05 + hover * 0.05));
    if on > 0.0 {
        let fill = Rect::from_center_size(rect.center(), rect.size() * vec2(0.6 + 0.4 * on, 1.0));
        p.rect_filled(fill, CornerRadius::same(16), alpha(pal.accent, on));
    }
    let fg = mix(pal.text, pal.accent_text, on);
    p.galley(rect.center() - galley.size() / 2.0, galley, fg);
    if resp.hovered() {
        ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand);
    }
    resp
}

/// Small label of a repository: "extra", "AUR".
pub fn badge(p: &egui::Painter, pal: &Pal, at: Pos2, repo: &str, anchor: Align2) -> Rect {
    let text = repo_label(repo);
    let color = pal.source(repo);
    let galley = p.layout_no_wrap(text, semi(11.0), color);
    let size = vec2(galley.size().x + 14.0, 20.0);
    let rect = anchor.anchor_size(at, size);
    p.rect_filled(rect, CornerRadius::same(10), alpha(color, 0.15));
    p.galley(rect.center() - galley.size() / 2.0, galley, color);
    rect
}

/// The app's icon, or a colored tile with its first letter.
pub fn avatar(ui: &Ui, pal: &Pal, rect: Rect, tex: Option<&TextureHandle>, name: &str) {
    let p = ui.painter();
    let radius = (rect.width() * 0.26) as u8;
    if let Some(t) = tex {
        egui::Image::new(t).corner_radius(CornerRadius::same(radius.min(8))).paint_at(ui, rect);
        return;
    }
    let h = crate::theme::name_hue(pal, name);
    let (l1, l2) = if pal.dark { (0.62, 0.42) } else { (0.66, 0.48) };
    let c1 = hsl(h, 0.55, l1);
    let c2 = hsl(h + 35.0, 0.6, l2);
    let inner = rect.shrink(rect.width() * 0.06);
    p.rect_filled(inner, CornerRadius::same(radius), c2);
    // a diagonal sheen across the tile
    let half = Rect::from_min_max(inner.min, pos2(inner.max.x, inner.center().y));
    p.rect_filled(half, CornerRadius { nw: radius, ne: radius, sw: 0, se: 0 }, alpha(c1, 0.55));
    let letter: String = name
        .trim_start_matches(|c: char| !c.is_alphanumeric())
        .chars()
        .next()
        .map(|c| c.to_uppercase().collect())
        .unwrap_or_else(|| "?".into());
    p.text(inner.center() + vec2(0.0, rect.height() * 0.02), Align2::CENTER_CENTER, letter, display(rect.height() * 0.42), Color32::from_white_alpha(240));
}

/// Indeterminate progress: a moving highlight across a track.
pub fn progress(p: &egui::Painter, pal: &Pal, r: Rect, value: Option<f32>, time: f64) {
    let cr = CornerRadius::same((r.height() / 2.0) as u8);
    p.rect_filled(r, cr, alpha(pal.accent, 0.16));
    match value {
        Some(v) => {
            let fill = Rect::from_min_size(r.min, vec2((r.width() * v.clamp(0.02, 1.0)).max(r.height()), r.height()));
            p.rect_filled(fill, cr, pal.accent);
        }
        None => {
            let t = (time * 0.7).fract() as f32;
            let w = r.width() * 0.32;
            let x = r.left() - w + (r.width() + w) * t;
            let seg = Rect::from_min_max(pos2(x.max(r.left()), r.top()), pos2((x + w).min(r.right()), r.bottom()));
            if seg.width() > 0.0 {
                p.rect_filled(seg, cr, pal.accent);
            }
        }
    }
}

pub fn spinner(p: &egui::Painter, c: Pos2, radius: f32, color: Color32, time: f64) {
    let a0 = (time * 5.0) as f32;
    let sweep = 1.6 + ((time * 2.2).sin() as f32 + 1.0) * 0.9;
    p.add(Shape::line(arc(c, radius, a0, a0 + sweep, 24), Stroke::new(2.2, color)));
}

pub fn ease_out(t: f32) -> f32 {
    let t = t.clamp(0.0, 1.0);
    1.0 - (1.0 - t).powi(3)
}

pub fn elide(ui: &Ui, text: &str, font: FontId, width: f32) -> String {
    let fits = |s: &str| ui.painter().layout_no_wrap(s.to_string(), font.clone(), Color32::WHITE).size().x <= width;
    if fits(text) {
        return text.to_string();
    }
    let chars: Vec<char> = text.chars().collect();
    let (mut lo, mut hi) = (0usize, chars.len());
    while lo < hi {
        let mid = (lo + hi).div_ceil(2);
        let s: String = chars[..mid].iter().collect::<String>() + "…";
        if fits(&s) { lo = mid } else { hi = mid - 1 }
    }
    chars[..lo].iter().collect::<String>().trim_end().to_string() + "…"
}

pub fn wrap_galley(ui: &Ui, text: &str, font: FontId, color: Color32, width: f32, max_rows: usize) -> std::sync::Arc<egui::Galley> {
    let mut job = egui::text::LayoutJob::simple(text.to_string(), font, color, width);
    job.wrap.max_rows = max_rows;
    job.wrap.break_anywhere = false;
    job.wrap.overflow_character = Some('…');
    ui.painter().layout_job(job)
}

/// A rounded rectangle filled with a four-corner gradient.
pub fn rounded_gradient(p: &egui::Painter, r: Rect, radius: f32, tl: Color32, tr: Color32, bl: Color32, br: Color32) {
    let rad = radius.min(r.width() / 2.0).min(r.height() / 2.0);
    let mut pts = Vec::new();
    let corners = [
        (pos2(r.right() - rad, r.top() + rad), -PI / 2.0),
        (pos2(r.right() - rad, r.bottom() - rad), 0.0),
        (pos2(r.left() + rad, r.bottom() - rad), PI / 2.0),
        (pos2(r.left() + rad, r.top() + rad), PI),
    ];
    for (c, a0) in corners {
        pts.extend(arc(c, rad, a0, a0 + PI / 2.0, 10));
    }
    let color_at = |q: Pos2| {
        let u = ((q.x - r.left()) / r.width()).clamp(0.0, 1.0);
        let v = ((q.y - r.top()) / r.height()).clamp(0.0, 1.0);
        mix(mix(tl, tr, u), mix(bl, br, u), v)
    };
    let mut m = Mesh::default();
    let c = r.center();
    m.vertices.push(Vertex { pos: c, uv: WHITE_UV, color: color_at(c) });
    for q in &pts {
        m.vertices.push(Vertex { pos: *q, uv: WHITE_UV, color: color_at(*q) });
    }
    let n = pts.len() as u32;
    for i in 0..n {
        m.indices.extend([0, 1 + i, 1 + (i + 1) % n]);
    }
    p.add(Shape::mesh(m));
}

/// Short name of a repository for badges.
pub fn repo_label(repo: &str) -> String {
    match repo {
        "aur" => "AUR".into(),
        "core" => "Core".into(),
        "extra" => "Extra".into(),
        "multilib" => "Multilib".into(),
        "local" => "Local".into(),
        r if r.starts_with("cachyos") => "CachyOS".into(),
        r => r.to_string(),
    }
}
