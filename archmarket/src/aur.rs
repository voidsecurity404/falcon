//! The AUR, through its public RPC interface (v5).

use crate::catalog::{Details, Pkg};
use serde_json::Value;
use std::time::Duration;

pub fn agent(secs: u64) -> ureq::Agent {
    ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(secs)))
        .user_agent("archmarket/1.0")
        .build()
        .into()
}

fn encode(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => out.push(b as char),
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn get(url: &str) -> Result<Value, String> {
    let mut resp = agent(15).get(url).call().map_err(|e| match e {
        ureq::Error::StatusCode(c) => format!("AUR answered {c}"),
        ureq::Error::Io(_) | ureq::Error::HostNotFound | ureq::Error::ConnectionFailed => "offline".into(),
        e => e.to_string(),
    })?;
    let v: Value = resp.body_mut().read_json().map_err(|e| e.to_string())?;
    if v["type"] == "error" {
        return Err(v["error"].as_str().unwrap_or("AUR error").to_string());
    }
    Ok(v)
}

fn pkg_of(r: &Value) -> Pkg {
    Pkg {
        name: r["Name"].as_str().unwrap_or("").into(),
        version: r["Version"].as_str().unwrap_or("").into(),
        desc: r["Description"].as_str().unwrap_or("").into(),
        repo: "aur".into(),
        votes: r["NumVotes"].as_u64().unwrap_or(0) as u32,
        popularity: r["Popularity"].as_f64().unwrap_or(0.0) as f32,
        maintainer: r["Maintainer"].as_str().map(str::to_string),
        out_of_date: !r["OutOfDate"].is_null(),
        ..Default::default()
    }
    .finish()
}

/// Search names and descriptions. A very broad word makes the AUR refuse
/// ("Too many package results"), so it falls back to names only.
pub fn search(query: &str) -> Result<Vec<Pkg>, String> {
    let q = encode(query.trim());
    let v = match get(&format!("https://aur.archlinux.org/rpc/v5/search/{q}?by=name-desc")) {
        Ok(v) => v,
        Err(e) if e.contains("Too many") => get(&format!("https://aur.archlinux.org/rpc/v5/search/{q}?by=name"))?,
        Err(e) => return Err(e),
    };
    let mut list: Vec<Pkg> = v["results"].as_array().into_iter().flatten().map(pkg_of).collect();
    list.sort_by(|a, b| b.popularity.partial_cmp(&a.popularity).unwrap_or(std::cmp::Ordering::Equal));
    Ok(list)
}

pub fn info_many(names: &[&str]) -> Result<Vec<Pkg>, String> {
    let args: String = names.iter().map(|n| format!("arg[]={}&", encode(n))).collect();
    let v = get(&format!("https://aur.archlinux.org/rpc/v5/info?{args}"))?;
    Ok(v["results"].as_array().into_iter().flatten().map(pkg_of).collect())
}

pub fn details(name: &str) -> Result<(Pkg, Details), String> {
    let v = get(&format!("https://aur.archlinux.org/rpc/v5/info?arg[]={}", encode(name)))?;
    let r = v["results"].get(0).ok_or_else(|| "not in the AUR".to_string())?;
    let list = |k: &str| -> Vec<String> {
        r[k].as_array().into_iter().flatten().filter_map(|x| x.as_str().map(str::to_string)).collect()
    };
    let mut depends = list("Depends");
    for m in list("MakeDepends") {
        depends.push(format!("{m} (make)"));
    }
    let date = |k: &str| r[k].as_i64().map(fmt_date).unwrap_or_default();
    let d = Details {
        url: r["URL"].as_str().map(str::to_string),
        licenses: list("License").join(", "),
        depends,
        optional: list("OptDepends"),
        packager: r["Maintainer"].as_str().unwrap_or("—").to_string(),
        built: date("LastModified"),
        installed_on: String::new(),
        desc: r["Description"].as_str().unwrap_or("").into(),
        version: r["Version"].as_str().unwrap_or("").into(),
        size: String::new(),
    };
    Ok((pkg_of(r), d))
}

fn fmt_date(ts: i64) -> String {
    // Civil date from a Unix time, no time zone needed for a date.
    let days = ts.div_euclid(86400);
    let z = days + 719468;
    let era = z.div_euclid(146097);
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{y:04}-{m:02}-{d:02}")
}
