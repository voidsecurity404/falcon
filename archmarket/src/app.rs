//! The store window.

use crate::appstream::{self, AppMeta};
use crate::catalog::{self, Catalog, Details, Local, Pkg, Update, human_size};
use crate::i18n::{t, tf};
use crate::icons::{Icons, Src};
use crate::jobs::{Job, Jobs, Kind, State};
use crate::theme::{Pal, alpha, hsl, hue_of, mix};
use crate::widgets::*;
use egui::{
    Align2, Color32, CornerRadius, Event, Id, Key, Rect, Sense, Stroke, StrokeKind, TextureHandle, Ui, UiBuilder,
    ViewportCommand, pos2, vec2,
};
use std::collections::{HashMap, HashSet};
use std::sync::mpsc::{Receiver, Sender, channel};
use std::time::{Duration, Instant};

struct Cat {
    title: &'static str,
    keys: &'static [&'static str],
    glyph: Glyph,
}

const CATS: [Cat; 9] = [
    Cat { title: "Internet", keys: &["Network"], glyph: Glyph::Globe },
    Cat { title: "Graphics", keys: &["Graphics"], glyph: Glyph::Palette },
    Cat { title: "Audio and video", keys: &["AudioVideo", "Audio", "Video"], glyph: Glyph::Play },
    Cat { title: "Development", keys: &["Development"], glyph: Glyph::Code },
    Cat { title: "Office", keys: &["Office"], glyph: Glyph::Doc },
    Cat { title: "Games", keys: &["Game"], glyph: Glyph::Gamepad },
    Cat { title: "System", keys: &["System", "Settings"], glyph: Glyph::Gear },
    Cat { title: "Utilities", keys: &["Utility"], glyph: Glyph::Tiles },
    Cat { title: "Science and education", keys: &["Science", "Education"], glyph: Glyph::Flask },
];

const HERO: &[&str] = &["obs-studio", "blender", "krita", "telegram-desktop", "gimp", "steam", "kdenlive", "inkscape", "firefox"];

const SHELVES: &[(&str, &[&str])] = &[
    ("Everyday essentials", &["firefox", "chromium", "telegram-desktop", "thunderbird", "libreoffice-fresh", "vlc", "qbittorrent", "keepassxc", "signal-desktop", "discord", "obsidian", "transmission-gtk"]),
    ("Create", &["gimp", "krita", "inkscape", "blender", "kdenlive", "obs-studio", "darktable", "audacity", "shotcut", "ardour", "pinta", "rawtherapee"]),
    ("For developers", &["code", "zed", "kate", "neovim", "gnome-builder", "meld", "dbeaver", "gitg", "godot", "qtcreator", "kdevelop", "ghex"]),
    ("Play", &["steam", "lutris", "retroarch", "supertuxkart", "0ad", "luanti", "dolphin-emu", "wesnoth", "xonotic", "pcsx2", "supertux", "mangohud"]),
];

const AUR_PICKS: &[&str] = &[
    "google-chrome", "visual-studio-code-bin", "spotify", "brave-bin", "zoom", "anydesk-bin", "onlyoffice-bin",
    "yandex-browser", "teams-for-linux", "postman-bin", "heroic-games-launcher-bin", "ttf-ms-fonts",
];

/// Packages the store refuses to remove: losing them breaks the system.
const PROTECTED: &[&str] = &[
    "base", "linux", "linux-cachyos", "linux-lts", "linux-zen", "linux-firmware", "systemd", "pacman", "glibc",
    "filesystem", "sudo", "polkit", "niri", "quickshell", "sddm", "kitty", "mesa", "bash", "coreutils",
    "limine", "grub", "networkmanager", "pipewire", "wireplumber", "archmarket",
];

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Page {
    Discover,
    Category(usize),
    Installed,
    Updates,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Scope {
    All,
    Repo,
    Aur,
}

enum Msg {
    Status(&'static str),
    Repo(Vec<Pkg>, HashMap<String, usize>),
    Apps(HashMap<String, AppMeta>),
    Local(HashMap<String, Local>),
    Aur { query: String, result: Result<Vec<Pkg>, String> },
    Picks(Vec<Pkg>),
    Details { name: String, result: Result<(Option<Pkg>, Details), String> },
    Updates(Result<Vec<Update>, String>),
    Desktop { name: String, id: Option<String> },
}

enum Detail {
    Loading,
    Ready(Details),
    Failed(String),
}

enum Act {
    Show(String),
    Install(String),
    Remove(String),
    Launch(String),
    Go(Page),
    UpgradeAll,
    CheckUpdates,
    Url(String),
    Close,
    Hero(usize),
}

#[derive(Clone)]
struct Item {
    name: String,
    title: String,
    summary: String,
    version: String,
    repo: String,
    installed: bool,
    size: u64,
}

struct Sheet {
    name: String,
    opened: Instant,
    closing: Option<Instant>,
}

pub struct Market {
    pal: Pal,
    tx: Sender<Msg>,
    rx: Receiver<Msg>,
    cat: Catalog,
    repo_ready: bool,
    apps_ready: bool,
    status: &'static str,
    local: HashMap<String, Local>,
    aur: HashMap<String, Pkg>,
    picks: Vec<String>,
    page: Page,
    page_since: Instant,
    query: String,
    typed_at: Option<Instant>,
    hits: Vec<String>,
    hits_for: String,
    aur_query: String,
    aur_sent: String,
    aur_loading: bool,
    aur_hits: Vec<String>,
    aur_error: Option<String>,
    scope: Scope,
    sheet: Option<Sheet>,
    details: HashMap<String, Detail>,
    desktop: HashMap<String, Option<String>>,
    updates: Option<Result<Vec<Update>, String>>,
    updates_loading: bool,
    installed_filter: usize,
    cat_lists: HashMap<usize, Vec<String>>,
    jobs: Jobs,
    job_list: Vec<Job>,
    finished: u64,
    log_open: bool,
    icons: Icons,
    confirm: Option<(String, Instant)>,
    toast: Option<(String, Instant, bool)>,
    acts: Vec<Act>,
    focus_search: bool,
    close_when_idle: bool,
    hero: usize,
    hero_since: Instant,
    have_yay: bool,
    pending_show: Option<String>,
    pending_install: Option<String>,
}

fn spawn(tx: &Sender<Msg>, ctx: &egui::Context, f: impl FnOnce() -> Msg + Send + 'static) {
    let tx = tx.clone();
    let ctx = ctx.clone();
    std::thread::spawn(move || {
        let _ = tx.send(f());
        ctx.request_repaint();
    });
}

impl Market {
    pub fn new(cc: &eframe::CreationContext<'_>) -> Market {
        let ctx = &cc.egui_ctx;
        let pal = Pal::load();
        crate::fonts::install(ctx);
        style(ctx, &pal);
        let (tx, rx) = channel();
        // Fast first: the package lists, then the app catalog.
        spawn(&tx, ctx, || {
            let (list, index) = catalog::load_repo();
            Msg::Repo(list, index)
        });
        spawn(&tx, ctx, || Msg::Local(catalog::load_local()));
        {
            let tx2 = tx.clone();
            let ctx2 = ctx.clone();
            spawn(&tx, ctx, move || {
                let say = |s: &str| {
                    let s: &'static str = if s.starts_with("Downloading") { "Downloading app catalog" } else { "Loading" };
                    let _ = tx2.send(Msg::Status(s));
                    ctx2.request_repaint();
                };
                match appstream::locate(&say) {
                    Some(root) => Msg::Apps(appstream::load(&root, crate::i18n::ru())),
                    None => Msg::Apps(HashMap::new()),
                }
            });
        }
        spawn(&tx, ctx, || Msg::Picks(crate::aur::info_many(AUR_PICKS).unwrap_or_default()));
        let now = Instant::now();
        let mut m = Market {
            pal,
            tx,
            rx,
            cat: Catalog::default(),
            repo_ready: false,
            apps_ready: false,
            status: "Reading package databases",
            local: HashMap::new(),
            aur: HashMap::new(),
            picks: Vec::new(),
            page: Page::Discover,
            page_since: now,
            query: String::new(),
            typed_at: None,
            hits: Vec::new(),
            hits_for: String::new(),
            aur_query: String::new(),
            aur_sent: String::new(),
            aur_loading: false,
            aur_hits: Vec::new(),
            aur_error: None,
            scope: Scope::All,
            sheet: None,
            details: HashMap::new(),
            desktop: HashMap::new(),
            updates: None,
            updates_loading: false,
            installed_filter: 0,
            cat_lists: HashMap::new(),
            jobs: Jobs::new(ctx.clone()),
            job_list: Vec::new(),
            finished: 0,
            log_open: false,
            icons: Icons::new(ctx),
            confirm: None,
            toast: None,
            acts: Vec::new(),
            focus_search: true,
            close_when_idle: false,
            hero: 0,
            hero_since: now,
            have_yay: catalog::have("yay"),
            pending_show: None,
            pending_install: None,
        };
        m.check_updates(ctx);
        // Start somewhere else: `--search TEXT`, `--page installed|updates|N`, `--show PACKAGE`.
        let args: Vec<String> = std::env::args().collect();
        for w in args.windows(2) {
            match w[0].as_str() {
                "--search" => m.query = w[1].clone(),
                "--page" => {
                    m.page = match w[1].as_str() {
                        "installed" => Page::Installed,
                        "updates" => Page::Updates,
                        n => n.parse::<usize>().ok().filter(|&i| i < CATS.len()).map(Page::Category).unwrap_or(Page::Discover),
                    }
                }
                "--show" => m.pending_show = Some(w[1].clone()),
                "--install" => m.pending_install = Some(w[1].clone()),
                _ => {}
            }
        }
        m
    }

    fn check_updates(&mut self, ctx: &egui::Context) {
        if self.updates_loading {
            return;
        }
        self.updates_loading = true;
        spawn(&self.tx, ctx, || Msg::Updates(catalog::load_updates()));
    }

    fn poll(&mut self, ctx: &egui::Context) {
        while let Ok(msg) = self.rx.try_recv() {
            match msg {
                Msg::Status(s) => self.status = s,
                Msg::Repo(list, index) => {
                    self.cat.repo = list;
                    self.cat.index = index;
                    self.repo_ready = true;
                    self.hits_for.clear();
                    self.status = "Loading app catalog";
                }
                Msg::Apps(apps) => {
                    self.cat.apps = apps;
                    self.apps_ready = true;
                    self.cat_lists.clear();
                    self.hits_for.clear();
                }
                Msg::Local(l) => self.local = l,
                Msg::Aur { query, result } => {
                    if query == self.aur_sent {
                        self.aur_loading = false;
                        self.aur_query = query;
                        match result {
                            Ok(list) => {
                                self.aur_error = None;
                                self.aur_hits = list
                                    .iter()
                                    .filter(|p| !self.cat.index.contains_key(&p.name))
                                    .map(|p| p.name.clone())
                                    .collect();
                                for p in list {
                                    self.aur.insert(p.name.clone(), p);
                                }
                            }
                            Err(e) => {
                                self.aur_error = Some(e);
                                self.aur_hits.clear();
                            }
                        }
                    }
                }
                Msg::Picks(list) => {
                    self.picks = list.iter().map(|p| p.name.clone()).collect();
                    for p in list {
                        self.aur.insert(p.name.clone(), p);
                    }
                }
                Msg::Details { name, result } => {
                    let d = match result {
                        Ok((pkg, d)) => {
                            if let Some(p) = pkg {
                                self.aur.insert(p.name.clone(), p);
                            }
                            Detail::Ready(d)
                        }
                        Err(e) => Detail::Failed(e),
                    };
                    self.details.insert(name, d);
                }
                Msg::Updates(r) => {
                    self.updates_loading = false;
                    self.updates = Some(r);
                }
                Msg::Desktop { name, id } => {
                    self.desktop.insert(name, id);
                }
            }
        }
        let (list, finished) = self.jobs.snapshot();
        if finished != self.finished {
            self.finished = finished;
            // Something was installed or removed: read the system again.
            spawn(&self.tx, ctx, || Msg::Local(catalog::load_local()));
            let touched: HashSet<String> = list
                .iter()
                .filter(|j| !j.active() && j.ended.map(|e| e.elapsed() < Duration::from_secs(5)).unwrap_or(false))
                .flat_map(|j| j.pkgs.clone())
                .collect();
            for n in &touched {
                self.desktop.remove(n);
                self.icons.forget(&format!("pkg:{n}"));
                self.details.remove(n);
            }
            if list.iter().any(|j| j.kind == Kind::Upgrade && !j.active()) || !touched.is_empty() {
                self.updates_loading = false;
                self.check_updates(ctx);
            }
        }
        self.job_list = list;
        if self.close_when_idle && !self.job_list.iter().any(|j| j.active()) {
            ctx.send_viewport_cmd(ViewportCommand::Close);
        }
    }

    // ---------------------------------------------------------------- search

    fn search(&mut self) {
        let q = self.query.trim().to_lowercase();
        if q == self.hits_for || !self.repo_ready {
            return;
        }
        self.hits_for = q.clone();
        self.hits.clear();
        if q.is_empty() {
            return;
        }
        let words: Vec<&str> = q.split_whitespace().collect();
        let mut scored: Vec<(i32, usize)> = Vec::new();
        for (i, p) in self.cat.repo.iter().enumerate() {
            let app = self.cat.apps.get(&p.name);
            let mut s = 0i32;
            if p.lname == q {
                s = 1000;
            } else if p.lname.starts_with(&q) {
                s = 760 - (p.lname.len() as i32 - q.len() as i32).min(200);
            } else if let Some(pos) = p.lname.find(&q) {
                s = 520 - pos as i32 * 4 - (p.lname.len() as i32 / 3);
            }
            if let Some(a) = app {
                if a.lname == q {
                    s = s.max(980);
                } else if a.lname.starts_with(&q) {
                    s = s.max(800);
                } else if a.lname.contains(&q) {
                    s = s.max(560);
                } else if s == 0 && a.keywords.iter().any(|k| k.starts_with(&q)) {
                    s = 330;
                }
            }
            if s == 0 && words.iter().all(|w| p.ldesc.contains(w) || p.lname.contains(w)) {
                s = 160;
            }
            if s == 0 {
                if let Some(a) = app {
                    let sum = a.summary.to_lowercase();
                    if words.iter().all(|w| sum.contains(w)) {
                        s = 170;
                    }
                }
            }
            if s > 0 {
                if app.is_some() {
                    s += 140;
                }
                if s < 1000 && app.is_none() && !crate::icons::app_like(&p.name) {
                    s -= 150;
                }
                scored.push((s, i));
            }
        }
        scored.sort_by(|a, b| b.0.cmp(&a.0).then_with(|| self.cat.repo[a.1].name.cmp(&self.cat.repo[b.1].name)));
        self.hits = scored.iter().take(160).map(|&(_, i)| self.cat.repo[i].name.clone()).collect();
    }

    fn search_aur(&mut self, ctx: &egui::Context) {
        let q = self.query.trim().to_string();
        let Some(at) = self.typed_at else { return };
        if at.elapsed() < Duration::from_millis(380) {
            ctx.request_repaint_after(Duration::from_millis(400) - at.elapsed().min(Duration::from_millis(400)));
            return;
        }
        if q == self.aur_sent {
            return;
        }
        self.aur_sent = q.clone();
        if q.chars().count() < 2 {
            self.aur_hits.clear();
            self.aur_query = q;
            self.aur_loading = false;
            return;
        }
        self.aur_loading = true;
        spawn(&self.tx, ctx, move || {
            let result = crate::aur::search(&q);
            Msg::Aur { query: q, result }
        });
    }

    // ---------------------------------------------------------------- data

    fn item(&self, name: &str) -> Option<Item> {
        let local = self.local.get(name);
        if let Some(p) = self.cat.get(name) {
            let app = self.cat.app(name);
            return Some(Item {
                name: p.name.clone(),
                title: app.map(|a| a.name.clone()).unwrap_or_else(|| p.name.clone()),
                summary: app.map(|a| a.summary.clone()).filter(|s| !s.is_empty()).unwrap_or_else(|| p.desc.clone()),
                version: p.version.clone(),
                repo: p.repo.clone(),
                installed: local.is_some(),
                size: p.size,
            });
        }
        if let Some(p) = self.aur.get(name) {
            return Some(Item {
                name: p.name.clone(),
                title: p.name.clone(),
                summary: p.desc.clone(),
                version: p.version.clone(),
                repo: "aur".into(),
                installed: local.is_some(),
                size: local.map(|l| l.size).unwrap_or(0),
            });
        }
        local.map(|l| Item {
            name: name.to_string(),
            title: name.to_string(),
            summary: l.desc.clone(),
            version: l.version.clone(),
            repo: if l.foreign { "aur".into() } else { "local".into() },
            installed: true,
            size: l.size,
        })
    }

    fn icon(&mut self, name: &str) -> Option<TextureHandle> {
        // Until the catalog and the local list are in, an unknown icon would
        // be remembered as missing for good.
        if !self.apps_ready || self.local.is_empty() {
            return None;
        }
        let key = format!("pkg:{name}");
        let file = self.cat.apps.get(name).and_then(|a| a.icon.clone());
        let installed = self.local.contains_key(name);
        self.icons.get(&key, || match file {
            Some(f) => Some(Src::File(f)),
            None if installed => Some(Src::Installed(name.to_string())),
            None if crate::icons::app_like(name) => Some(Src::Web(name.to_string())),
            None => None,
        })
    }

    fn cat_list(&mut self, i: usize) -> &Vec<String> {
        if !self.cat_lists.contains_key(&i) {
            let keys = CATS[i].keys;
            let mut list: Vec<(&str, &str)> = self
                .cat
                .apps
                .iter()
                .filter(|(pkg, a)| self.cat.index.contains_key(*pkg) && a.categories.iter().any(|c| keys.contains(&c.as_str())))
                .map(|(pkg, a)| (pkg.as_str(), a.lname.as_str()))
                .collect();
            list.sort_by(|a, b| a.1.cmp(b.1));
            let names = list.into_iter().map(|(p, _)| p.to_string()).collect();
            self.cat_lists.insert(i, names);
        }
        &self.cat_lists[&i]
    }

    fn job_for(&self, name: &str) -> Option<Job> {
        Jobs::for_pkg(&self.job_list, name)
    }

    // ---------------------------------------------------------------- actions

    fn apply(&mut self, ctx: &egui::Context) {
        for act in std::mem::take(&mut self.acts) {
            match act {
                Act::Show(name) => self.open_sheet(ctx, &name),
                Act::Install(name) => {
                    let aur = !self.cat.index.contains_key(&name);
                    self.jobs.add(Kind::Install, vec![name], aur);
                    self.jobs.mark_seen();
                }
                Act::Remove(name) => {
                    match &self.confirm {
                        Some((n, at)) if *n == name && at.elapsed() < Duration::from_secs(4) => {
                            self.confirm = None;
                            self.jobs.add(Kind::Remove, vec![name], false);
                        }
                        _ => self.confirm = Some((name, Instant::now())),
                    }
                }
                Act::Launch(name) => {
                    if let Some(Some(id)) = self.desktop.get(&name) {
                        let _ = std::process::Command::new("gtk-launch")
                            .arg(id.trim_end_matches(".desktop"))
                            .stdin(std::process::Stdio::null())
                            .stdout(std::process::Stdio::null())
                            .stderr(std::process::Stdio::null())
                            .spawn();
                    }
                }
                Act::Go(p) => {
                    if self.page != p || !self.query.is_empty() {
                        self.page = p;
                        self.page_since = Instant::now();
                        self.query.clear();
                        self.hits_for.clear();
                        self.typed_at = None;
                    }
                    if p == Page::Updates && self.updates.is_none() {
                        self.check_updates(ctx);
                    }
                }
                Act::UpgradeAll => {
                    let aur = matches!(&self.updates, Some(Ok(l)) if l.iter().any(|u| u.aur));
                    self.jobs.add(Kind::Upgrade, Vec::new(), aur);
                }
                Act::CheckUpdates => {
                    self.updates_loading = false;
                    self.check_updates(ctx);
                }
                Act::Url(u) => ctx.open_url(egui::OpenUrl::new_tab(u)),
                Act::Close => {
                    if let Some(s) = self.sheet.as_mut() {
                        if s.closing.is_none() {
                            s.closing = Some(Instant::now());
                        }
                    }
                }
                Act::Hero(i) => {
                    self.hero = i;
                    self.hero_since = Instant::now();
                }
            }
        }
    }

    fn open_sheet(&mut self, ctx: &egui::Context, name: &str) {
        self.sheet = Some(Sheet { name: name.to_string(), opened: Instant::now(), closing: None });
        if !self.details.contains_key(name) {
            self.details.insert(name.to_string(), Detail::Loading);
            let n = name.to_string();
            let in_repo = self.cat.index.contains_key(name);
            let foreign = self.local.get(name).map(|l| l.foreign).unwrap_or(false);
            spawn(&self.tx, ctx, move || {
                let result = if in_repo {
                    catalog::repo_details(&n, false).map(|d| (None, d))
                } else {
                    match crate::aur::details(&n) {
                        Ok((p, d)) => Ok((Some(p), d)),
                        Err(e) if foreign || e.contains("not in") => catalog::repo_details(&n, true).map(|d| (None, d)),
                        Err(e) => Err(e),
                    }
                };
                Msg::Details { name: n, result }
            });
        }
        if self.local.contains_key(name) && !self.desktop.contains_key(name) {
            let n = name.to_string();
            spawn(&self.tx, ctx, move || {
                let id = catalog::desktop_entry(&n).map(|d| d.0);
                Msg::Desktop { name: n, id }
            });
        }
    }

    fn ensure_desktop(&mut self, ctx: &egui::Context, name: &str) {
        if self.local.contains_key(name) && !self.desktop.contains_key(name) {
            self.desktop.insert(name.to_string(), None);
            let n = name.to_string();
            spawn(&self.tx, ctx, move || {
                let id = catalog::desktop_entry(&n).map(|d| d.0);
                Msg::Desktop { name: n, id }
            });
        }
    }

    // ---------------------------------------------------------------- keys

    fn keys(&mut self, ctx: &egui::Context) {
        let nothing_focused = ctx.memory(|m| m.focused().is_none());
        let (esc, typed) = ctx.input(|i| {
            let esc = i.key_pressed(Key::Escape);
            let typed: String = i
                .events
                .iter()
                .filter_map(|e| match e {
                    Event::Text(t) => Some(t.clone()),
                    _ => None,
                })
                .collect();
            (esc, typed)
        });
        if nothing_focused && !typed.is_empty() && self.sheet.is_none() {
            self.query.push_str(&typed);
            self.typed_at = Some(Instant::now());
            self.focus_search = true;
        }
        if esc {
            if self.sheet.as_ref().map(|s| s.closing.is_none()).unwrap_or(false) {
                self.acts.push(Act::Close);
            } else if self.log_open {
                self.log_open = false;
            } else if !self.query.is_empty() {
                self.query.clear();
                self.typed_at = None;
            } else {
                ctx.send_viewport_cmd(ViewportCommand::Close);
            }
        }
        if ctx.input(|i| i.viewport().close_requested()) && self.jobs.busy() {
            ctx.send_viewport_cmd(ViewportCommand::CancelClose);
            self.close_when_idle = true;
            self.toast = Some((t("Finishing the installation first, then closing").into(), Instant::now(), true));
        }
    }
}

fn style(ctx: &egui::Context, pal: &Pal) {
    ctx.all_styles_mut(|s| {
        let v = &mut s.visuals;
        *v = if pal.dark { egui::Visuals::dark() } else { egui::Visuals::light() };
        v.override_text_color = Some(pal.text);
        v.panel_fill = Color32::TRANSPARENT;
        v.window_fill = pal.bg;
        v.extreme_bg_color = Color32::TRANSPARENT;
        v.selection.bg_fill = alpha(pal.accent, 0.35);
        v.selection.stroke = Stroke::new(1.0, pal.accent);
        v.text_cursor.stroke = Stroke::new(2.0, pal.accent);
        v.hyperlink_color = pal.accent;
        v.widgets.noninteractive.bg_stroke = Stroke::NONE;
        s.spacing.scroll.bar_width = 6.0;
        s.spacing.scroll.floating = true;
        s.spacing.scroll.bar_inner_margin = 4.0;
        s.spacing.item_spacing = vec2(10.0, 10.0);
        v.widgets.inactive.bg_fill = alpha(pal.text, 0.18);
        v.widgets.hovered.bg_fill = alpha(pal.text, 0.30);
        v.widgets.active.bg_fill = alpha(pal.accent, 0.6);
    });
}

impl eframe::App for Market {
    fn clear_color(&self, _v: &egui::Visuals) -> [f32; 4] {
        [0.0, 0.0, 0.0, 0.0]
    }

    fn ui(&mut self, ui: &mut Ui, _frame: &mut eframe::Frame) {
        let ctx = ui.ctx().clone();
        self.poll(&ctx);
        self.icons.poll(&ctx);
        self.keys(&ctx);
        if self.query.trim().to_lowercase() != self.hits_for {
            self.search();
            if self.typed_at.is_none() {
                self.typed_at = Some(Instant::now());
            }
        }
        if !self.query.trim().is_empty() {
            self.search_aur(&ctx);
        }

        if self.repo_ready {
            if let Some(n) = self.pending_show.take() {
                self.open_sheet(&ctx, &n);
            }
            if let Some(n) = self.pending_install.take() {
                self.open_sheet(&ctx, &n);
                self.acts.push(Act::Install(n));
            }
        }
        let full = ui.max_rect();
        self.background(ui, full);
        let side_w = 252.0;
        let side = Rect::from_min_size(full.min, vec2(side_w, full.height()));
        let main = Rect::from_min_max(pos2(full.left() + side_w, full.top()), full.max);
        ui.scope_builder(UiBuilder::new().max_rect(side).id_salt("side"), |ui| self.sidebar(ui, side));
        ui.scope_builder(UiBuilder::new().max_rect(main).id_salt("main"), |ui| self.main(ui, main));
        self.sheet_layer(&ctx, full);
        self.jobs_layer(&ctx, full);
        self.toast_layer(&ctx, full);
        self.apply(&ctx);
        if self.job_list.iter().any(|j| j.active()) {
            ctx.request_repaint_after(Duration::from_millis(33));
        }
    }
}

// -------------------------------------------------------------------- drawing

impl Market {
    fn background(&self, ui: &Ui, r: Rect) {
        let p = ui.painter();
        let pal = &self.pal;
        p.rect_filled(r, CornerRadius::ZERO, pal.floor());
        // two soft lights in the theme's colors
        glow(p, pos2(r.left() + 120.0, r.top() + 40.0), 520.0, alpha(pal.accent, if pal.dark { 0.10 } else { 0.14 }));
        glow(p, pos2(r.right() - 160.0, r.bottom() - 60.0), 620.0, alpha(hsl(hue_of(pal.accent) + 50.0, 0.6, 0.6), 0.06));
        // sidebar floor
        let side = Rect::from_min_size(r.min, vec2(252.0, r.height()));
        p.rect_filled(side, CornerRadius::ZERO, alpha(pal.pill, if pal.dark { 0.35 } else { 0.08 }));
        p.line_segment([side.right_top(), side.right_bottom()], Stroke::new(1.0, pal.line()));
    }

    fn sidebar(&mut self, ui: &mut Ui, r: Rect) {
        let pal = self.pal.clone();
        let p = ui.painter().clone();
        // logo
        let logo = Rect::from_min_size(r.min + vec2(22.0, 26.0), vec2(40.0, 40.0));
        shadow(&p, logo, 12.0, 0.7);
        let h0 = hue_of(pal.accent);
        rounded_gradient(&p, logo, 12.0, mix(pal.accent, Color32::WHITE, 0.15), hsl(h0 + 35.0, 0.7, 0.68), hsl(h0 - 30.0, 0.65, 0.58), hsl(h0 + 10.0, 0.7, 0.5));
        glyph(&p, logo.shrink(9.0), Glyph::Package, pal.accent_text);
        p.text(pos2(logo.right() + 12.0, logo.top() + 2.0), Align2::LEFT_TOP, "archmarket", display(18.0), pal.text);
        p.text(pos2(logo.right() + 12.0, logo.bottom() - 1.0), Align2::LEFT_BOTTOM, "pacman · AUR", body(12.0), alpha(pal.muted, 0.8));

        let mut y = logo.bottom() + 30.0;
        let row_h = 40.0;
        let mut rows: Vec<(Page, &'static str, Glyph, Option<String>, f32)> = Vec::new();
        let upd = match &self.updates {
            Some(Ok(l)) if !l.is_empty() => Some(l.len().to_string()),
            _ => None,
        };
        let explicit = self.local.values().filter(|l| l.explicit).count();
        rows.push((Page::Discover, "Discover", Glyph::Compass, None, y));
        y += row_h;
        rows.push((Page::Installed, "Installed", Glyph::Package, (explicit > 0).then(|| explicit.to_string()), y));
        y += row_h;
        rows.push((Page::Updates, "Updates", Glyph::Refresh, upd, y));
        y += row_h + 22.0;
        let cat_label_y = y - 8.0;
        for (i, c) in CATS.iter().enumerate() {
            rows.push((Page::Category(i), c.title, c.glyph, None, y));
            y += row_h - 4.0;
        }
        let searching = !self.query.trim().is_empty();
        // sliding highlight
        if let Some(cur) = rows.iter().find(|row| row.0 == self.page) {
            let target = cur.4;
            let ay = ui.ctx().animate_value_with_time(Id::new("side-hl"), target, 0.22);
            let h = if matches!(self.page, Page::Category(_)) { row_h - 4.0 } else { row_h };
            let hl = Rect::from_min_size(pos2(r.left() + 12.0, ay), vec2(r.width() - 24.0, h - 4.0));
            let on = if searching { 0.45 } else { 1.0 };
            p.rect_filled(hl, CornerRadius::same(12), alpha(pal.accent, 0.16 * on));
            let bar = Rect::from_min_size(pos2(hl.left(), hl.center().y - 8.0), vec2(3.0, 16.0));
            p.rect_filled(bar, CornerRadius::same(2), alpha(pal.accent, on));
        }
        p.text(pos2(r.left() + 26.0, cat_label_y), Align2::LEFT_BOTTOM, t("CATEGORIES"), semi(11.0), alpha(pal.muted, 0.6));
        for (page, title, g, count, ry) in rows {
            let h = if matches!(page, Page::Category(_)) { row_h - 4.0 } else { row_h };
            let rect = Rect::from_min_size(pos2(r.left() + 12.0, ry), vec2(r.width() - 24.0, h - 4.0));
            let id = Id::new(("side", format!("{page:?}")));
            let resp = ui.interact(rect, id, Sense::click());
            let hov = ui.ctx().animate_bool_with_time(id, resp.hovered(), 0.12);
            if hov > 0.0 {
                p.rect_filled(rect, CornerRadius::same(12), alpha(pal.text, 0.05 * hov));
            }
            let active = self.page == page;
            let fg = if active { pal.accent } else { mix(pal.muted, pal.text, hov) };
            glyph(&p, Rect::from_center_size(pos2(rect.left() + 22.0, rect.center().y), vec2(18.0, 18.0)), g, fg);
            p.text(pos2(rect.left() + 44.0, rect.center().y), Align2::LEFT_CENTER, t(title), if active { semi(14.0) } else { body(14.0) }, if active { pal.text } else { mix(pal.muted, pal.text, 0.4 + hov * 0.6) });
            if let Some(c) = count {
                let is_upd = page == Page::Updates;
                let g = p.layout_no_wrap(c, semi(11.0), if is_upd { pal.accent_text } else { pal.muted });
                let b = Rect::from_min_size(pos2(rect.right() - 12.0 - g.size().x - 14.0, rect.center().y - 10.0), vec2(g.size().x + 14.0, 20.0));
                p.rect_filled(b, CornerRadius::same(10), if is_upd { pal.accent } else { alpha(pal.text, 0.07) });
                p.galley(b.center() - g.size() / 2.0, g, pal.text);
            }
            if resp.clicked() {
                self.acts.push(Act::Go(page));
            }
            if resp.hovered() {
                ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand);
            }
        }

        // what the store knows, at the bottom
        let foot = Rect::from_min_max(pos2(r.left() + 16.0, r.bottom() - 84.0), pos2(r.right() - 16.0, r.bottom() - 16.0));
        p.rect_filled(foot, CornerRadius::same(14), alpha(pal.text, 0.04));
        let pk = if self.repo_ready { group(self.cat.repo.len()) } else { "…".into() };
        let ap = if self.apps_ready { group(self.cat.apps.len()) } else { "…".into() };
        p.text(foot.left_top() + vec2(14.0, 12.0), Align2::LEFT_TOP, tf("{} packages", &pk), semi(13.0), pal.text);
        p.text(foot.left_top() + vec2(14.0, 31.0), Align2::LEFT_TOP, tf("{} apps with icons", &ap), body(12.0), pal.muted);
        let mut x = foot.left() + 14.0;
        for (name, ok) in [("pacman", true), ("yay", self.have_yay)] {
            let c = if ok { pal.good } else { pal.error };
            p.circle_filled(pos2(x + 3.0, foot.bottom() - 15.0), 3.0, c);
            let g = p.layout_no_wrap(name.into(), mono(11.0), pal.muted);
            let w = g.size().x;
            p.galley(pos2(x + 10.0, foot.bottom() - 15.0 - g.size().y / 2.0), g, pal.muted);
            x += w + 26.0;
        }
    }

    fn main(&mut self, ui: &mut Ui, r: Rect) {
        let pal = self.pal.clone();
        // search
        let bar = Rect::from_min_size(r.min + vec2(32.0, 24.0), vec2((r.width() - 64.0).min(720.0), 48.0));
        let focused = ui.ctx().memory(|m| m.focused() == Some(Id::new("search")));
        let f = ui.ctx().animate_bool_with_time(Id::new("search-f"), focused, 0.18);
        let p = ui.painter().clone();
        if f > 0.0 {
            p.rect_filled(bar.expand(3.0 * f), CornerRadius::same(27), alpha(pal.accent, 0.18 * f));
        }
        p.rect_filled(bar, CornerRadius::same(24), alpha(pal.text, 0.07 + 0.03 * f));
        p.rect_stroke(bar, CornerRadius::same(24), Stroke::new(1.0, alpha(pal.accent, 0.2 + 0.5 * f)), StrokeKind::Inside);
        glyph(&p, Rect::from_center_size(pos2(bar.left() + 26.0, bar.center().y), vec2(20.0, 20.0)), Glyph::Search, mix(pal.muted, pal.accent, f));
        let edit_rect = Rect::from_min_max(pos2(bar.left() + 48.0, bar.center().y - 12.0), pos2(bar.right() - 44.0, bar.center().y + 12.0));
        let hint = if self.repo_ready {
            tf("Search {} packages and the AUR", &group(self.cat.repo.len()))
        } else {
            t("Search packages and the AUR").to_string()
        };
        let before = self.query.clone();
        let edit = egui::TextEdit::singleline(&mut self.query)
            .id(Id::new("search"))
            .frame(egui::Frame::NONE)
            .font(body(16.5))
            .text_color(pal.text)
            .hint_text(egui::RichText::new(hint).color(alpha(pal.muted, 0.65)).font(body(16.5)))
            .margin(egui::Margin::symmetric(0, 2))
            .desired_width(edit_rect.width());
        let resp = ui.put(edit_rect, edit);
        if self.focus_search && self.sheet.is_none() {
            resp.request_focus();
            if let Some(mut st) = egui::TextEdit::load_state(ui.ctx(), resp.id) {
                let end = egui::text::CCursor::new(self.query.chars().count());
                st.cursor.set_char_range(Some(egui::text::CCursorRange::one(end)));
                st.store(ui.ctx(), resp.id);
            }
            self.focus_search = false;
        }
        if self.query != before {
            self.typed_at = Some(Instant::now());
        }
        if resp.lost_focus() && ui.input(|i| i.key_pressed(Key::Enter)) {
            if let Some(first) = self.hits.first().cloned().or_else(|| self.aur_hits.first().cloned()) {
                self.acts.push(Act::Show(first));
            }
        }
        if !self.query.is_empty() {
            let x = Rect::from_center_size(pos2(bar.right() - 24.0, bar.center().y), vec2(28.0, 28.0));
            let xr = ui.interact(x, Id::new("clear"), Sense::click());
            if xr.hovered() {
                p.circle_filled(x.center(), 14.0, alpha(pal.text, 0.08));
            }
            glyph(&p, x.shrink(8.0), Glyph::Close, pal.muted);
            if xr.clicked() {
                self.query.clear();
                self.typed_at = None;
                self.focus_search = true;
            }
        }
        // keys hint on the right
        let hint_r = Rect::from_min_max(pos2(bar.right() + 16.0, bar.top()), pos2(r.right() - 32.0, bar.bottom()));
        if hint_r.width() > 160.0 {
            let busy = self.job_list.iter().filter(|j| j.active()).count();
            if busy > 0 {
                spinner(&p, pos2(hint_r.right() - 10.0, hint_r.center().y), 8.0, pal.accent, ui.input(|i| i.time));
                p.text(pos2(hint_r.right() - 26.0, hint_r.center().y), Align2::RIGHT_CENTER, tf("{} in progress", &busy.to_string()), body(13.0), pal.muted);
            } else {
                p.text(pos2(hint_r.right(), hint_r.center().y), Align2::RIGHT_CENTER, t("Esc closes"), body(12.0), alpha(pal.muted, 0.55));
            }
        }

        let content = Rect::from_min_max(pos2(r.left(), bar.bottom() + 14.0), r.max);
        let key = if self.query.trim().is_empty() { format!("{:?}", self.page) } else { "search".into() };
        let now = ui.input(|i| i.time);
        let since = ui.ctx().data_mut(|d| {
            let k = Id::new("content-key");
            let old: Option<(String, f64)> = d.get_temp(k);
            match old {
                Some((o, t0)) if o == key => now - t0,
                _ => {
                    d.insert_temp(k, (key.clone(), now));
                    0.0
                }
            }
        }) as f32;
        let a = ease_out(since / 0.32);
        if a < 1.0 {
            ui.ctx().request_repaint();
        }
        let shifted = content.translate(vec2(0.0, (1.0 - a) * 18.0));
        ui.scope_builder(UiBuilder::new().max_rect(shifted).id_salt(("content", key.clone())), |ui| {
            ui.multiply_opacity(a);
            ui.set_clip_rect(content);
            if !self.repo_ready {
                self.loading(ui, content);
            } else if !self.query.trim().is_empty() {
                self.results_page(ui);
            } else {
                match self.page {
                    Page::Discover => self.discover(ui),
                    Page::Category(i) => self.category(ui, i),
                    Page::Installed => self.installed(ui),
                    Page::Updates => self.updates_page(ui),
                }
            }
        });
    }

    fn loading(&self, ui: &mut Ui, r: Rect) {
        let p = ui.painter();
        let time = ui.input(|i| i.time);
        spinner(p, r.center() - vec2(0.0, 30.0), 18.0, self.pal.accent, time);
        p.text(r.center() + vec2(0.0, 6.0), Align2::CENTER_TOP, t(self.status), body(15.0), self.pal.muted);
        ui.ctx().request_repaint();
    }

    fn scroll(&self, id: &str) -> egui::ScrollArea {
        egui::ScrollArea::vertical()
            .id_salt(id)
            .auto_shrink([false, false])
            .content_margin(egui::Margin { left: 32, right: 32, top: 6, bottom: 120 })
    }

    fn heading(&self, ui: &mut Ui, title: &str, sub: Option<String>) {
        ui.add_space(6.0);
        let w = ui.available_width();
        let (r, _) = ui.allocate_exact_size(vec2(w, if sub.is_some() { 54.0 } else { 34.0 }), Sense::hover());
        let p = ui.painter();
        p.text(r.left_top(), Align2::LEFT_TOP, title, display(22.0), self.pal.text);
        if let Some(s) = sub {
            p.text(r.left_top() + vec2(0.0, 34.0), Align2::LEFT_TOP, s, body(13.5), self.pal.muted);
        }
    }

    fn shelf_title(&self, ui: &mut Ui, title: &str, sub: &str) {
        ui.add_space(24.0);
        let w = ui.available_width();
        let (r, _) = ui.allocate_exact_size(vec2(w, 40.0), Sense::hover());
        let p = ui.painter();
        p.text(r.left_top(), Align2::LEFT_TOP, title, semi(18.0), self.pal.text);
        p.text(r.left_top() + vec2(0.0, 24.0), Align2::LEFT_TOP, sub, body(12.5), self.pal.muted);
    }

    // ---------------------------------------------------------------- discover

    fn discover(&mut self, ui: &mut Ui) {
        self.scroll("discover").show(ui, |ui| {
            self.hero(ui);
            for (si, (title, names)) in SHELVES.iter().enumerate() {
                let list: Vec<String> = names
                    .iter()
                    .filter(|n| self.cat.index.contains_key(**n))
                    .map(|n| n.to_string())
                    .collect();
                if list.is_empty() {
                    continue;
                }
                let sub = match si {
                    0 => t("The apps most people install first"),
                    1 => t("Draw, edit photos, make videos and music"),
                    2 => t("Editors and tools for writing code"),
                    _ => t("Games and launchers"),
                };
                self.shelf_title(ui, t(title), sub);
                self.card_grid(ui, &list);
            }
            if !self.picks.is_empty() {
                self.shelf_title(ui, t("Popular in the AUR"), t("Built from source by yay, maintained by the community"));
                let picks = self.picks.clone();
                self.card_grid(ui, &picks);
            }
            ui.add_space(10.0);
            self.shelf_title(ui, t("Browse by category"), t("Every app with a real icon, sorted by name"));
            self.category_tiles(ui);
        });
    }

    fn hero(&mut self, ui: &mut Ui) {
        let picks: Vec<&str> = HERO
            .iter()
            .copied()
            .filter(|n| self.cat.index.contains_key(*n) && self.cat.apps.get(*n).and_then(|a| a.icon.as_ref()).is_some())
            .collect();
        let w = ui.available_width();
        let (r, _) = ui.allocate_exact_size(vec2(w, 236.0), Sense::hover());
        if picks.is_empty() {
            return;
        }
        if self.hero_since.elapsed() > Duration::from_secs(7) && self.sheet.is_none() {
            self.hero = (self.hero + 1) % picks.len();
            self.hero_since = Instant::now();
        }
        let idx = self.hero % picks.len();
        let name = picks[idx].to_string();
        let pal = self.pal.clone();
        let p = ui.painter().clone();
        let time = ui.input(|i| i.time);
        let h0 = hue_of(pal.accent);
        shadow(&p, r, 26.0, 0.8);
        // the card: a gradient in the theme's hues, darkened for text
        let (l1, l2) = if pal.dark { (0.30, 0.18) } else { (0.78, 0.66) };
        rounded_gradient(&p, r, 26.0, hsl(h0, 0.55, l1), hsl(h0 + 40.0, 0.5, l2), hsl(h0 - 30.0, 0.5, l2), hsl(h0 + 10.0, 0.45, l2 * 0.8));
        glow(&p, pos2(r.right() - 190.0, r.center().y), 200.0, alpha(pal.accent, 0.30));
        p.rect_stroke(r, CornerRadius::same(26), Stroke::new(1.0, alpha(Color32::WHITE, 0.10)), StrokeKind::Inside);
        let fade = ease_out(self.hero_since.elapsed().as_secs_f32() / 0.5);
        if fade < 1.0 {
            ui.ctx().request_repaint();
        } else {
            ui.ctx().request_repaint_after(Duration::from_millis(7000).saturating_sub(self.hero_since.elapsed()));
        }
        let item = self.item(&name);
        let text_c = if pal.dark { Color32::WHITE } else { Color32::from_gray(20) };
        let sub_c = alpha(text_c, 0.75);
        if let Some(it) = item.clone() {
            let off = (1.0 - fade) * 16.0;
            let x = r.left() + 36.0 + off;
            p.text(pos2(x, r.top() + 34.0), Align2::LEFT_TOP, t("EDITOR'S PICK"), semi(11.5), alpha(text_c, 0.6 * fade));
            p.text(pos2(x, r.top() + 54.0), Align2::LEFT_TOP, &it.title, display(34.0), alpha(text_c, fade));
            let g = wrap_galley(ui, &it.summary, body(15.0), alpha(sub_c, fade), (r.width() * 0.5).min(460.0), 2);
            p.galley(pos2(x, r.top() + 104.0), g, sub_c);
            let ui_rect = Rect::from_min_max(pos2(r.left() + 36.0, r.bottom() - 72.0), pos2(r.center().x, r.bottom() - 28.0));
            ui.scope_builder(UiBuilder::new().max_rect(ui_rect).layout(egui::Layout::left_to_right(egui::Align::Center)), |ui| {
                self.action_buttons(ui, &it, 40.0, "hero");
                if button(ui, &pal, Id::new("hero-more"), t("Details"), None, Btn::Ghost, 40.0).clicked() {
                    self.acts.push(Act::Show(it.name.clone()));
                }
            });
        }
        // the icon, floating, with the other picks orbiting around it
        let c = pos2(r.right() - 190.0, r.center().y);
        for (i, other) in picks.iter().enumerate() {
            if i == idx {
                continue;
            }
            let a = time as f32 * 0.25 + i as f32 * std::f32::consts::TAU / picks.len() as f32;
            let pos = c + vec2(a.cos() * 140.0, a.sin() * 70.0);
            let depth = (a.sin() + 1.0) / 2.0;
            let s = 26.0 + depth * 12.0;
            let rr = Rect::from_center_size(pos, vec2(s, s));
            let tex = self.icon(other);
            let resp = ui.interact(rr, Id::new(("orbit", i)), Sense::click());
            if let Some(tex) = tex {
                egui::Image::new(&tex).tint(Color32::from_white_alpha((120.0 + depth * 135.0) as u8)).paint_at(ui, rr);
            }
            if resp.clicked() {
                self.acts.push(Act::Hero(i));
            }
            if resp.hovered() {
                ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand);
            }
        }
        let bob = (time as f32 * 1.4).sin() * 5.0;
        let big = Rect::from_center_size(c + vec2(0.0, bob), vec2(124.0, 124.0) * (0.85 + 0.15 * fade));
        let tex = self.icon(&name);
        glow(&p, c, 120.0, alpha(Color32::BLACK, 0.18));
        if let Some(tex) = tex {
            egui::Image::new(&tex).tint(Color32::from_white_alpha((fade * 255.0) as u8)).paint_at(ui, big);
        }
        let big_resp = ui.interact(big, Id::new("hero-icon"), Sense::click());
        if big_resp.clicked() {
            self.acts.push(Act::Show(name.clone()));
        }
        ui.ctx().request_repaint_after(Duration::from_millis(30));
        // dots
        let n = picks.len();
        let dots_w = n as f32 * 14.0;
        for i in 0..n {
            let d = pos2(r.right() - 190.0 - dots_w / 2.0 + i as f32 * 14.0 + 7.0, r.bottom() - 20.0);
            let on = i == idx;
            let rr = Rect::from_center_size(d, vec2(if on { 18.0 } else { 6.0 }, 6.0));
            p.rect_filled(rr, CornerRadius::same(3), alpha(text_c, if on { 0.9 } else { 0.35 }));
            if ui.interact(Rect::from_center_size(d, vec2(14.0, 16.0)), Id::new(("dot", i)), Sense::click()).clicked() {
                self.acts.push(Act::Hero(i));
            }
        }
    }

    /// Install, Remove, Open or progress for one package.
    fn action_buttons(&mut self, ui: &mut Ui, it: &Item, h: f32, salt: &str) {
        let pal = self.pal.clone();
        let time = ui.input(|i| i.time);
        if let Some(job) = self.job_for(&it.name) {
            let label = match (job.kind, &job.state) {
                (_, State::Queued) => t("Queued"),
                (_, State::Waiting) => t("Waiting for pacman"),
                (Kind::Remove, _) => t("Removing…"),
                _ => t("Installing…"),
            };
            let w = button_width(ui, label, true, h).max(150.0);
            let (rect, _) = ui.allocate_exact_size(vec2(w, h), Sense::hover());
            let p = ui.painter();
            p.rect_filled(rect, CornerRadius::same((h / 2.0) as u8), alpha(pal.accent, 0.14));
            spinner(p, pos2(rect.left() + h * 0.5, rect.center().y), h * 0.2, pal.accent, time);
            p.text(pos2(rect.left() + h * 0.9, rect.center().y - 4.0), Align2::LEFT_CENTER, label, semi(h * 0.33), pal.accent);
            progress(p, &pal, Rect::from_min_size(pos2(rect.left() + h * 0.9, rect.center().y + h * 0.18), vec2(rect.width() - h * 1.3, 3.0)), job.progress, time);
            return;
        }
        if it.installed {
            self.ensure_desktop(ui.ctx(), &it.name);
            if let Some(Some(_)) = self.desktop.get(&it.name) {
                if button(ui, &pal, Id::new((salt, "open", &it.name)), t("Open"), Some(Glyph::Open), Btn::Primary, h).clicked() {
                    self.acts.push(Act::Launch(it.name.clone()));
                }
            }
            if PROTECTED.contains(&it.name.as_str()) {
                let (rect, _) = ui.allocate_exact_size(vec2(button_width(ui, t("Installed"), true, h), h), Sense::hover());
                let p = ui.painter();
                p.rect_filled(rect, CornerRadius::same((h / 2.0) as u8), alpha(pal.good, 0.12));
                glyph(p, Rect::from_center_size(pos2(rect.left() + h * 0.55, rect.center().y), vec2(h * 0.45, h * 0.45)), Glyph::Check, pal.good);
                p.text(pos2(rect.left() + h * 0.95, rect.center().y), Align2::LEFT_CENTER, t("Installed"), semi(h * 0.4), pal.good);
                return;
            }
            let confirming = matches!(&self.confirm, Some((n, at)) if *n == it.name && at.elapsed() < Duration::from_secs(4));
            let label = if confirming { t("Remove for sure?") } else { t("Remove") };
            if confirming {
                ui.ctx().request_repaint_after(Duration::from_millis(200));
            }
            if button(ui, &pal, Id::new((salt, "rm", &it.name)), label, Some(Glyph::Trash), Btn::Danger, h).clicked() {
                self.acts.push(Act::Remove(it.name.clone()));
            }
        } else if button(ui, &pal, Id::new((salt, "in", &it.name)), t("Install"), Some(Glyph::Download), Btn::Primary, h).clicked() {
            self.acts.push(Act::Install(it.name.clone()));
        }
    }

    fn card_grid(&mut self, ui: &mut Ui, names: &[String]) {
        let w = ui.available_width();
        let gap = 14.0;
        let cols = ((w + gap) / 250.0).floor().max(2.0) as usize;
        let cw = (w - gap * (cols as f32 - 1.0)) / cols as f32;
        let ch = 176.0;
        let rows = names.len().div_ceil(cols).min(2);
        let (area, _) = ui.allocate_exact_size(vec2(w, rows as f32 * (ch + gap) - gap), Sense::hover());
        for (i, name) in names.iter().take(cols * rows).enumerate() {
            let (row, col) = (i / cols, i % cols);
            let rect = Rect::from_min_size(area.min + vec2(col as f32 * (cw + gap), row as f32 * (ch + gap)), vec2(cw, ch));
            if ui.is_rect_visible(rect) {
                self.card(ui, rect, name);
            }
        }
    }

    fn card(&mut self, ui: &mut Ui, rect: Rect, name: &str) {
        let Some(it) = self.item(name) else { return };
        let pal = self.pal.clone();
        let id = Id::new(("card", name));
        let resp = ui.interact(rect, id, Sense::click());
        let hov = ui.ctx().animate_bool_with_time(id, resp.hovered(), 0.16);
        let lift = hov * 3.0;
        let r = rect.translate(vec2(0.0, -lift));
        let p = ui.painter().clone();
        if hov > 0.0 {
            shadow(&p, r, 20.0, hov * 0.8);
        }
        p.rect_filled(r, CornerRadius::same(20), mix(pal.card(), pal.card_hover(), hov));
        p.rect_stroke(r, CornerRadius::same(20), Stroke::new(1.0, alpha(pal.text, 0.06 + hov * 0.06)), StrokeKind::Inside);
        let icon_r = Rect::from_min_size(r.min + vec2(18.0, 18.0), vec2(56.0, 56.0));
        let tex = self.icon(name);
        avatar(ui, &pal, icon_r, tex.as_ref(), &it.title);
        badge(&p, &pal, pos2(r.right() - 16.0, r.top() + 18.0), &it.repo, Align2::RIGHT_TOP);
        let tw = r.width() - 36.0;
        p.text(pos2(r.left() + 18.0, icon_r.bottom() + 12.0), Align2::LEFT_TOP, elide(ui, &it.title, semi(15.5), tw), semi(15.5), pal.text);
        let g = wrap_galley(ui, &it.summary, body(12.5), pal.muted, tw, 2);
        p.galley(pos2(r.left() + 18.0, icon_r.bottom() + 34.0), g, pal.muted);
        // the action, bottom right
        let btn_h = 30.0;
        let btn_area = Rect::from_min_max(pos2(r.left() + 14.0, r.bottom() - btn_h - 14.0), pos2(r.right() - 14.0, r.bottom() - 14.0));
        if it.installed && self.job_for(name).is_none() {
            p.text(pos2(btn_area.left() + 4.0, btn_area.center().y), Align2::LEFT_CENTER, t("Installed"), semi(12.5), pal.good);
            glyph(&p, Rect::from_center_size(pos2(btn_area.right() - 12.0, btn_area.center().y), vec2(18.0, 18.0)), Glyph::Check, pal.good);
        } else if self.job_for(name).is_some() || hov > 0.01 {
            ui.scope_builder(UiBuilder::new().max_rect(btn_area).layout(egui::Layout::right_to_left(egui::Align::Center)), |ui| {
                ui.multiply_opacity(if self.job_for(name).is_some() { 1.0 } else { hov });
                self.action_buttons(ui, &it, btn_h, "card");
            });
        } else {
            let size = if it.size > 0 { human_size(it.size) } else { it.version.clone() };
            p.text(pos2(btn_area.left() + 4.0, btn_area.center().y), Align2::LEFT_CENTER, elide(ui, &size, body(12.0), btn_area.width()), body(12.0), alpha(pal.muted, 0.8));
        }
        if resp.clicked() {
            self.acts.push(Act::Show(name.to_string()));
        }
        if resp.hovered() {
            ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand);
        }
    }

    fn category_tiles(&mut self, ui: &mut Ui) {
        let w = ui.available_width();
        let gap = 12.0;
        let cols = ((w + gap) / 200.0).floor().clamp(2.0, 5.0) as usize;
        let cw = (w - gap * (cols as f32 - 1.0)) / cols as f32;
        let ch = 76.0;
        let rows = CATS.len().div_ceil(cols);
        let (area, _) = ui.allocate_exact_size(vec2(w, rows as f32 * (ch + gap)), Sense::hover());
        let pal = self.pal.clone();
        for (i, c) in CATS.iter().enumerate() {
            let rect = Rect::from_min_size(area.min + vec2((i % cols) as f32 * (cw + gap), (i / cols) as f32 * (ch + gap)), vec2(cw, ch));
            let id = Id::new(("tile", i));
            let resp = ui.interact(rect, id, Sense::click());
            let hov = ui.ctx().animate_bool_with_time(id, resp.hovered(), 0.15);
            let p = ui.painter();
            let hue = hue_of(pal.accent) + (i as f32 - 4.0) * 22.0;
            let tint = hsl(hue, 0.55, if pal.dark { 0.65 } else { 0.45 });
            rounded_gradient(p, rect, 18.0, alpha(tint, 0.18 + hov * 0.08), alpha(tint, 0.06), alpha(tint, 0.09), alpha(tint, 0.03));
            p.rect_stroke(rect, CornerRadius::same(18), Stroke::new(1.0, alpha(tint, 0.18 + hov * 0.2)), StrokeKind::Inside);
            glyph(p, Rect::from_center_size(pos2(rect.left() + 34.0, rect.center().y), vec2(24.0 + hov * 2.0, 24.0 + hov * 2.0)), c.glyph, tint);
            p.text(pos2(rect.left() + 62.0, rect.center().y - 9.0), Align2::LEFT_CENTER, elide(ui, t(c.title), semi(14.0), cw - 74.0), semi(14.0), pal.text);
            let n = if self.apps_ready { self.cat_list(i).len() } else { 0 };
            let p = ui.painter();
            p.text(pos2(rect.left() + 62.0, rect.center().y + 11.0), Align2::LEFT_CENTER, tf("{} apps", &n.to_string()), body(12.0), pal.muted);
            if resp.clicked() {
                self.acts.push(Act::Go(Page::Category(i)));
            }
            if resp.hovered() {
                ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand);
            }
        }
    }

    // ---------------------------------------------------------------- category

    fn category(&mut self, ui: &mut Ui, i: usize) {
        if !self.apps_ready {
            let r = ui.max_rect();
            self.loading(ui, r);
            return;
        }
        let list = self.cat_list(i).clone();
        let title = t(CATS[i].title);
        let pal = self.pal.clone();
        let w = ui.max_rect().width() - 64.0;
        let gap = 14.0;
        let cols = ((w + gap) / 330.0).floor().max(1.0) as usize;
        let cw = (w - gap * (cols as f32 - 1.0)) / cols as f32;
        let ch = 104.0;
        let rows = list.len().div_ceil(cols);
        egui::ScrollArea::vertical()
            .id_salt(("cat", i))
            .auto_shrink([false, false])
            .content_margin(egui::Margin { left: 32, right: 32, top: 6, bottom: 120 })
            .show(ui, |ui| {
                let (hr, _) = ui.allocate_exact_size(vec2(w, 60.0), Sense::hover());
                let p = ui.painter();
                glyph(p, Rect::from_min_size(hr.min + vec2(0.0, 6.0), vec2(26.0, 26.0)), CATS[i].glyph, pal.accent);
                p.text(hr.min + vec2(40.0, 2.0), Align2::LEFT_TOP, title, display(22.0), pal.text);
                p.text(hr.min + vec2(40.0, 36.0), Align2::LEFT_TOP, tf("{} apps", &list.len().to_string()), body(13.0), pal.muted);
                for row in 0..rows {
                    let (rr, _) = ui.allocate_exact_size(vec2(w, ch), Sense::hover());
                    if !ui.is_rect_visible(rr) {
                        continue;
                    }
                    for col in 0..cols {
                        let k = row * cols + col;
                        if k >= list.len() {
                            break;
                        }
                        let rect = Rect::from_min_size(rr.min + vec2(col as f32 * (cw + gap), 0.0), vec2(cw, ch));
                        self.wide_card(ui, rect, &list[k]);
                    }
                }
            });
    }

    fn wide_card(&mut self, ui: &mut Ui, rect: Rect, name: &str) {
        let Some(it) = self.item(name) else { return };
        let pal = self.pal.clone();
        let id = Id::new(("wide", name));
        let resp = ui.interact(rect, id, Sense::click());
        let hov = ui.ctx().animate_bool_with_time(id, resp.hovered(), 0.15);
        let p = ui.painter().clone();
        p.rect_filled(rect, CornerRadius::same(18), mix(pal.card(), pal.card_hover(), hov));
        let icon_r = Rect::from_min_size(rect.min + vec2(16.0, 18.0), vec2(52.0, 52.0));
        let tex = self.icon(name);
        avatar(ui, &pal, icon_r, tex.as_ref(), &it.title);
        let x = icon_r.right() + 14.0;
        let tw = rect.right() - x - 14.0;
        p.text(pos2(x, rect.top() + 16.0), Align2::LEFT_TOP, elide(ui, &it.title, semi(15.0), tw - 30.0), semi(15.0), pal.text);
        let g = wrap_galley(ui, &it.summary, body(12.5), pal.muted, tw, 2);
        p.galley(pos2(x, rect.top() + 38.0), g, pal.muted);
        if it.installed {
            glyph(&p, Rect::from_min_size(pos2(rect.right() - 30.0, rect.top() + 16.0), vec2(16.0, 16.0)), Glyph::Check, pal.good);
        }
        if let Some(job) = self.job_for(name) {
            progress(&p, &pal, Rect::from_min_size(pos2(x, rect.bottom() - 14.0), vec2(tw, 3.0)), job.progress, ui.input(|i| i.time));
        }
        if resp.clicked() {
            self.acts.push(Act::Show(name.to_string()));
        }
        if resp.hovered() {
            ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand);
        }
    }

    // ---------------------------------------------------------------- lists

    fn row(&mut self, ui: &mut Ui, name: &str, extra: Option<String>) {
        let w = ui.available_width();
        let (rect, _) = ui.allocate_exact_size(vec2(w, 70.0), Sense::hover());
        if !ui.is_rect_visible(rect) {
            return;
        }
        let Some(it) = self.item(name) else { return };
        let pal = self.pal.clone();
        let id = Id::new(("row", name));
        let resp = ui.interact(rect, id, Sense::click());
        let hov = ui.ctx().animate_bool_with_time(id, resp.hovered(), 0.12);
        let p = ui.painter().clone();
        p.rect_filled(rect, CornerRadius::same(16), alpha(pal.text, 0.025 + hov * 0.05));
        let icon_r = Rect::from_min_size(rect.min + vec2(14.0, 13.0), vec2(44.0, 44.0));
        let tex = self.icon(name);
        avatar(ui, &pal, icon_r, tex.as_ref(), &it.title);
        // right side: action and badges
        let right_w = 300.0f32.min(w * 0.42);
        let right = Rect::from_min_max(pos2(rect.right() - right_w, rect.top()), pos2(rect.right() - 14.0, rect.bottom()));
        ui.scope_builder(UiBuilder::new().max_rect(right).layout(egui::Layout::right_to_left(egui::Align::Center)), |ui| {
            self.action_buttons(ui, &it, 34.0, "row");
        });
        let x = icon_r.right() + 14.0;
        let text_w = right.left() - x - 90.0;
        let title = if it.title != it.name { format!("{}  ", it.title) } else { String::new() };
        let mut tx = x;
        if !title.is_empty() {
            let g = p.layout_no_wrap(elide(ui, &title, semi(15.0), text_w * 0.6), semi(15.0), pal.text);
            tx += g.size().x;
            p.galley(pos2(x, rect.top() + 14.0), g, pal.text);
        }
        let ng = p.layout_no_wrap(it.name.clone(), if title.is_empty() { semi(15.0) } else { mono(12.5) }, if title.is_empty() { pal.text } else { pal.muted });
        let nw = ng.size().x;
        p.galley(pos2(tx, rect.top() + 14.0 + if title.is_empty() { 0.0 } else { 2.0 }), ng, pal.muted);
        let b = badge(&p, &pal, pos2(tx + nw + 10.0, rect.top() + 13.0), &it.repo, Align2::LEFT_TOP);
        let ver = extra.unwrap_or_else(|| it.version.clone());
        p.text(pos2(b.right() + 8.0, b.center().y), Align2::LEFT_CENTER, elide(ui, &ver, mono(12.0), (right.left() - b.right() - 16.0).max(10.0)), mono(12.0), alpha(pal.muted, 0.75));
        p.text(pos2(x, rect.top() + 40.0), Align2::LEFT_TOP, elide(ui, &it.summary, body(13.0), right.left() - x - 12.0), body(13.0), pal.muted);
        if resp.clicked() {
            self.acts.push(Act::Show(name.to_string()));
        }
    }

    fn results_page(&mut self, ui: &mut Ui) {
        let pal = self.pal.clone();
        let hits = self.hits.clone();
        let aur = self.aur_hits.clone();
        let time = ui.input(|i| i.time);
        self.scroll("results").show(ui, |ui| {
            ui.horizontal(|ui| {
                for (s, label) in [(Scope::All, t("Everything")), (Scope::Repo, t("Repositories")), (Scope::Aur, "AUR")] {
                    if chip(ui, &pal, Id::new(("scope", label)), label, self.scope == s).clicked() {
                        self.scope = s;
                    }
                }
            });
            ui.add_space(6.0);
            // Apps first: what has a real icon in the repositories, then the
            // AUR packages people use most whose name carries the query.
            let q = self.query.trim().to_lowercase();
            let mut best: Vec<String> = Vec::new();
            if self.scope == Scope::All {
                best.extend(hits.iter().filter(|n| self.cat.apps.contains_key(*n)).take(3).cloned());
                let squeezed: String = q.split_whitespace().collect::<Vec<_>>().join("-");
                best.extend(
                    aur.iter()
                        .filter(|n| crate::icons::app_like(n))
                        .filter(|n| self.aur.get(*n).map(|p| p.votes >= 10 && (p.lname.contains(&squeezed) || p.ldesc.contains(&q))).unwrap_or(false))
                        .take(4)
                        .cloned(),
                );
            }
            if !best.is_empty() {
                self.shelf_title(ui, t("Best matches"), t("Apps from the repositories and the AUR"));
                for n in &best {
                    let extra = self.aur.get(n).filter(|_| !self.cat.index.contains_key(n)).map(|p| format!("{}  ·  {}", p.version, tf("{} votes", &p.votes.to_string())));
                    self.row(ui, n, extra);
                }
            }
            let hits: Vec<String> = hits.into_iter().filter(|n| !best.contains(n)).collect();
            let aur: Vec<String> = aur.into_iter().filter(|n| !best.contains(n)).collect();
            if self.scope != Scope::Aur {
                self.shelf_title(ui, t("Official repositories"), &tf("{} found", &hits.len().to_string()));
                if hits.is_empty() {
                    self.empty(ui, t("Nothing in the repositories"));
                }
                for n in &hits {
                    self.row(ui, n, None);
                }
            }
            if self.scope != Scope::Repo {
                let sub = if self.aur_loading {
                    t("Searching…").to_string()
                } else if let Some(e) = &self.aur_error {
                    if e == "offline" { t("No connection to the AUR").into() } else { e.clone() }
                } else {
                    tf("{} found", &aur.len().to_string())
                };
                ui.add_space(8.0);
                self.shelf_title(ui, t("AUR"), &sub);
                if self.aur_loading {
                    let (r, _) = ui.allocate_exact_size(vec2(ui.available_width(), 60.0), Sense::hover());
                    spinner(ui.painter(), r.center(), 12.0, pal.accent, time);
                    ui.ctx().request_repaint();
                } else {
                    if !aur.is_empty() && !self.have_yay {
                        self.empty(ui, t("Install yay to install from the AUR"));
                    }
                    for n in aur.iter().take(120) {
                        let pop = self.aur.get(n).map(|p| format!("{}  ·  {}", p.version, tf("{} votes", &p.votes.to_string())));
                        self.row(ui, n, pop);
                    }
                }
            }
        });
    }

    fn empty(&self, ui: &mut Ui, text: &str) {
        let (r, _) = ui.allocate_exact_size(vec2(ui.available_width(), 46.0), Sense::hover());
        ui.painter().text(r.left_center() + vec2(4.0, 0.0), Align2::LEFT_CENTER, text, body(13.5), alpha(self.pal.muted, 0.8));
    }

    fn installed(&mut self, ui: &mut Ui) {
        let pal = self.pal.clone();
        let mut names: Vec<(&String, &Local)> = self
            .local
            .iter()
            .filter(|(n, l)| match self.installed_filter {
                0 => l.explicit && self.cat.apps.contains_key(*n),
                1 => l.explicit,
                2 => l.foreign,
                _ => true,
            })
            .collect();
        names.sort_by(|a, b| a.0.cmp(b.0));
        let list: Vec<String> = names.iter().map(|(n, _)| n.to_string()).collect();
        let total: u64 = names.iter().map(|(_, l)| l.size).sum();
        self.scroll("installed").show(ui, |ui| {
            self.heading(ui, t("Installed"), Some(tf("{} packages", &list.len().to_string()) + " · " + &human_size(total)));
            ui.horizontal(|ui| {
                for (i, label) in [t("Apps"), t("Installed by you"), "AUR", t("Everything")].iter().enumerate() {
                    if chip(ui, &pal, Id::new(("inst", i)), label, self.installed_filter == i).clicked() {
                        self.installed_filter = i;
                    }
                }
            });
            ui.add_space(10.0);
            if list.is_empty() {
                self.empty(ui, t("Nothing here"));
            }
            for n in &list {
                let size = self.local.get(n).map(|l| format!("{}  ·  {}", l.version, human_size(l.size)));
                self.row(ui, n, size);
            }
        });
    }

    fn updates_page(&mut self, ui: &mut Ui) {
        let pal = self.pal.clone();
        let time = ui.input(|i| i.time);
        let upgrading = self.job_list.iter().any(|j| j.kind == Kind::Upgrade && j.active());
        self.scroll("updates").show(ui, |ui| {
            let list = match &self.updates {
                Some(Ok(l)) => l.clone(),
                _ => Vec::new(),
            };
            let sub = if self.updates_loading {
                t("Checking for updates…").to_string()
            } else {
                match &self.updates {
                    Some(Ok(l)) if l.is_empty() => t("Everything is up to date").into(),
                    Some(Ok(l)) => tf("{} updates are waiting", &l.len().to_string()),
                    Some(Err(e)) => e.clone(),
                    None => String::new(),
                }
            };
            self.heading(ui, t("Updates"), Some(sub));
            ui.horizontal(|ui| {
                if !list.is_empty() {
                    if upgrading {
                        let (r, _) = ui.allocate_exact_size(vec2(260.0, 40.0), Sense::hover());
                        let job = self.job_list.iter().find(|j| j.kind == Kind::Upgrade && j.active()).cloned();
                        let p = ui.painter();
                        p.rect_filled(r, CornerRadius::same(20), alpha(pal.accent, 0.14));
                        spinner(p, pos2(r.left() + 20.0, r.center().y), 8.0, pal.accent, time);
                        p.text(pos2(r.left() + 38.0, r.center().y - 5.0), Align2::LEFT_CENTER, t("Updating…"), semi(13.0), pal.accent);
                        progress(p, &pal, Rect::from_min_size(pos2(r.left() + 38.0, r.center().y + 8.0), vec2(r.width() - 56.0, 3.0)), job.and_then(|j| j.progress), time);
                    } else if button(ui, &pal, Id::new("upall"), t("Update everything"), Some(Glyph::Download), Btn::Primary, 40.0).clicked() {
                        self.acts.push(Act::UpgradeAll);
                    }
                }
                if !self.updates_loading && button(ui, &pal, Id::new("recheck"), t("Check again"), Some(Glyph::Refresh), Btn::Ghost, 40.0).clicked() {
                    self.acts.push(Act::CheckUpdates);
                }
            });
            ui.add_space(12.0);
            if self.updates_loading {
                let (r, _) = ui.allocate_exact_size(vec2(ui.available_width(), 120.0), Sense::hover());
                spinner(ui.painter(), r.center(), 16.0, pal.accent, time);
                ui.ctx().request_repaint();
                return;
            }
            if list.is_empty() {
                if let Some(Ok(_)) = &self.updates {
                    let (r, _) = ui.allocate_exact_size(vec2(ui.available_width(), 220.0), Sense::hover());
                    let p = ui.painter();
                    let c = r.center() - vec2(0.0, 20.0);
                    glow(p, c, 110.0, alpha(pal.good, 0.18));
                    p.circle_filled(c, 40.0, alpha(pal.good, 0.16));
                    glyph(p, Rect::from_center_size(c, vec2(40.0, 40.0)), Glyph::Check, pal.good);
                    p.text(c + vec2(0.0, 62.0), Align2::CENTER_TOP, t("Your system is fresh"), semi(16.0), pal.text);
                }
                return;
            }
            for u in &list {
                self.update_row(ui, u);
            }
        });
    }

    fn update_row(&mut self, ui: &mut Ui, u: &Update) {
        let pal = self.pal.clone();
        let w = ui.available_width();
        let (rect, _) = ui.allocate_exact_size(vec2(w, 58.0), Sense::hover());
        if !ui.is_rect_visible(rect) {
            return;
        }
        let id = Id::new(("upd", &u.name));
        let resp = ui.interact(rect, id, Sense::click());
        let hov = ui.ctx().animate_bool_with_time(id, resp.hovered(), 0.12);
        let p = ui.painter().clone();
        p.rect_filled(rect, CornerRadius::same(14), alpha(pal.text, 0.025 + hov * 0.05));
        let icon_r = Rect::from_min_size(rect.min + vec2(12.0, 11.0), vec2(36.0, 36.0));
        let tex = self.icon(&u.name);
        let title = self.cat.app(&u.name).map(|a| a.name.clone()).unwrap_or_else(|| u.name.clone());
        avatar(ui, &pal, icon_r, tex.as_ref(), &title);
        let x = icon_r.right() + 14.0;
        p.text(pos2(x, rect.top() + 11.0), Align2::LEFT_TOP, &u.name, semi(14.5), pal.text);
        let repo = if u.aur { "aur".to_string() } else { self.cat.get(&u.name).map(|p| p.repo.clone()).unwrap_or_default() };
        let g = p.layout_no_wrap(u.old.clone(), mono(12.0), alpha(pal.muted, 0.7));
        let gw = g.size().x;
        p.galley(pos2(x, rect.top() + 33.0), g, pal.muted);
        p.text(pos2(x + gw + 8.0, rect.top() + 33.0), Align2::LEFT_TOP, "→", mono(12.0), pal.muted);
        p.text(pos2(x + gw + 26.0, rect.top() + 33.0), Align2::LEFT_TOP, &u.new, mono(12.0), pal.accent);
        if !repo.is_empty() {
            badge(&p, &pal, pos2(rect.right() - 16.0, rect.center().y), &repo, Align2::RIGHT_CENTER);
        }
        if resp.clicked() {
            self.acts.push(Act::Show(u.name.clone()));
        }
    }

    // ---------------------------------------------------------------- sheet

    fn sheet_layer(&mut self, ctx: &egui::Context, full: Rect) {
        let Some(sheet) = self.sheet.as_ref() else { return };
        let opened = ease_out(sheet.opened.elapsed().as_secs_f32() / 0.32);
        let closing = sheet.closing.map(|c| ease_out(c.elapsed().as_secs_f32() / 0.24)).unwrap_or(0.0);
        if closing >= 1.0 {
            self.sheet = None;
            return;
        }
        let k = opened * (1.0 - closing);
        if k < 1.0 {
            ctx.request_repaint();
        }
        let name = sheet.name.clone();
        let pal = self.pal.clone();
        egui::Area::new(Id::new("sheet-layer"))
            .order(egui::Order::Foreground)
            .fixed_pos(full.min)
            .show(ctx, |ui| {
                ui.set_min_size(full.size());
                let scrim = ui.interact(full, Id::new("scrim"), Sense::click());
                ui.painter().rect_filled(full, CornerRadius::ZERO, Color32::from_black_alpha((110.0 * k) as u8));
                let w = (full.width() * 0.56).clamp(520.0, 680.0);
                let x = full.right() - w * k;
                let r = Rect::from_min_size(pos2(x, full.top()), vec2(w, full.height()));
                let p = ui.painter().clone();
                shadow(&p, r, 0.0, k);
                p.rect_filled(r, CornerRadius::ZERO, mix(pal.bg, pal.pill, 0.25));
                glow(&p, pos2(r.left() + w * 0.3, r.top()), 420.0, alpha(pal.accent, 0.10));
                p.line_segment([r.left_top(), r.left_bottom()], Stroke::new(1.0, pal.line()));
                if scrim.clicked() {
                    self.acts.push(Act::Close);
                }
                ui.scope_builder(UiBuilder::new().max_rect(r).id_salt("sheet"), |ui| {
                    ui.set_clip_rect(r);
                    self.sheet_body(ui, r, &name);
                });
            });
    }

    fn sheet_body(&mut self, ui: &mut Ui, r: Rect, name: &str) {
        let pal = self.pal.clone();
        let close = Rect::from_min_size(r.min + vec2(20.0, 18.0), vec2(36.0, 36.0));
        let cr = ui.interact(close, Id::new("sheet-close"), Sense::click());
        let p = ui.painter().clone();
        p.circle_filled(close.center(), 18.0, alpha(pal.text, if cr.hovered() { 0.12 } else { 0.06 }));
        glyph(&p, close.shrink(10.0), Glyph::Back, pal.text);
        if cr.clicked() {
            self.acts.push(Act::Close);
        }
        let Some(it) = self.item(name) else {
            p.text(r.center(), Align2::CENTER_CENTER, t("Loading"), body(14.0), pal.muted);
            return;
        };
        let app = self.cat.app(name).cloned();
        let body_rect = Rect::from_min_max(pos2(r.left(), close.bottom() + 6.0), r.max);
        let time = ui.input(|i| i.time);
        ui.scope_builder(UiBuilder::new().max_rect(body_rect), |ui| {
            egui::ScrollArea::vertical()
                .id_salt(("sheet-scroll", name))
                .auto_shrink([false, false])
                .content_margin(egui::Margin { left: 36, right: 36, top: 6, bottom: 90 })
                .show(ui, |ui| {
                    let w = ui.available_width();
                    // header
                    let (hr, _) = ui.allocate_exact_size(vec2(w, 108.0), Sense::hover());
                    let icon_r = Rect::from_min_size(hr.min, vec2(96.0, 96.0));
                    let tex = self.icon(name);
                    let p = ui.painter().clone();
                    avatar(ui, &pal, icon_r, tex.as_ref(), &it.title);
                    let x = icon_r.right() + 20.0;
                    p.text(pos2(x, hr.top() + 6.0), Align2::LEFT_TOP, elide(ui, &it.title, display(26.0), w - 120.0), display(26.0), pal.text);
                    let ng = p.layout_no_wrap(it.name.clone(), mono(13.0), pal.muted);
                    let nw = ng.size().x;
                    p.galley(pos2(x, hr.top() + 48.0), ng, pal.muted);
                    let b = badge(&p, &pal, pos2(x + nw + 10.0, hr.top() + 46.0), &it.repo, Align2::LEFT_TOP);
                    if let Some(pk) = self.aur.get(name).filter(|p| p.out_of_date) {
                        let _ = pk;
                        p.text(pos2(b.right() + 10.0, b.center().y), Align2::LEFT_CENTER, t("marked out of date"), body(12.0), pal.error);
                    }
                    ui.add_space(2.0);
                    ui.horizontal(|ui| {
                        self.action_buttons(ui, &it, 42.0, "sheet");
                        let url = match self.details.get(name) {
                            Some(Detail::Ready(d)) => d.url.clone(),
                            _ => None,
                        }
                        .or_else(|| app.as_ref().and_then(|a| a.homepage.clone()));
                        if let Some(u) = url {
                            if button(ui, &pal, Id::new(("site", name)), t("Website"), Some(Glyph::Link), Btn::Ghost, 42.0).clicked() {
                                self.acts.push(Act::Url(u));
                            }
                        }
                        if it.repo == "aur" && button(ui, &pal, Id::new(("aurpage", name)), "AUR", Some(Glyph::Open), Btn::Ghost, 42.0).clicked() {
                            self.acts.push(Act::Url(format!("https://aur.archlinux.org/packages/{name}")));
                        }
                    });
                    if let Some(job) = self.job_for(name) {
                        ui.add_space(4.0);
                        let (jr, _) = ui.allocate_exact_size(vec2(w, 24.0), Sense::hover());
                        let stage = if job.stage.is_empty() { t("Starting").to_string() } else { job.stage.clone() };
                        ui.painter().text(jr.left_center(), Align2::LEFT_CENTER, elide(ui, &stage, mono(12.0), w), mono(12.0), pal.muted);
                    }
                    if it.repo == "aur" {
                        ui.add_space(8.0);
                        let g = wrap_galley(ui, t("AUR packages are written by users and built on this computer. Read the PKGBUILD on the AUR page if you do not know the author."), body(12.5), pal.text, w - 56.0, 4);
                        let h = g.size().y + 24.0;
                        let (nr, _) = ui.allocate_exact_size(vec2(w, h), Sense::hover());
                        let warm = pal.source("aur");
                        let p = ui.painter();
                        p.rect_filled(nr, CornerRadius::same(14), alpha(warm, 0.10));
                        glyph(p, Rect::from_min_size(nr.min + vec2(14.0, 13.0), vec2(18.0, 18.0)), Glyph::Alert, warm);
                        p.galley(nr.min + vec2(42.0, 12.0), g, pal.text);
                    }
                    // screenshots
                    if let Some(a) = &app {
                        if !a.screenshots.is_empty() {
                            ui.add_space(14.0);
                            let sh = 230.0;
                            egui::ScrollArea::horizontal().id_salt(("shots", name)).auto_shrink([false, true]).show(ui, |ui| {
                                ui.horizontal(|ui| {
                                    for (i, url) in a.screenshots.iter().enumerate() {
                                        let key = format!("shot:{url}");
                                        let u = url.clone();
                                        let tex = self.icons.get(&key, || Some(Src::Url(u)));
                                        let size = tex.as_ref().map(|t| {
                                            let s = t.size_vec2();
                                            vec2(sh * s.x / s.y.max(1.0), sh)
                                        });
                                        let waiting = self.icons.waiting(&key);
                                        if tex.is_none() && !waiting {
                                            continue;
                                        }
                                        let (sr, resp) = ui.allocate_exact_size(size.unwrap_or(vec2(sh * 1.6, sh)).min(vec2(sh * 2.2, sh)), Sense::click());
                                        let p = ui.painter();
                                        p.rect_filled(sr, CornerRadius::same(14), alpha(pal.text, 0.05));
                                        match tex {
                                            Some(t) => egui::Image::new(&t).corner_radius(CornerRadius::same(14)).paint_at(ui, sr),
                                            None => spinner(p, sr.center(), 10.0, pal.muted, time),
                                        }
                                        if resp.clicked() {
                                            self.acts.push(Act::Url(url.clone()));
                                        }
                                        let _ = i;
                                    }
                                });
                            });
                        }
                    }
                    // description
                    ui.add_space(16.0);
                    let paras: Vec<String> = match &app {
                        Some(a) if !a.description.is_empty() => a.description.clone(),
                        _ => match self.details.get(name) {
                            Some(Detail::Ready(d)) if !d.desc.is_empty() => vec![d.desc.clone()],
                            _ => vec![it.summary.clone()],
                        },
                    };
                    for para in paras.iter().take(12) {
                        let g = wrap_galley(ui, para, body(14.5), pal.text, w, 40);
                        let (pr, _) = ui.allocate_exact_size(g.size(), Sense::hover());
                        ui.painter().galley(pr.min, g, pal.text);
                        ui.add_space(4.0);
                    }
                    // facts
                    ui.add_space(14.0);
                    let mut facts: Vec<(&str, String)> = Vec::new();
                    let det = self.details.get(name);
                    match det {
                        Some(Detail::Ready(d)) => {
                            facts.push(("Version", if d.version.is_empty() { it.version.clone() } else { d.version.clone() }));
                            if let Some(l) = self.local.get(name) {
                                if l.version != d.version && !d.version.is_empty() {
                                    facts.push(("Installed version", l.version.clone()));
                                }
                            }
                            facts.push(("Source", if it.repo.starts_with("cachyos") { format!("CachyOS · {}", it.repo) } else { repo_label(&it.repo) }));
                            if let Some(pk) = self.cat.get(name) {
                                if pk.download > 0 {
                                    facts.push(("Download", human_size(pk.download)));
                                }
                                if pk.size > 0 {
                                    facts.push(("Installed size", human_size(pk.size)));
                                }
                            } else if !d.size.is_empty() {
                                facts.push(("Installed size", d.size.clone()));
                            }
                            if !d.licenses.is_empty() {
                                facts.push(("License", d.licenses.clone()));
                            }
                            if let Some(pk) = self.aur.get(name).filter(|_| it.repo == "aur") {
                                facts.push(("Votes", pk.votes.to_string()));
                                facts.push(("Popularity", format!("{:.2}", pk.popularity)));
                                facts.push(("Maintainer", pk.maintainer.clone().unwrap_or_else(|| t("nobody").into())));
                                if !d.built.is_empty() {
                                    facts.push(("Last updated", d.built.clone()));
                                }
                            } else {
                                if !d.packager.is_empty() {
                                    facts.push(("Packager", d.packager.split('<').next().unwrap_or("").trim().to_string()));
                                }
                                if !d.built.is_empty() {
                                    facts.push(("Built", d.built.clone()));
                                }
                            }
                            if !d.installed_on.is_empty() {
                                facts.push(("Installed on", d.installed_on.clone()));
                            }
                        }
                        Some(Detail::Failed(e)) => facts.push(("Details", e.clone())),
                        _ => {
                            let (lr, _) = ui.allocate_exact_size(vec2(w, 40.0), Sense::hover());
                            spinner(ui.painter(), lr.center(), 10.0, pal.accent, time);
                            ui.ctx().request_repaint();
                        }
                    }
                    if !facts.is_empty() {
                        let cols = 2;
                        let cw = (w - 12.0) / cols as f32;
                        let rows = facts.len().div_ceil(cols);
                        let (fr, _) = ui.allocate_exact_size(vec2(w, rows as f32 * 62.0), Sense::hover());
                        let p = ui.painter();
                        for (i, (k, v)) in facts.iter().enumerate() {
                            let cell = Rect::from_min_size(fr.min + vec2((i % cols) as f32 * (cw + 12.0), (i / cols) as f32 * 62.0), vec2(cw, 54.0));
                            p.rect_filled(cell, CornerRadius::same(14), alpha(pal.text, 0.04));
                            p.text(cell.min + vec2(14.0, 10.0), Align2::LEFT_TOP, t(k), body(11.5), pal.muted);
                            p.text(cell.min + vec2(14.0, 28.0), Align2::LEFT_TOP, elide(ui, v, semi(13.5), cw - 28.0), semi(13.5), pal.text);
                        }
                    }
                    if let Some(Detail::Ready(d)) = self.details.get(name) {
                        let deps = d.depends.clone();
                        let opt = d.optional.clone();
                        if !deps.is_empty() {
                            ui.add_space(14.0);
                            ui.label(egui::RichText::new(t("Depends on")).font(semi(14.0)).color(pal.text));
                            ui.horizontal_wrapped(|ui| {
                                ui.spacing_mut().item_spacing = vec2(6.0, 6.0);
                                for dep in deps {
                                    let base = dep.split(['<', '>', '=', ' ']).next().unwrap_or("").to_string();
                                    let have = self.local.contains_key(&base);
                                    let g = ui.painter().layout_no_wrap(dep.clone(), mono(12.0), pal.text);
                                    let (cr, resp) = ui.allocate_exact_size(g.size() + vec2(18.0, 10.0), Sense::click());
                                    let p = ui.painter();
                                    p.rect_filled(cr, CornerRadius::same(9), alpha(if have { pal.good } else { pal.text }, if resp.hovered() { 0.14 } else { 0.07 }));
                                    p.galley(cr.center() - g.size() / 2.0, g, pal.text);
                                    if resp.clicked() && (self.cat.index.contains_key(&base) || self.local.contains_key(&base)) {
                                        self.acts.push(Act::Show(base));
                                    }
                                }
                            });
                        }
                        if !opt.is_empty() {
                            ui.add_space(14.0);
                            ui.label(egui::RichText::new(t("Optional")).font(semi(14.0)).color(pal.text));
                            for o in opt.iter().take(30) {
                                ui.label(egui::RichText::new(o).font(mono(12.0)).color(pal.muted));
                            }
                        }
                    }
                });
        });
    }

    // ---------------------------------------------------------------- jobs

    fn jobs_layer(&mut self, ctx: &egui::Context, full: Rect) {
        let shown: Vec<Job> = self
            .job_list
            .iter()
            .filter(|j| j.active() || (!j.seen && j.ended.map(|e| e.elapsed() < Duration::from_secs(if matches!(j.state, State::Failed(_)) { 30 } else { 6 })).unwrap_or(false)))
            .cloned()
            .collect();
        let any = !shown.is_empty();
        let k = ctx.animate_bool_with_time(Id::new("dock"), any, 0.25);
        if k <= 0.0 {
            self.log_open = false;
            return;
        }
        if !shown.is_empty() {
            ctx.data_mut(|d| d.insert_temp(Id::new("dock-last"), shown.clone()));
        }
        let shown: Vec<Job> = if shown.is_empty() { ctx.data(|d| d.get_temp(Id::new("dock-last"))).unwrap_or_default() } else { shown };
        let Some(job) = shown.iter().find(|j| j.active()).or(shown.last()).cloned() else { return };
        let queued = shown.iter().filter(|j| j.active()).count().saturating_sub(1);
        let pal = self.pal.clone();
        let w = 400.0;
        let h = if self.log_open {
            340.0
        } else if job.active() || matches!(job.state, State::Failed(_)) || queued > 0 {
            104.0
        } else {
            68.0
        };
        let hh = ctx.animate_value_with_time(Id::new("dock-h"), h, 0.22);
        let r = Rect::from_min_size(pos2(full.right() - w - 24.0, full.bottom() - hh - 24.0 + (1.0 - ease_out(k)) * 40.0), vec2(w, hh));
        let time = ctx.input(|i| i.time);
        egui::Area::new(Id::new("dock-area")).order(egui::Order::Tooltip).fixed_pos(r.min).show(ctx, |ui| {
            ui.set_min_size(r.size());
            ui.multiply_opacity(k);
            let p = ui.painter().clone();
            shadow(&p, r, 22.0, 1.0);
            p.rect_filled(r, CornerRadius::same(22), mix(pal.bg, pal.pill, 0.3));
            p.rect_stroke(r, CornerRadius::same(22), Stroke::new(1.0, alpha(pal.text, 0.10)), StrokeKind::Inside);
            let (title, color, g) = match (&job.state, job.kind) {
                (State::Done, _) => (
                    match job.kind {
                        Kind::Install => tf("{} installed", &job.pkgs.join(", ")),
                        Kind::Remove => tf("{} removed", &job.pkgs.join(", ")),
                        Kind::Upgrade => t("The system is up to date").into(),
                    },
                    pal.good,
                    Some(Glyph::Check),
                ),
                (State::Failed(_), _) => (t("It did not work").into(), pal.error, Some(Glyph::Alert)),
                (State::Cancelled, _) => (t("Cancelled").into(), pal.muted, Some(Glyph::Close)),
                (_, Kind::Install) => (tf("Installing {}", &job.pkgs.join(", ")), pal.accent, None),
                (_, Kind::Remove) => (tf("Removing {}", &job.pkgs.join(", ")), pal.accent, None),
                (_, Kind::Upgrade) => (t("Updating the system").into(), pal.accent, None),
            };
            let ic = pos2(r.left() + 34.0, r.top() + 34.0);
            p.circle_filled(ic, 18.0, alpha(color, 0.16));
            match g {
                Some(g) => glyph(&p, Rect::from_center_size(ic, vec2(18.0, 18.0)), g, color),
                None => spinner(&p, ic, 9.0, color, time),
            }
            p.text(pos2(r.left() + 62.0, r.top() + 18.0), Align2::LEFT_TOP, elide(ui, &title, semi(14.5), w - 150.0), semi(14.5), pal.text);
            let sub = match &job.state {
                State::Failed(e) => e.clone(),
                State::Waiting => t("Another package manager is running").into(),
                State::Queued => t("Queued").into(),
                State::Running if job.stage.is_empty() => {
                    if job.kind == Kind::Install && job.aur { t("Building from the AUR").into() } else { t("Waiting for the password").into() }
                }
                State::Running => job.stage.clone(),
                _ => String::new(),
            };
            p.text(pos2(r.left() + 62.0, r.top() + 39.0), Align2::LEFT_TOP, elide(ui, &sub, body(12.5), w - 90.0), body(12.5), if matches!(job.state, State::Failed(_)) { pal.error } else { pal.muted });
            if job.active() {
                progress(&p, &pal, Rect::from_min_size(pos2(r.left() + 62.0, r.top() + 66.0), vec2(w - 90.0, 4.0)), job.progress, time);
            }
            if queued > 0 {
                p.text(pos2(r.left() + 62.0, r.top() + 80.0), Align2::LEFT_TOP, tf("{} more in the queue", &queued.to_string()), body(11.5), pal.muted);
            }
            // buttons: log, close
            let lb = Rect::from_min_size(pos2(r.right() - 84.0, r.top() + 14.0), vec2(36.0, 32.0));
            let lr = ui.interact(lb, Id::new("dock-log"), Sense::click());
            p.rect_filled(lb, CornerRadius::same(10), alpha(pal.text, if lr.hovered() || self.log_open { 0.12 } else { 0.05 }));
            glyph(&p, lb.shrink2(vec2(10.0, 8.0)), Glyph::Terminal, pal.text);
            if lr.clicked() {
                self.log_open = !self.log_open;
            }
            if !job.active() {
                let cb = Rect::from_min_size(pos2(r.right() - 44.0, r.top() + 14.0), vec2(32.0, 32.0));
                let cr = ui.interact(cb, Id::new("dock-x"), Sense::click());
                p.rect_filled(cb, CornerRadius::same(10), alpha(pal.text, if cr.hovered() { 0.12 } else { 0.05 }));
                glyph(&p, cb.shrink(10.0), Glyph::Close, pal.text);
                if cr.clicked() {
                    self.jobs.mark_seen();
                    self.log_open = false;
                }
            }
            if self.log_open && hh > 150.0 {
                let lr = Rect::from_min_max(pos2(r.left() + 14.0, r.top() + 104.0), pos2(r.right() - 14.0, r.bottom() - 14.0));
                p.rect_filled(lr, CornerRadius::same(12), alpha(Color32::BLACK, 0.28));
                ui.scope_builder(UiBuilder::new().max_rect(lr.shrink(10.0)), |ui| {
                    egui::ScrollArea::vertical().id_salt("log").stick_to_bottom(true).auto_shrink([false, false]).show(ui, |ui| {
                        ui.spacing_mut().item_spacing.y = 1.0;
                        if job.log.is_empty() {
                            ui.label(egui::RichText::new(t("No output yet")).font(mono(11.5)).color(pal.muted));
                        }
                        for l in job.log.iter().rev().take(400).rev() {
                            ui.label(egui::RichText::new(l).font(mono(11.5)).color(alpha(pal.text, 0.85)));
                        }
                    });
                });
            }
        });
    }

    fn toast_layer(&mut self, ctx: &egui::Context, full: Rect) {
        let Some((text, at, ok)) = self.toast.clone() else { return };
        let age = at.elapsed().as_secs_f32();
        if age > 4.0 {
            self.toast = None;
            return;
        }
        let k = ease_out(age / 0.25) * (1.0 - ease_out((age - 3.6) / 0.4).max(0.0));
        ctx.request_repaint();
        let pal = self.pal.clone();
        egui::Area::new(Id::new("toast")).order(egui::Order::Tooltip).fixed_pos(full.min).interactable(false).show(ctx, |ui| {
            let p = ui.painter();
            let g = p.layout_no_wrap(text.clone(), semi(13.5), pal.text);
            let w = g.size().x + 64.0;
            let r = Rect::from_center_size(pos2(full.center().x + 126.0, full.top() + 48.0 + (1.0 - k) * -20.0), vec2(w, 40.0));
            let c = if ok { pal.good } else { pal.error };
            shadow(p, r, 20.0, k);
            p.rect_filled(r, CornerRadius::same(20), alpha(mix(pal.bg, pal.pill, 0.4), k));
            p.rect_stroke(r, CornerRadius::same(20), Stroke::new(1.0, alpha(c, 0.4 * k)), StrokeKind::Inside);
            glyph(p, Rect::from_center_size(pos2(r.left() + 22.0, r.center().y), vec2(16.0, 16.0)), if ok { Glyph::Check } else { Glyph::Alert }, alpha(c, k));
            p.galley(pos2(r.left() + 40.0, r.center().y - g.size().y / 2.0), g, alpha(pal.text, k));
        });
    }
}

fn group(n: usize) -> String {
    let s = n.to_string();
    let mut out = String::new();
    for (i, ch) in s.chars().enumerate() {
        if i > 0 && (s.len() - i) % 3 == 0 {
            out.push('\u{202F}');
        }
        out.push(ch);
    }
    out
}

