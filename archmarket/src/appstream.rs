//! AppStream: real app names, summaries, categories, icons and screenshots
//! for the official repositories. Uses `/usr/share/swcatalog` when the
//! `archlinux-appstream-data` package is installed, otherwise downloads that
//! same package once into the cache (no root needed) and refreshes it every
//! two weeks.

use crate::theme::home;
use std::collections::HashMap;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

#[derive(Clone, Debug, Default)]
pub struct AppMeta {
    pub id: String,
    pub name: String,
    pub summary: String,
    pub description: Vec<String>,
    pub categories: Vec<String>,
    pub keywords: Vec<String>,
    pub icon: Option<PathBuf>,
    pub stock_icon: Option<String>,
    pub homepage: Option<String>,
    pub screenshots: Vec<String>,
    pub lname: String,
}

fn cache_dir() -> PathBuf {
    std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".cache"))
        .join("archmarket")
}

fn system_root() -> Option<PathBuf> {
    let p = PathBuf::from("/usr/share/swcatalog");
    p.join("xml/extra.xml.gz").is_file().then_some(p)
}

fn cached_root() -> PathBuf {
    cache_dir().join("swcatalog")
}

fn fresh(path: &Path) -> bool {
    std::fs::metadata(path)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| SystemTime::now().duration_since(t).ok())
        .map(|age| age < Duration::from_secs(14 * 24 * 3600))
        .unwrap_or(false)
}

/// Where the catalog lives, downloading it when needed. `say` reports
/// progress for the loading screen.
pub fn locate(say: &dyn Fn(&str)) -> Option<PathBuf> {
    if let Some(p) = system_root() {
        return Some(p);
    }
    let root = cached_root();
    let stamp = root.join(".stamp");
    if root.join("xml/extra.xml.gz").is_file() && fresh(&stamp) {
        return Some(root);
    }
    say("Downloading app catalog");
    match download(&root) {
        Ok(()) => {
            let _ = std::fs::write(&stamp, b"");
            Some(root)
        }
        Err(e) => {
            eprintln!("archmarket: appstream download failed: {e}");
            root.join("xml/extra.xml.gz").is_file().then_some(root)
        }
    }
}

fn download(root: &Path) -> Result<(), String> {
    let out = std::process::Command::new("pacman")
        .args(["-Sp", "archlinux-appstream-data"])
        .env("LC_ALL", "C")
        .output()
        .map_err(|e| e.to_string())?;
    let url = String::from_utf8_lossy(&out.stdout)
        .lines()
        .find(|l| l.starts_with("http"))
        .ok_or("no mirror url")?
        .trim()
        .to_string();
    let agent = crate::aur::agent(120);
    let mut resp = agent.get(&url).call().map_err(|e| e.to_string())?;
    let body = resp.body_mut().as_reader();
    let zstd = ruzstd::decoding::StreamingDecoder::new(body).map_err(|e| e.to_string())?;
    let tmp = root.with_extension("new");
    let _ = std::fs::remove_dir_all(&tmp);
    std::fs::create_dir_all(&tmp).map_err(|e| e.to_string())?;
    let mut archive = tar::Archive::new(zstd);
    for entry in archive.entries().map_err(|e| e.to_string())? {
        let mut entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path().map_err(|e| e.to_string())?.into_owned();
        let Ok(rest) = path.strip_prefix("usr/share/swcatalog") else { continue };
        if rest.components().any(|c| !matches!(c, std::path::Component::Normal(_))) {
            continue;
        }
        let dest = tmp.join(rest);
        if entry.header().entry_type().is_dir() {
            std::fs::create_dir_all(&dest).map_err(|e| e.to_string())?;
        } else if entry.header().entry_type().is_file() {
            if let Some(parent) = dest.parent() {
                std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
            }
            let mut buf = Vec::new();
            entry.read_to_end(&mut buf).map_err(|e| e.to_string())?;
            std::fs::write(&dest, buf).map_err(|e| e.to_string())?;
        }
    }
    if !tmp.join("xml/extra.xml.gz").is_file() {
        return Err("package had no catalog".into());
    }
    let _ = std::fs::remove_dir_all(root);
    std::fs::rename(&tmp, root).map_err(|e| e.to_string())
}

pub fn load(root: &Path, ru: bool) -> HashMap<String, AppMeta> {
    let mut apps = HashMap::new();
    for repo in ["core", "extra", "multilib"] {
        let path = root.join(format!("xml/{repo}.xml.gz"));
        let Ok(file) = std::fs::File::open(&path) else { continue };
        let mut text = String::new();
        if flate2::read::GzDecoder::new(file).read_to_string(&mut text).is_ok() {
            parse(&text, root, ru, &mut apps);
        }
    }
    apps
}

fn attr<'a>(attrs: &'a str, key: &str) -> Option<&'a str> {
    let mut rest = attrs;
    while let Some(pos) = rest.find(key) {
        let after = &rest[pos + key.len()..];
        let before_ok = pos == 0 || rest.as_bytes()[pos - 1].is_ascii_whitespace();
        if before_ok {
            if let Some(v) = after.strip_prefix("=\"") {
                return v.split('"').next();
            }
        }
        rest = after;
    }
    None
}

pub fn decode(s: &str) -> String {
    if !s.contains('&') {
        return s.to_string();
    }
    let mut out = String::with_capacity(s.len());
    let mut rest = s;
    while let Some(p) = rest.find('&') {
        out.push_str(&rest[..p]);
        rest = &rest[p..];
        let Some(end) = rest.find(';') else { break };
        let ent = &rest[1..end];
        let ch = match ent {
            "amp" => Some('&'),
            "lt" => Some('<'),
            "gt" => Some('>'),
            "quot" => Some('"'),
            "apos" => Some('\''),
            e if e.starts_with("#x") => u32::from_str_radix(&e[2..], 16).ok().and_then(char::from_u32),
            e if e.starts_with('#') => e[1..].parse().ok().and_then(char::from_u32),
            _ => None,
        };
        match ch {
            Some(c) => out.push(c),
            None => out.push_str(&rest[..=end]),
        }
        rest = &rest[end + 1..];
    }
    out.push_str(rest);
    out
}

#[derive(Default)]
struct Comp {
    kind: String,
    id: String,
    pkg: String,
    name: String,
    name_ru: String,
    summary: String,
    summary_ru: String,
    desc: Vec<String>,
    desc_ru: Vec<String>,
    categories: Vec<String>,
    keywords: Vec<String>,
    icon: Option<(u32, String)>,
    stock: Option<String>,
    homepage: Option<String>,
    shots: Vec<String>,
}

/// A small reader for the AppStream catalog. The format is regular, so this
/// keeps the parsing in our hands and needs no XML library.
fn parse(xml: &str, root: &Path, ru: bool, out: &mut HashMap<String, AppMeta>) {
    let mut origin = String::new();
    let mut stack: Vec<String> = Vec::new();
    let mut desc_lang: Option<String> = None;
    let mut cur: Option<Comp> = None;
    let mut i = 0usize;
    while let Some(lt) = xml[i..].find('<') {
        let s = i + lt;
        let Some(gt) = xml[s..].find('>') else { break };
        let tag = &xml[s + 1..s + gt];
        i = s + gt + 1;
        if tag.starts_with('?') || tag.starts_with('!') {
            continue;
        }
        if let Some(name) = tag.strip_prefix('/') {
            let name = name.trim();
            if let Some(pos) = stack.iter().rposition(|t| t == name) {
                stack.truncate(pos);
            }
            match name {
                "component" => {
                    if let Some(c) = cur.take() {
                        finish(c, root, &origin, ru, out);
                    }
                }
                "description" => desc_lang = None,
                _ => {}
            }
            continue;
        }
        let self_closing = tag.ends_with('/');
        let tag = tag.trim_end_matches('/');
        let (name, attrs) = match tag.find(char::is_whitespace) {
            Some(p) => (&tag[..p], &tag[p..]),
            None => (tag, ""),
        };
        let parent = stack.last().map(String::as_str).unwrap_or("");
        let lang = attr(attrs, "xml:lang");
        let text_end = xml[i..].find('<').map(|p| i + p).unwrap_or(xml.len());
        let text = || decode(xml[i..text_end].trim());
        match name {
            "components" => origin = attr(attrs, "origin").unwrap_or("").to_string(),
            "component" => {
                cur = Some(Comp { kind: attr(attrs, "type").unwrap_or("").to_string(), ..Default::default() })
            }
            "description" => desc_lang = Some(lang.unwrap_or("").to_string()),
            _ => {}
        }
        if let Some(c) = cur.as_mut() {
            match (name, parent) {
                ("id", "component") => c.id = text(),
                ("pkgname", "component") => c.pkg = text(),
                ("name", "component") => match lang {
                    None => c.name = text(),
                    Some("ru") => c.name_ru = text(),
                    _ => {}
                },
                ("summary", "component") => match lang {
                    None => c.summary = text(),
                    Some("ru") => c.summary_ru = text(),
                    _ => {}
                },
                ("p" | "li", _) => {
                    let mut t = text().split_whitespace().collect::<Vec<_>>().join(" ");
                    if name == "li" {
                        t = format!("•  {t}");
                    }
                    match desc_lang.as_deref() {
                        Some("") if lang.is_none() => c.desc.push(t),
                        Some("ru") => c.desc_ru.push(t),
                        _ if lang == Some("ru") && desc_lang.is_some() => c.desc_ru.push(t),
                        _ => {}
                    }
                }
                ("category", "categories") => c.categories.push(text()),
                ("keyword", "keywords") if lang.is_none() || lang == Some("ru") => {
                    c.keywords.push(text().to_lowercase())
                }
                ("icon", "component") => match attr(attrs, "type") {
                    Some("cached") => {
                        let w: u32 = attr(attrs, "width").and_then(|v| v.parse().ok()).unwrap_or(0);
                        if c.icon.as_ref().map(|i| w > i.0).unwrap_or(true) {
                            c.icon = Some((w, text()));
                        }
                    }
                    Some("stock") => c.stock = Some(text()),
                    _ => {}
                },
                ("url", "component") if attr(attrs, "type") == Some("homepage") => c.homepage = Some(text()),
                ("image", "screenshot") => {
                    if attr(attrs, "type") == Some("source") && c.shots.len() < 4 {
                        let t = text();
                        if t.starts_with("http") {
                            c.shots.push(t);
                        }
                    }
                }
                _ => {}
            }
        }
        if !self_closing {
            stack.push(name.to_string());
        }
    }
}

fn finish(c: Comp, root: &Path, origin: &str, ru: bool, out: &mut HashMap<String, AppMeta>) {
    if c.pkg.is_empty() || !(c.kind == "desktop-application" || c.kind == "desktop" || c.kind == "console-application") {
        return;
    }
    // A package can ship several apps (plan9port, libreoffice). Keep the one
    // whose id names the package, else the first.
    if let Some(old) = out.get(&c.pkg) {
        let pkg = c.pkg.to_lowercase();
        let new_better = c.id.to_lowercase().contains(&pkg) && !old.id.to_lowercase().contains(&pkg);
        if !new_better {
            return;
        }
    }
    let icon = c.icon.and_then(|(w, file)| {
        let dir = root.join("icons").join(origin);
        let sizes = match w {
            128.. => ["128x128", "64x64", "48x48"],
            64.. => ["64x64", "128x128", "48x48"],
            _ => ["48x48", "64x64", "128x128"],
        };
        sizes.iter().map(|s| dir.join(s).join(&file)).find(|p| p.is_file())
    });
    let pick = |ru_v: String, v: String| if ru && !ru_v.is_empty() { ru_v } else { v };
    let name = pick(c.name_ru, c.name);
    let summary = pick(c.summary_ru, c.summary);
    let description = if ru && !c.desc_ru.is_empty() { c.desc_ru } else { c.desc };
    let lname = name.to_lowercase();
    out.insert(
        c.pkg,
        AppMeta {
            id: c.id,
            name,
            summary,
            description,
            categories: c.categories,
            keywords: c.keywords,
            icon,
            stock_icon: c.stock,
            homepage: c.homepage,
            screenshots: c.shots,
            lname,
        },
    );
}
