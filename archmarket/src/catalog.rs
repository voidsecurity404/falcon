//! What can be installed and what is installed, read from pacman's own
//! databases through `expac` (or `pacman` when expac is missing).

use crate::appstream::AppMeta;
use std::collections::{HashMap, HashSet};
use std::process::Command;

#[derive(Clone, Debug, Default)]
pub struct Pkg {
    pub name: String,
    pub version: String,
    pub desc: String,
    /// `core`, `extra`, `multilib`, a CachyOS repository, `aur`, or `local`
    /// for a package installed from a file.
    pub repo: String,
    pub download: u64,
    pub size: u64,
    pub votes: u32,
    pub popularity: f32,
    pub maintainer: Option<String>,
    pub out_of_date: bool,
    pub lname: String,
    pub ldesc: String,
}

impl Pkg {
    pub fn aur(&self) -> bool {
        self.repo == "aur"
    }

    pub fn finish(mut self) -> Pkg {
        self.lname = self.name.to_lowercase();
        self.ldesc = self.desc.to_lowercase();
        self
    }
}

#[derive(Clone, Debug)]
pub struct Local {
    pub version: String,
    pub explicit: bool,
    pub foreign: bool,
    pub size: u64,
    pub desc: String,
}

#[derive(Default)]
pub struct Catalog {
    pub repo: Vec<Pkg>,
    pub index: HashMap<String, usize>,
    pub apps: HashMap<String, AppMeta>,
}

impl Catalog {
    pub fn get(&self, name: &str) -> Option<&Pkg> {
        self.index.get(name).map(|&i| &self.repo[i])
    }

    pub fn app(&self, name: &str) -> Option<&AppMeta> {
        self.apps.get(name)
    }
}

fn run(cmd: &str, args: &[&str]) -> Option<String> {
    let out = Command::new(cmd).args(args).env("LC_ALL", "C").output().ok()?;
    if !out.status.success() && out.stdout.is_empty() {
        return None;
    }
    Some(String::from_utf8_lossy(&out.stdout).into_owned())
}

pub fn have(cmd: &str) -> bool {
    std::env::var_os("PATH")
        .map(|p| std::env::split_paths(&p).any(|d| d.join(cmd).is_file()))
        .unwrap_or(false)
}

/// Every package of the sync databases, first repository wins, in
/// pacman.conf order, as pacman itself does.
pub fn load_repo() -> (Vec<Pkg>, HashMap<String, usize>) {
    let mut list = Vec::with_capacity(26000);
    let mut index = HashMap::with_capacity(26000);
    let text = if have("expac") {
        run("expac", &["-S", "%r\t%n\t%v\t%k\t%m\t%d"]).unwrap_or_default()
    } else {
        String::new()
    };
    if !text.is_empty() {
        for line in text.lines() {
            let mut f = line.splitn(6, '\t');
            let (Some(repo), Some(name), Some(version), Some(dl), Some(size), desc) =
                (f.next(), f.next(), f.next(), f.next(), f.next(), f.next())
            else {
                continue;
            };
            if index.contains_key(name) {
                continue;
            }
            index.insert(name.to_string(), list.len());
            list.push(
                Pkg {
                    name: name.into(),
                    version: version.into(),
                    desc: desc.unwrap_or("").into(),
                    repo: repo.into(),
                    download: dl.parse().unwrap_or(0),
                    size: size.parse().unwrap_or(0),
                    ..Default::default()
                }
                .finish(),
            );
        }
    } else if let Some(text) = run("pacman", &["-Sl"]) {
        // No expac: names and versions only, descriptions come with details.
        for line in text.lines() {
            let mut f = line.split_whitespace();
            let (Some(repo), Some(name), Some(version)) = (f.next(), f.next(), f.next()) else {
                continue;
            };
            if index.contains_key(name) {
                continue;
            }
            index.insert(name.to_string(), list.len());
            list.push(
                Pkg { name: name.into(), version: version.into(), repo: repo.into(), ..Default::default() }
                    .finish(),
            );
        }
    }
    (list, index)
}

pub fn load_local() -> HashMap<String, Local> {
    let mut out = HashMap::new();
    let foreign: HashSet<String> = run("pacman", &["-Qqm"])
        .unwrap_or_default()
        .lines()
        .map(str::to_string)
        .collect();
    if have("expac") {
        for line in run("expac", &["-Q", "%n\t%v\t%w\t%m\t%d"]).unwrap_or_default().lines() {
            let mut f = line.splitn(5, '\t');
            let (Some(name), Some(version), Some(reason), Some(size)) = (f.next(), f.next(), f.next(), f.next())
            else {
                continue;
            };
            out.insert(
                name.to_string(),
                Local {
                    version: version.into(),
                    explicit: reason == "explicit",
                    foreign: foreign.contains(name),
                    size: size.parse().unwrap_or(0),
                    desc: f.next().unwrap_or("").into(),
                },
            );
        }
    } else {
        let explicit: HashSet<String> =
            run("pacman", &["-Qqe"]).unwrap_or_default().lines().map(str::to_string).collect();
        for line in run("pacman", &["-Q"]).unwrap_or_default().lines() {
            let mut f = line.split_whitespace();
            if let (Some(name), Some(version)) = (f.next(), f.next()) {
                out.insert(
                    name.to_string(),
                    Local {
                        version: version.into(),
                        explicit: explicit.contains(name),
                        foreign: foreign.contains(name),
                        size: 0,
                        desc: String::new(),
                    },
                );
            }
        }
    }
    out
}

#[derive(Clone, Debug)]
pub struct Update {
    pub name: String,
    pub old: String,
    pub new: String,
    pub aur: bool,
}

fn parse_updates(text: &str, aur: bool, out: &mut Vec<Update>) {
    for line in text.lines() {
        let f: Vec<&str> = line.split_whitespace().collect();
        if f.len() >= 4 && f[2] == "->" {
            out.push(Update { name: f[0].into(), old: f[1].into(), new: f[3].into(), aur });
        }
    }
}

/// Waiting updates. `checkupdates` works on its own copy of the database,
/// so nothing here needs root or changes the system.
pub fn load_updates() -> Result<Vec<Update>, String> {
    let mut out = Vec::new();
    if have("checkupdates") {
        let o = Command::new("checkupdates")
            .env("LC_ALL", "C")
            .output()
            .map_err(|e| e.to_string())?;
        match o.status.code() {
            Some(0) => parse_updates(&String::from_utf8_lossy(&o.stdout), false, &mut out),
            Some(2) => {}
            _ => {
                let err = String::from_utf8_lossy(&o.stderr).trim().to_string();
                return Err(if err.is_empty() { "checkupdates failed".into() } else { err });
            }
        }
    } else {
        return Err("checkupdates is missing (pacman-contrib)".into());
    }
    if have("yay") {
        if let Ok(o) = Command::new("yay").args(["-Qua"]).env("LC_ALL", "C").output() {
            parse_updates(&String::from_utf8_lossy(&o.stdout), true, &mut out);
        }
    }
    out.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(out)
}

#[derive(Clone, Debug, Default)]
pub struct Details {
    pub url: Option<String>,
    pub licenses: String,
    pub depends: Vec<String>,
    pub optional: Vec<String>,
    pub packager: String,
    pub built: String,
    pub installed_on: String,
    pub desc: String,
    pub version: String,
    pub size: String,
}

/// `pacman -Si` (or `-Qi` for a package only installed locally), read in
/// the C locale so the keys are fixed.
pub fn repo_details(name: &str, local_only: bool) -> Result<Details, String> {
    let flag = if local_only { "-Qi" } else { "-Si" };
    let text = run("pacman", &[flag, name]).ok_or_else(|| "pacman failed".to_string())?;
    let mut fields: Vec<(String, String)> = Vec::new();
    for line in text.lines() {
        if line.trim().is_empty() {
            if !fields.is_empty() {
                break; // only the first repository's block
            }
            continue;
        }
        if line.starts_with(' ') {
            if let Some(last) = fields.last_mut() {
                last.1.push('\n');
                last.1.push_str(line.trim());
            }
            continue;
        }
        if let Some((k, v)) = line.split_once(" : ") {
            fields.push((k.trim().to_string(), v.trim().to_string()));
        }
    }
    if fields.is_empty() {
        return Err("no such package".into());
    }
    let get = |k: &str| fields.iter().find(|f| f.0 == k).map(|f| f.1.clone()).unwrap_or_default();
    let list = |v: String| -> Vec<String> {
        if v == "None" {
            Vec::new()
        } else {
            v.split_whitespace().map(str::to_string).collect()
        }
    };
    let optional: Vec<String> = {
        let v = get("Optional Deps");
        if v == "None" { Vec::new() } else { v.lines().map(|l| l.trim().to_string()).filter(|l| !l.is_empty()).collect() }
    };
    let url = get("URL");
    Ok(Details {
        url: if url.is_empty() || url == "None" { None } else { Some(url) },
        licenses: get("Licenses"),
        depends: list(get("Depends On")),
        optional,
        packager: get("Packager"),
        built: get("Build Date"),
        installed_on: get("Install Date"),
        desc: get("Description"),
        version: get("Version"),
        size: get("Installed Size"),
    })
}

pub fn human_size(bytes: u64) -> String {
    let b = bytes as f64;
    if b >= 1024.0 * 1024.0 * 1024.0 {
        format!("{:.1} GiB", b / 1024.0 / 1024.0 / 1024.0)
    } else if b >= 1024.0 * 1024.0 {
        format!("{:.1} MiB", b / 1024.0 / 1024.0)
    } else if b >= 1024.0 {
        format!("{:.0} KiB", b / 1024.0)
    } else {
        format!("{bytes} B")
    }
}

/// The `.desktop` file a package ships, used to open an installed app and
/// to find an icon for packages AppStream does not know.
pub fn desktop_entry(pkg: &str) -> Option<(String, Option<String>)> {
    let text = run("pacman", &["-Qlq", pkg])?;
    for path in text.lines() {
        if path.starts_with("/usr/share/applications/") && path.ends_with(".desktop") {
            let id = path.rsplit('/').next()?.to_string();
            let body = std::fs::read_to_string(path).unwrap_or_default();
            if body.lines().any(|l| l.trim() == "NoDisplay=true") {
                continue;
            }
            let icon = body
                .lines()
                .find_map(|l| l.strip_prefix("Icon="))
                .map(|s| s.trim().to_string());
            return Some((id, icon));
        }
    }
    None
}
