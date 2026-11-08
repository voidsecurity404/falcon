"use strict";

const tg = window.Telegram && window.Telegram.WebApp;
const initData = (tg && tg.initData) || "";
const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];

let T = {};
let hello = {};
const t = (s, vars) => {
  let out = T[s] || s;
  if (vars) for (const k in vars) out = out.replaceAll("{" + k + "}", vars[k]);
  return out;
};

/* ---------- Telegram ---------- */

function haptic(kind = "light") {
  try {
    if (kind === "ok" || kind === "error" || kind === "warning") tg.HapticFeedback.notificationOccurred(kind === "ok" ? "success" : kind);
    else if (kind === "select") tg.HapticFeedback.selectionChanged();
    else tg.HapticFeedback.impactOccurred(kind);
  } catch (_) {}
}

function confirmBox(text) {
  return new Promise((resolve) => {
    if (tg && tg.showConfirm && tg.isVersionAtLeast && tg.isVersionAtLeast("6.2")) tg.showConfirm(text, resolve);
    else resolve(window.confirm(text));
  });
}

if (tg) {
  tg.ready();
  tg.expand();
  try { tg.disableVerticalSwipes(); } catch (_) {}
}

/* ---------- API ---------- */

class ApiError extends Error {}

async function api(path, opts = {}) {
  const headers = Object.assign({ "X-Init-Data": initData }, opts.headers || {});
  let body = opts.body;
  if (body && !(body instanceof Blob) && typeof body !== "string") {
    body = JSON.stringify(body);
    headers["Content-Type"] = "application/json";
  }
  let res;
  try {
    res = await fetch(path, { method: opts.method || (body ? "POST" : "GET"), headers, body, cache: "no-store" });
  } catch (e) {
    setOnline(false);
    throw new ApiError(t("No connection to the computer"));
  }
  setOnline(true);
  if (res.status === 403) {
    const j = await res.json().catch(() => ({}));
    showGate(t("No access"), j.error || "");
    throw new ApiError(j.error || "forbidden");
  }
  if (opts.blob) {
    if (!res.ok) {
      const j = await res.json().catch(() => ({}));
      throw new ApiError(j.error || res.statusText);
    }
    return res.blob();
  }
  const j = await res.json().catch(() => ({}));
  if (!res.ok || j.error) throw new ApiError(j.error || res.statusText);
  return j;
}

let online = true;
function setOnline(on) {
  if (on === online) return;
  online = on;
  $(".dot").classList.toggle("off", !on);
  if (!on) $("#subText").textContent = t("No connection");
}

function showGate(title, sub) {
  $("#gateText").textContent = title;
  $("#gateSub").textContent = sub;
  $("#gate").classList.add("on");
}

let toastTimer;
function toast(text, bad = false) {
  const el = $("#toast");
  el.textContent = text;
  el.classList.toggle("bad", bad);
  el.classList.add("on");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("on"), 2600);
  haptic(bad ? "error" : "ok");
}

/* ---------- Formatting ---------- */

function bytes(n, digits = 1) {
  const units = [t("B"), t("KB"), t("MB"), t("GB"), t("TB")];
  let i = 0;
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
  return (i === 0 ? Math.round(n) : n.toFixed(n >= 100 ? 0 : digits)) + " " + units[i];
}
const rate = (n) => t("{v}/s", { v: bytes(n) });

function age(sec) {
  sec = Math.max(0, Math.floor(sec));
  const d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600), m = Math.floor((sec % 3600) / 60);
  if (d > 0) return t("{d} d {h} h", { d, h });
  if (h > 0) return t("{h} h {m} min", { h, m });
  if (m > 0) return t("{m} min", { m });
  return t("{s} s", { s: sec });
}

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

/* ---------- Theme from the wallpaper ---------- */

function hexToHsl(hex) {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex || "");
  if (!m) return null;
  const n = parseInt(m[1], 16);
  let r = (n >> 16) / 255, g = ((n >> 8) & 255) / 255, b = (n & 255) / 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h = 0, s = 0;
  const l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    h *= 60;
  }
  return [h, s * 100, l * 100];
}
const hsl = (h, s, l) => `hsl(${((h % 360) + 360) % 360} ${s}% ${l}%)`;

function applyTheme(c) {
  const root = document.documentElement.style;
  const set = (k, v) => v && root.setProperty(k, v);
  set("--accent", c.accent);
  set("--accent-text", c.accentText);
  set("--surface", c.surface);
  set("--text", c.text);
  set("--muted", c.muted);
  set("--error", c.error);
  set("--bg", c.pill || c.surface);
  const a = hexToHsl(c.accent);
  if (a) {
    const s = Math.max(a[1], 45);
    set("--accent2", hsl(a[0] + 130, s, Math.max(a[2], 70)));
    set("--accent3", hsl(a[0] + 240, s, Math.max(a[2], 74)));
  }
  if (tg) {
    try {
      tg.setHeaderColor(c.pill || c.surface || "#120d0c");
      tg.setBackgroundColor(c.pill || c.surface || "#120d0c");
      tg.setBottomBarColor && tg.setBottomBarColor(c.pill || c.surface || "#120d0c");
    } catch (_) {}
  }
}
const css = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();

function translatePage() {
  $$("[data-t]").forEach((el) => (el.textContent = t(el.dataset.t)));
  $("#procQ").placeholder = t("Search by name, PID or user");
  $("#clipText").placeholder = t("Text for the computer's clipboard");
  $("#pcClip").dataset.empty = t("The clipboard has no text.");
  document.documentElement.lang = hello.lang || "en";
}

/* ---------- Charts ---------- */

function drawArea(canvas, series, opts = {}) {
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth, h = canvas.clientHeight;
  if (!w || !h) return;
  if (canvas.width !== w * dpr || canvas.height !== h * dpr) { canvas.width = w * dpr; canvas.height = h * dpr; }
  const ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);
  const len = opts.len || 90;
  let max = opts.max;
  if (!max) { max = 1; series.forEach((s) => s.data.forEach((v) => (max = Math.max(max, v)))); max *= 1.15; }
  series.forEach((s) => {
    const data = s.data.slice(-len);
    if (data.length < 2) return;
    const step = w / (len - 1);
    const x0 = w - (data.length - 1) * step;
    const y = (v) => h - 2 - (Math.min(v, max) / max) * (h - 6);
    ctx.beginPath();
    ctx.moveTo(x0, y(data[0]));
    for (let i = 1; i < data.length; i++) {
      const xa = x0 + (i - 1) * step, xb = x0 + i * step, xm = (xa + xb) / 2;
      ctx.bezierCurveTo(xm, y(data[i - 1]), xm, y(data[i]), xb, y(data[i]));
    }
    ctx.strokeStyle = s.color;
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.lineTo(w, h);
    ctx.lineTo(x0, h);
    ctx.closePath();
    const g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, s.fill || s.color);
    g.addColorStop(1, "transparent");
    ctx.globalAlpha = 0.28;
    ctx.fillStyle = g;
    ctx.fill();
    ctx.globalAlpha = 1;
  });
}

function setGauge(id, value, max, text) {
  const el = $(id);
  const v = Math.max(0, Math.min(1, value / max));
  el.querySelector(".bar").style.strokeDasharray = `${(v * 197.9).toFixed(1)} 263.9`;
  el.querySelector("b").textContent = text;
}

// btop-like color: calm, then the accent, then the error color.
function loadColor(p) {
  if (p < 50) return "var(--accent2)";
  if (p < 80) return "var(--accent)";
  return "var(--error)";
}

/* ---------- Tabs ---------- */

let current = "dash";
const loops = {};

function loop(name, fn, ms) {
  clearTimeout(loops[name]);
  const tick = async () => {
    if (current !== name || document.hidden) return;
    try { await fn(); } catch (_) {}
    loops[name] = setTimeout(tick, ms);
  };
  tick();
}

function openTab(name) {
  if (name === current && $("#tab-" + name).classList.contains("active")) return;
  current = name;
  haptic("select");
  $$("#nav button").forEach((b) => b.classList.toggle("on", b.dataset.tab === name));
  $$(".tab").forEach((s) => s.classList.toggle("active", s.id === "tab-" + name));
  window.scrollTo({ top: 0 });
  startTab();
}

function startTab() {
  if (current === "dash") { loop("dash", refreshOverview, 1500); setTimeout(refreshControls, 50); }
  if (current === "term") openTerminal();
  if (current === "screen") loop("screen", refreshWindows, 4000);
  if (current === "procs") loop("procs", refreshProcs, 2000);
  if (current === "clip") { refreshClip(); renderSent(); }
}

$$("#nav button").forEach((b) => b.addEventListener("click", () => openTab(b.dataset.tab)));
document.addEventListener("visibilitychange", () => !document.hidden && startTab());

/* ---------- Overview ---------- */

let coresBuilt = 0;
let lastControls = 0;

async function refreshOverview() {
  const o = await api("/api/overview");
  $("#host").textContent = o.host;
  $("#subText").textContent = (o.session ? "" : t("At the login screen") + " · ") + t("On for {time}", { time: age(o.uptime) });

  setGauge("#gCpu", o.cpu, 100, Math.round(o.cpu));
  const memP = o.mem.total ? (100 * o.mem.used) / o.mem.total : 0;
  setGauge("#gMem", memP, 100, Math.round(memP));
  setGauge("#gTemp", o.temp, 100, o.temp ? Math.round(o.temp) : "–");
  $("#gTemp").style.setProperty("--c", o.temp >= 85 ? "var(--error)" : "var(--accent3)");
  $("#cpuModel").textContent = (o.cpuModel || "").replace(/\(R\)|\(TM\)|CPU|Processor/g, "").replace(/\s+/g, " ").trim();
  $("#cpuFreq").textContent = o.freqMHz ? (o.freqMHz / 1000).toFixed(2) + " " + t("GHz") : "";
  drawArea($("#cpuChart"), [{ data: o.history.cpu || [], color: css("--accent") }], { max: 100 });

  const cores = $("#cores");
  if (coresBuilt !== o.cores.length) {
    cores.innerHTML = o.cores.map((_, i) => `<div class="core"><span>${i}</span><div class="m"><i></i></div><b>0</b></div>`).join("");
    coresBuilt = o.cores.length;
  }
  $$(".core", cores).forEach((el, i) => {
    const v = o.cores[i] || 0;
    const bar = el.querySelector("i");
    bar.style.width = v.toFixed(0) + "%";
    bar.style.setProperty("--c", loadColor(v));
    el.querySelector("b").textContent = Math.round(v);
  });
  $("#loadAvg").textContent = (o.load || []).map((v) => v.toFixed(2)).join("  ");

  $("#netIface").textContent = o.net.iface || "";
  $("#rx").textContent = rate(o.net.rx);
  $("#tx").textContent = rate(o.net.tx);
  drawArea($("#netChart"), [
    { data: o.history.rx || [], color: css("--accent2") },
    { data: o.history.tx || [], color: css("--accent") },
  ], { len: 60 });

  $("#memText").textContent = bytes(o.mem.used) + " / " + bytes(o.mem.total, 0);
  drawArea($("#memChart"), [{ data: o.history.mem || [], color: css("--accent2") }], { max: 100, len: 60 });
  const cache = Math.min(o.mem.cached, o.mem.total - o.mem.used);
  $("#memUsed").style.width = memP + "%";
  $("#memCache").style.width = (o.mem.total ? (100 * cache) / o.mem.total : 0) + "%";
  $("#swap").textContent = o.mem.swapTotal ? bytes(o.mem.swapUsed) : "–";
  $("#diskIO").textContent = bytes(o.diskIO[0] + o.diskIO[1]) + t("/s");

  $("#disks").innerHTML = (o.disks || []).map((d) => {
    const p = d.total ? (100 * d.used) / d.total : 0;
    return `<div class="disk"><div class="diskTop"><span class="mono">${esc(d.mount)}</span><span>${bytes(d.used)} / ${bytes(d.total, 0)}</span></div><div class="track"><i style="width:${p.toFixed(1)}%"></i></div></div>`;
  }).join("");

  const chips = [];
  const icon = (p) => `<svg viewBox="0 0 24 24"><path d="${p}"/></svg>`;
  if (o.battery) {
    const charging = o.battery.status === "Charging" || o.battery.status === "Full";
    chips.push(`${icon(charging ? "M13 3L5 14h6l-1 7 8-11h-6Z" : "M4 8h14v8H4Z M20 11v2")}<span>${t("Battery")}</span><b>${o.battery.percent}%</b>${o.battery.watts ? `<span class="dim">${o.battery.watts.toFixed(1)} ${t("W")}</span>` : ""}`);
  }
  chips.push(`${icon("M3 12h4l3-8 4 16 3-8h4")}<span>${t("Processes")}</span><b>${o.procs}</b>`);
  if (o.gpuMHz) chips.push(`${icon("M7 7h10v10H7Z M10 3v4 M14 3v4 M10 17v4 M14 17v4 M3 10h4 M3 14h4 M17 10h4 M17 14h4")}<span>GPU</span><b>${Math.round(o.gpuMHz)} ${t("MHz")}</b>`);
  chips.push(`${icon("M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18Z M12 7v5l3 2")}<span>${t("Uptime")}</span><b>${age(o.uptime)}</b>`);
  chips.push(`${icon("M12 4a4 4 0 1 0 0 8a4 4 0 0 0 0-8Z M4 21a8 8 0 0 1 16 0")}<b>${esc(o.user)}</b><span class="dim">${esc(o.kernel)}</span>`);
  $("#chips").innerHTML = chips.map((c) => `<div class="chip">${c}</div>`).join("");

  if (Date.now() - lastControls > 3000) refreshControls();
}

async function refreshControls() {
  lastControls = Date.now();
  const c = await api("/api/controls").catch(() => null);
  if (!c) return;
  if (c.volume) {
    $("#volText").textContent = c.volume.muted ? t("Muted") : Math.round(c.volume.level * 100) + "%";
    $("#volFill").style.width = Math.min(100, c.volume.level * 100) + "%";
    $(".volBar").classList.toggle("muted", c.volume.muted);
  }
  const p = c.player;
  $("#mTitle").textContent = p ? p.title || t("Unknown") : t("Nothing is playing");
  $("#mArtist").textContent = p ? p.artist : "";
  $("#playIcon").innerHTML = p && p.status === "Playing" ? '<path d="M7 5h3.5v14H7Z M13.5 5H17v14h-3.5Z"/>' : '<path d="M7 5v14l12-7Z"/>';
}

const actionNames = { suspend: "Put the computer to sleep?", reboot: "Restart the computer?", poweroff: "Shut down the computer?", lock: "" };

$$("[data-act]").forEach((b) => b.addEventListener("click", async () => {
  const name = b.dataset.act;
  if (actionNames[name] && !(await confirmBox(t(actionNames[name])))) return;
  haptic("medium");
  try {
    await api("/api/action/" + name, { method: "POST" });
    if (name in actionNames) toast(t("Done"));
    setTimeout(refreshControls, 250);
  } catch (e) {
    toast(e.message, true);
  }
}));

/* ---------- Terminal ---------- */

let term, fit, ws, termReady = false, termRetry = 0, termFontSize = 12;
const mods = { ctrl: false, alt: false };

function openTerminal() {
  if (!window.Terminal) { toast(t("The terminal could not be loaded"), true); return; }
  if (!term) {
    try { termFontSize = Number(localStorage.getItem("termFont")) || 12; } catch (_) {}
    term = new Terminal({
      fontFamily: '"Geist Mono", ui-monospace, monospace',
      fontSize: termFontSize,
      cursorBlink: true,
      allowProposedApi: true,
      scrollback: 5000,
      theme: {
        background: "rgba(0,0,0,0)",
        foreground: css("--text"),
        cursor: css("--accent"),
        cursorAccent: css("--accent-text"),
        selectionBackground: "rgba(255,255,255,0.25)",
      },
      allowTransparency: true,
    });
    fit = new FitAddon.FitAddon();
    term.loadAddon(fit);
    term.open($("#term"));
    term.onData((d) => sendKeys(d));
    new ResizeObserver(() => resizeTerm()).observe($("#termBox"));
  }
  setTimeout(() => { resizeTerm(); if (!ws || ws.readyState > 1) connectTerm(false); term.focus(); }, 60);
}

function resizeTerm() {
  if (!term || current !== "term") return;
  try { fit.fit(); } catch (_) {}
  if (ws && ws.readyState === 1) ws.send(JSON.stringify({ t: "r", c: term.cols, r: term.rows }));
}

function connectTerm(fresh) {
  if (ws && ws.readyState <= 1) ws.close();
  const url = new URL("/api/term", location.href);
  url.protocol = location.protocol === "https:" ? "wss:" : "ws:";
  url.searchParams.set("auth", initData);
  url.searchParams.set("cols", term.cols);
  url.searchParams.set("rows", term.rows);
  if (fresh) url.searchParams.set("fresh", "1");
  const sock = new WebSocket(url);
  sock.binaryType = "arraybuffer";
  ws = sock;
  if (fresh) term.reset();
  let first = true;
  sock.onmessage = (ev) => {
    if (typeof ev.data === "string") {
      const m = JSON.parse(ev.data);
      if ("root" in m) {
        const badge = $("#termBadge");
        badge.textContent = m.root ? "root" : (hello.user || t("user"));
        badge.classList.toggle("root", m.root);
        if (first && !fresh) term.reset();
        first = false;
        termRetry = 0;
      }
      if (m.exit) term.write("\r\n\x1b[2m" + t("[session ended, press New session]") + "\x1b[0m\r\n");
      if (m.error) term.write("\r\n\x1b[31m" + m.error + "\x1b[0m\r\n");
      return;
    }
    term.write(new Uint8Array(ev.data));
  };
  sock.onclose = () => {
    if (ws !== sock) return;
    if (current === "term" && !document.hidden && termRetry < 6) {
      termRetry++;
      setTimeout(() => current === "term" && ws === sock && connectTerm(false), 800 * termRetry);
    }
  };
}

function sendKeys(d) {
  if (!ws || ws.readyState !== 1) return;
  if (mods.ctrl && d.length === 1) {
    const c = d.toUpperCase().charCodeAt(0);
    if (c >= 64 && c <= 95) d = String.fromCharCode(c - 64);
    else if (d === " ") d = "\x00";
    setMod("ctrl", false);
  }
  if (mods.alt) { d = "\x1b" + d; setMod("alt", false); }
  ws.send(JSON.stringify({ t: "i", d }));
}

function setMod(name, on) {
  mods[name] = on;
  $(`[data-k="${name}"]`).classList.toggle("on", on);
}

const keyMap = {
  esc: "\x1b", tab: "\t", up: "\x1b[A", down: "\x1b[B", right: "\x1b[C", left: "\x1b[D",
  home: "\x1b[H", end: "\x1b[F", pgup: "\x1b[5~", pgdn: "\x1b[6~",
  "^C": "\x03", "^D": "\x04", "^L": "\x0c", "^R": "\x12",
};

$$("#keys button").forEach((b) => {
  b.addEventListener("pointerdown", (e) => e.preventDefault());
  b.addEventListener("click", () => {
    haptic("light");
    const k = b.dataset.k;
    if (k === "ctrl" || k === "alt") { setMod(k, !mods[k]); return; }
    sendKeys(keyMap[k] || k);
    term && term.focus();
  });
});

$("#termNew").addEventListener("click", async () => {
  if (!(await confirmBox(t("End this session and start a new one?")))) return;
  termRetry = 0;
  connectTerm(true);
  term.focus();
});

$("#termFont").addEventListener("click", () => {
  termFontSize = termFontSize >= 15 ? 10 : termFontSize + 1;
  term.options.fontSize = termFontSize;
  try { localStorage.setItem("termFont", termFontSize); } catch (_) {}
  resizeTerm();
});

/* ---------- Windows and screenshots ---------- */

const icons = new Map();

async function iconURL(appId) {
  if (icons.has(appId)) return icons.get(appId);
  const p = api("/api/icon/" + encodeURIComponent(appId), { blob: true }).then((b) => URL.createObjectURL(b)).catch(() => "");
  icons.set(appId, p);
  return p;
}

function iconHTML(w) {
  const letter = esc((w.name || w.appId || "?").trim().charAt(0).toUpperCase());
  return `<div class="appIcon letter" data-icon="${w.icon ? esc(w.appId) : ""}">${letter}</div>`;
}

async function fillIcons(root) {
  for (const el of $$("[data-icon]", root)) {
    const id = el.dataset.icon;
    if (!id) continue;
    const url = await iconURL(id);
    if (url && el.isConnected) {
      const img = new Image();
      img.className = "appIcon";
      img.src = url;
      img.onload = () => el.replaceWith(img);
    }
  }
}

let windowsKey = "";
let windowsList = [];

async function refreshWindows() {
  let data;
  try {
    data = await api("/api/windows");
  } catch (e) {
    $("#windows").innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    windowsKey = "";
    return;
  }
  windowsList = data.windows;
  const key = JSON.stringify(data.windows.map((w) => [w.id, w.title, w.focused, w.workspace, Math.round(w.cpu), Math.round(w.mem / 1e7), Math.floor(w.age / 60)]));
  if (key === windowsKey) return;
  windowsKey = key;
  if (!data.windows.length) {
    $("#windows").innerHTML = `<div class="empty">${t("No open windows")}</div>`;
    return;
  }
  let html = "", ws = null;
  for (const w of data.windows) {
    if (w.workspace !== ws) {
      ws = w.workspace;
      html += `<div class="wsTitle">${t("Workspace {n}", { n: ws })}</div>`;
    }
    html += `<button class="card win" data-win="${w.id}">
      ${iconHTML(w)}
      <div class="winText">
        <div class="winName">${w.focused ? '<i class="focused"></i>' : ""}<span class="ell">${esc(w.name)}</span></div>
        <div class="winTitle">${esc(w.title)}</div>
        <div class="winMeta">
          <span><svg viewBox="0 0 24 24"><path d="M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18Z M12 7v5l3 2"/></svg>${w.age ? age(w.age) : "–"}</span>
          <span><svg viewBox="0 0 24 24"><path d="M3 12h4l3-8 4 16 3-8h4"/></svg>${w.cpu.toFixed(1)}%</span>
          <span><svg viewBox="0 0 24 24"><path d="M7 7h10v10H7Z M10 3v4 M14 3v4 M10 17v4 M14 17v4"/></svg>${bytes(w.mem)}</span>
        </div>
      </div>
    </button>`;
  }
  $("#windows").innerHTML = html;
  fillIcons($("#windows"));
  $$("[data-win]").forEach((b) => b.addEventListener("click", () => openViewer(windowsList.find((w) => String(w.id) === b.dataset.win))));
}

let viewing = null, liveTimer = null, lastShot = "";

function openSheet(id) {
  $(id).classList.add("open");
  if (tg && tg.BackButton) tg.BackButton.show();
}
function closeSheets() {
  $$(".sheet").forEach((s) => s.classList.remove("open"));
  stopLive();
  viewing = null;
  if (tg && tg.BackButton) tg.BackButton.hide();
}
if (tg && tg.BackButton) tg.BackButton.onClick(closeSheets);
$$(".sheet").forEach((s) => s.addEventListener("click", (e) => e.target === s && closeSheets()));
$("#vClose").addEventListener("click", closeSheets);
$("#pClose").addEventListener("click", closeSheets);

function openViewer(w) {
  haptic("light");
  viewing = w || { id: null };
  const whole = !w;
  $("#vTitle").textContent = whole ? t("Whole screen") : w.name;
  $("#vSub").textContent = whole ? hello.host || "" : w.title;
  $("#vFocus").style.display = whole ? "none" : "";
  $("#vKill").style.display = whole ? "none" : "";
  const icon = $("#vIcon");
  icon.style.display = "none";
  if (w && w.icon) iconURL(w.appId).then((u) => { if (u) { icon.src = u; icon.style.display = ""; } });
  $("#vImg").src = "";
  openSheet("#viewer");
  loadShot();
}

async function loadShot() {
  if (!viewing) return;
  const target = viewing;
  $("#vSpin").classList.toggle("on", !$("#vImg").getAttribute("src"));
  $("#vErr").textContent = "";
  try {
    const blob = await api(target.id ? `/api/windows/${target.id}/shot` : "/api/screen", { blob: true });
    if (viewing !== target) return;
    const url = URL.createObjectURL(blob);
    $("#vImg").src = url;
    if (lastShot) URL.revokeObjectURL(lastShot);
    lastShot = url;
  } catch (e) {
    if (viewing === target) $("#vErr").textContent = e.message;
  }
  $("#vSpin").classList.remove("on");
}

function stopLive() {
  clearTimeout(liveTimer);
  liveTimer = null;
  $("#vLive").classList.remove("on");
}

$("#vRefresh").addEventListener("click", () => { haptic(); loadShot(); });
$("#vLive").addEventListener("click", () => {
  if (liveTimer) { stopLive(); return; }
  $("#vLive").classList.add("on");
  const tick = async () => {
    if (!viewing || !$("#vLive").classList.contains("on")) return;
    await loadShot();
    liveTimer = setTimeout(tick, 1500);
  };
  liveTimer = setTimeout(tick, 0);
});
$("#vFocus").addEventListener("click", async () => {
  try { await api(`/api/windows/${viewing.id}/focus`, { method: "POST" }); toast(t("The window is in front")); setTimeout(loadShot, 400); } catch (e) { toast(e.message, true); }
});
$("#vKill").addEventListener("click", async () => {
  if (!(await confirmBox(t("Close this window?")))) return;
  try { await api(`/api/windows/${viewing.id}/close`, { method: "POST" }); toast(t("Closed")); closeSheets(); windowsKey = ""; refreshWindows(); } catch (e) { toast(e.message, true); }
});
$("#wholeScreen").addEventListener("click", () => openViewer(null));
$("#shotTop").addEventListener("click", () => openViewer(null));

/* ---------- Processes ---------- */

let sortBy = "cpu", mineOnly = false, procQuery = "", procData = [], selectedProc = null;

async function refreshProcs() {
  const q = new URLSearchParams({ sort: sortBy, q: procQuery, mine: mineOnly ? "1" : "0" });
  const d = await api("/api/procs?" + q);
  procData = d.procs;
  $("#procSummary").innerHTML = `<span>${t("Shown")} <b>${d.total}</b> / ${d.all}</span><span>${t("Cores")} <b>${d.cores}</b></span>`;
  $("#procs").innerHTML = d.procs.map((p) => {
    return `<div class="proc" data-pid="${p.pid}">
      <div class="pn"><div>${esc(p.name)}</div><div>${p.pid} · ${esc(p.user)} · ${age(p.age)}</div></div>
      <div class="pc"><span>${p.cpu.toFixed(1)}%</span><div class="m"><i style="width:${Math.min(100, p.cpu).toFixed(1)}%;--c:${loadColor(p.cpu)}"></i></div></div>
      <div class="pm">${bytes(p.mem)}</div>
    </div>`;
  }).join("") || `<div class="empty">${t("Nothing found")}</div>`;
  if (selectedProc) {
    const p = procData.find((x) => x.pid === selectedProc.pid);
    if (p) fillProc(p);
  }
}

$("#procs").addEventListener("click", (e) => {
  const row = e.target.closest("[data-pid]");
  if (!row) return;
  const p = procData.find((x) => String(x.pid) === row.dataset.pid);
  if (!p) return;
  haptic();
  selectedProc = p;
  fillProc(p);
  openSheet("#procSheet");
});

function fillProc(p) {
  $("#pName").textContent = p.name;
  $("#pSub").textContent = `PID ${p.pid} · PPID ${p.ppid} · ${p.user}`;
  $("#pCmd").textContent = p.cmd || p.name;
  const stat = (label, v) => `<div><span>${label}</span><b>${v}</b></div>`;
  $("#pStats").innerHTML = stat("CPU", p.cpu.toFixed(1) + "%") + stat(t("RAM"), bytes(p.mem)) + stat(t("Time"), age(p.age)) + stat(t("Threads"), p.threads) + stat(t("State"), p.state) + stat(t("Owner"), esc(p.user));
}

$$("[data-sig]").forEach((b) => b.addEventListener("click", async () => {
  const p = selectedProc;
  if (!p) return;
  const sig = b.dataset.sig;
  if ((sig === "TERM" || sig === "KILL") && !(await confirmBox(t("End {name} ({pid})?", { name: p.name, pid: p.pid })))) return;
  try {
    await api(`/api/procs/${p.pid}/signal`, { body: { signal: sig } });
    toast(t("Signal sent: {sig}", { sig }));
    if (sig === "TERM" || sig === "KILL") { closeSheets(); selectedProc = null; }
    setTimeout(refreshProcs, 400);
  } catch (e) {
    toast(e.message, true);
  }
}));

$$("#sorts [data-s]").forEach((b) => b.addEventListener("click", () => {
  sortBy = b.dataset.s;
  $$("#sorts [data-s]").forEach((x) => x.classList.toggle("on", x === b));
  haptic("select");
  refreshProcs();
}));
$("#mineOnly").addEventListener("click", () => {
  mineOnly = !mineOnly;
  $("#mineOnly").classList.toggle("on", mineOnly);
  haptic("select");
  refreshProcs();
});
let searchTimer;
$("#procQ").addEventListener("input", (e) => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => { procQuery = e.target.value; refreshProcs(); }, 250);
});

/* ---------- Clipboard ---------- */

function loadSent() {
  try { return JSON.parse(localStorage.getItem("sent") || "[]"); } catch (_) { return []; }
}
function remember(text) {
  const list = [{ text, at: Date.now() }, ...loadSent().filter((x) => x.text !== text)].slice(0, 8);
  try { localStorage.setItem("sent", JSON.stringify(list)); } catch (_) {}
  renderSent();
}
function renderSent() {
  const list = loadSent();
  $("#sentCard").style.display = list.length ? "" : "none";
  $("#sent").innerHTML = list.map((x, i) => `<div class="sentRow"><span>${esc(x.text)}</span><time>${new Date(x.at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</time><button class="ic sm" data-again="${i}"><svg viewBox="0 0 24 24"><path d="M21 3L3 10.5L10 13L13 20Z M10 13L21 3"/></svg></button></div>`).join("");
  $$("[data-again]").forEach((b) => b.addEventListener("click", () => sendText(list[Number(b.dataset.again)].text)));
}

async function sendText(text) {
  if (!text.trim()) { toast(t("Write something first"), true); return; }
  try {
    await api("/api/clipboard", { body: { text } });
    remember(text);
    toast(t("Copied on the computer"));
    setTimeout(refreshClip, 300);
  } catch (e) {
    toast(e.message, true);
  }
}

$("#clipSend").addEventListener("click", () => {
  const text = $("#clipText").value;
  sendText(text).then(() => {});
});

$("#clipImg").addEventListener("change", async (e) => {
  const file = e.target.files[0];
  e.target.value = "";
  if (!file) return;
  try {
    await api("/api/clipboard", { body: file, headers: { "Content-Type": file.type || "image/jpeg" } });
    toast(t("The picture is on the computer's clipboard"));
    setTimeout(refreshClip, 300);
  } catch (err) {
    toast(err.message, true);
  }
});

let pcText = "";
async function refreshClip() {
  try {
    const c = await api("/api/clipboard");
    pcText = c.text || "";
    $("#pcClip").textContent = pcText;
    const img = $("#pcClipImg");
    if (c.image) {
      const blob = await api("/api/clipboard/image", { blob: true });
      if (img.src) URL.revokeObjectURL(img.src);
      img.src = URL.createObjectURL(blob);
      img.style.display = "block";
    } else {
      img.style.display = "none";
    }
    $("#clipToPhone").style.display = pcText ? "" : "none";
  } catch (e) {
    $("#pcClip").textContent = e.message;
  }
}
$("#clipRefresh").addEventListener("click", () => { haptic(); refreshClip(); });

$("#clipToPhone").addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(pcText);
  } catch (_) {
    const area = document.createElement("textarea");
    area.value = pcText;
    document.body.appendChild(area);
    area.select();
    document.execCommand("copy");
    area.remove();
  }
  toast(t("Copied to the phone"));
});

/* ---------- Start ---------- */

async function start() {
  if (!initData) {
    showGate(t("Open this from Telegram"), t("This page works only inside the bot's app."));
    return;
  }
  try {
    hello = await api("/api/hello");
  } catch (e) {
    if (!$("#gate").classList.contains("on")) showGate(t("No connection to the computer"), e.message);
    return;
  }
  T = hello.i18n || {};
  applyTheme(hello.theme || {});
  translatePage();
  $("#host").textContent = hello.host;
  $$(".needsPower").forEach((b) => (b.disabled = !hello.power));
  $("#shotTop").style.display = hello.screen ? "" : "none";
  $("#wholeScreen").style.display = hello.screen ? "" : "none";
  startTab();
}

start();
