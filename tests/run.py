#!/usr/bin/env python3
"""niri-desk uchun avtomatik test: har funksiya bo'yicha ssenariylar.

Faqat sinov mashinasida ishga tushiring: oynalarni yopadi, sozlamalarni o'zgartiradi.
Haqiqiy klavish va sichqoncha ydotool orqali yuboriladi.

  tests/run.py [--only ID,ID] [--list]
Natija: /tmp/niri-desk-report.json
"""
import json, os, re, shutil, subprocess, sys, tempfile, time, traceback
from pathlib import Path

HOME = Path.home()
SET = HOME / ".config/niri-desk/settings.json"
GEN = HOME / ".config/niri/generated"
STATE = HOME / ".local/state/niri-desk"
FAILDIR = Path("/tmp/nd-fail")
LIB = {p: p.read_text() for p in (HOME / ".config/niri-desk/profiles.json", HOME / ".config/niri-desk/snippets.json") if p.exists()}
PW = os.environ.get("NIRI_DESK_TEST_PW", "")
FEATURES, CUR = [], None
KEYC = {**{c: k for c, k in zip("qwertyuiop", range(16, 26))}, **{c: k for c, k in zip("asdfghjkl", range(30, 39))}, **{c: k for c, k in zip("zxcvbnm", range(44, 51))},
        **{str(i): i + 1 for i in range(1, 10)}, "0": 11, "enter": 28, "esc": 1, "space": 57, "tab": 15, "grave": 41, "comma": 51, "minus": 12, "equal": 13,
        "left": 105, "right": 106, "up": 103, "down": 108, "shift": 42, "ctrl": 29, "alt": 56, "mod": 125, "[": 26, "]": 27, "volup": 115, "voldown": 114, "mute": 113,
        "backspace": 14, "print": 99, "slash": 53}


class Skip(Exception):
    pass


def feature(fid, title):
    global CUR
    CUR = {"id": fid, "title": title, "cases": []}
    FEATURES.append(CUR)


def case(desc):
    def deco(fn):
        CUR["cases"].append((desc, fn))
        return fn
    return deco


def sh(cmd, check=False, timeout=20, stdin=None):
    r = subprocess.run(cmd, shell=isinstance(cmd, str), capture_output=True, text=True, timeout=timeout, input=stdin, errors="replace")
    if check and r.returncode:
        raise AssertionError(f"{cmd} rc={r.returncode}: {r.stderr[:200]}")
    return r


def niri(*a):
    return sh(["niri", "msg", "action", *map(str, a)])


def nj(what):
    return json.loads(sh(["niri", "msg", "--json", what], check=True).stdout)


def windows():
    return nj("windows")


def wsl():
    return sorted(nj("workspaces"), key=lambda w: w["idx"])


def active_ws():
    return next(w["idx"] for w in wsl() if w["is_active"])


def focused():
    return next((w for w in windows() if w["is_focused"]), None)


def win(i):
    return next((w for w in windows() if w["id"] == i), None)


def ipc(*a):
    return sh(["qs", "-c", "niri-desk", "ipc", "call", "desk", *a], timeout=8)


def st():
    return json.loads(ipc("state").stdout)


def layers():
    return [l["namespace"] for l in nj("layers")]


def wait(fn, t=5.0, msg=""):
    end = time.time() + t
    last = None
    while time.time() < end:
        try:
            last = fn()
            if last:
                return last
        except (ValueError, StopIteration, KeyError, IndexError):
            pass
        time.sleep(0.08)
    raise AssertionError(msg or f"kutilgan holat bo'lmadi (oxirgi: {last!r})")


def ok(cond, msg="shart bajarilmadi"):
    if not cond:
        raise AssertionError(msg)


def key(*names):
    seq = [KEYC[n] for n in names]
    ev = [f"{k}:1" for k in seq] + [f"{k}:0" for k in reversed(seq)]
    sh(["ydotool", "key", "-d", "12", *ev])
    time.sleep(0.12)


def typ(text):
    sh(["ydotool", "type", "-d", "8", "--", text])
    time.sleep(0.25)


def move(x, y):
    sh(["ydotool", "mousemove", "--absolute", "-x", str(x), "-y", str(y)])
    time.sleep(0.12)
    sh(["ydotool", "mousemove", "-x", "1", "-y", "0"])
    time.sleep(0.08)


def click(x, y, button="0xC0"):
    move(x, y)
    sh(["ydotool", "click", button])
    time.sleep(0.2)


def drag(x1, y1, x2, y2):
    move(x1, y1)
    sh(["ydotool", "click", "0x40"])
    time.sleep(0.15)
    move(x2, y2)
    sh(["ydotool", "click", "0x80"])
    time.sleep(0.2)


def term(title="t", cls=None, wait_new=True, focus_expected=True):
    before = {w["id"] for w in windows()}
    args = ["kitty"]
    if cls:
        args += ["--class", cls]
    args += ["--title", title, "sh", "-c", "sleep 900"]
    niri("spawn", "--", *args)
    if not wait_new:
        return None
    w = wait(lambda: [w for w in windows() if w["id"] not in before], 6, "oyna ochilmadi")[0]
    # Kitty ochilib bo'lgach fokusni oladi: shu bosqich tugashini kutamiz.
    time.sleep(0.8)
    return w["id"]


def shot(name, geom=None):
    path = f"/tmp/nd-{name}.png"
    sh(["grim"] + (["-g", geom] if geom else []) + [path], check=True)
    return Path(path).read_bytes()


def settings(**kw):
    """settings(windows__gaps=4): settings.json ni o'zgartiradi."""
    data = json.loads(SET.read_text() or "{}")
    for path, value in kw.items():
        node = data
        keys = path.split("__")
        for k in keys[:-1]:
            node = node.setdefault(k, {})
        node[keys[-1]] = value
    tmp = SET.with_suffix(".tmpx")
    tmp.write_text(json.dumps(data))
    os.replace(tmp, SET)
    time.sleep(1.0)


def toast(text, t=5):
    wait(lambda: text in st()["toast"], t, f"xabar chiqmadi: {text} (bor: {st()['toast']!r})")


def row(section):
    return [r.split("|", 1)[1] for r in st()["rows"] if r.startswith(section + "|")]


def launcher(q=""):
    key("mod", "space")
    wait(lambda: st()["popup"] == "launcher", 3, "qidiruv ochilmadi")
    time.sleep(0.5)
    if q:
        typ(q)
    time.sleep(0.2)


def clip_text():
    return sh(["wl-paste", "-n", "-t", "text/plain"]).stdout


GOOD = None


def reset():
    if sh("pgrep -x hyprlock").returncode == 0 and PW:
        typ(PW)
        key("enter")
        wait(lambda: sh("pgrep -x hyprlock").returncode != 0, 6, "ekran ochilmadi")
    wait(lambda: "niri-desk-top" in layers(), 12, "panel qaytmadi")
    ipc("reset")
    sh("rm -f /tmp/nd-*.flag")
    for path, text in LIB.items():
        if path.read_text() != text:
            path.write_text(text)
            time.sleep(0.4)
    if SET.read_text() != GOOD:
        SET.write_text(GOOD)
        time.sleep(1.0)
    if (GEN / "zen.kdl").read_text():
        (GEN / "zen.kdl").write_text("")
        time.sleep(0.5)
    if st()["layout"] != "EN":
        niri("switch-layout", "0")
    for w in windows():
        niri("close-window", "--id", w["id"])
    sh("pkill -f 'sleep 900'; pkill -f wf-recorder; pkill -x satty; pkill -x slurp; pkill -x btop; pkill -x nm-applet")
    try:
        wait(lambda: not windows(), 2.5)
    except AssertionError:
        sh("pkill -x kitty; pkill -f nautilus")
        wait(lambda: not windows(), 4, "oynalar yopilmadi")
    niri("focus-workspace", 1)
    move(1000, 600)
    time.sleep(0.15)


# ---------------------------------------------------------------------------------------
feature("ribbon", "Workspace raqamlari")


@case("Boshida raqamlar 1 dan ketma-ket boradi")
def _():
    r = st()["ribbon"]
    ok(r == list(range(1, len(r) + 1)), r)


@case("Mod+2 ikkinchi workspace'ga o'tkazadi")
def _():
    term()
    key("mod", "2")
    wait(lambda: active_ws() == 2)


@case("2 raqamini bosish o'tkazadi")
def _():
    term()
    click(14 + 4 + 26 + 13, 27)
    wait(lambda: active_ws() == 2)


@case("1 raqamini bosish qaytaradi")
def _():
    term()
    niri("focus-workspace", 2)
    time.sleep(0.3)
    click(14 + 4 + 13, 27)
    wait(lambda: active_ws() == 1)


@case("Oyna ko'chirilsa yangi raqam paydo bo'ladi")
def _():
    n = len(st()["ribbon"])
    term()
    key("mod", "ctrl", "2")
    wait(lambda: len(st()["ribbon"]) == n + 1)


@case("Oxirgi oyna yopilsa ortiqcha raqam yo'qoladi")
def _():
    n = len(st()["ribbon"])
    i = term()
    niri("move-column-to-workspace", 3)
    wait(lambda: len(st()["ribbon"]) >= n + 1)
    niri("close-window", "--id", i)
    wait(lambda: len(st()["ribbon"]) == n)


@case("9 ta workspace'da ham panel ishlaydi")
def _():
    for n in range(1, 10):
        niri("focus-workspace", n)
        term(f"w{n}")
    wait(lambda: len(st()["ribbon"]) >= 9)
    click(14 + 4 + 26 * 6 + 13, 27)
    wait(lambda: active_ws() == 7)


@case("Mod+J va Mod+K raqam bo'ylab yuradi")
def _():
    term()
    key("mod", "j")
    wait(lambda: active_ws() == 2)
    key("mod", "k")
    wait(lambda: active_ws() == 1)


@case("Diqqat so'ragan oyna shell'ni buzmaydi")
def _():
    i = term()
    niri("focus-workspace", 2)
    niri("set-window-urgent", "--id", i)
    wait(lambda: next(w for w in wsl() if w["idx"] == 1)["is_urgent"])
    ok(st()["ribbon"])
    niri("unset-window-urgent", "--id", i)


@case("Bo'sh raqamlarni yashirish sozlamasi panelni o'zgartiradi")
def _():
    term()
    a = shot("r1", "0,0 400x44")
    settings(panel__hideEmpty=True)
    b = shot("r2", "0,0 400x44")
    ok(a != b, "panel o'zgarmadi")


# ---------------------------------------------------------------------------------------
feature("rules", "Oyna ochilish qoidalari")


def floats(title="t", cls=None):
    i = term(title, cls)
    return win(i)["is_floating"]


@case("Oddiy terminal lentada ochiladi")
def _():
    ok(not floats("oddiy"))


@case("Ovoz sozlamasi (pavucontrol) suzib ochiladi")
def _():
    ok(floats("x", "pavucontrol"))


@case("'Open File' dialogi suzib ochiladi")
def _():
    ok(floats("Open File"))


@case("'Save As' dialogi suzib ochiladi")
def _():
    ok(floats("Save As"))


@case("Ruscha 'Открыть файл' suzib ochiladi")
def _():
    ok(floats("Открыть файл"))


@case("Picture-in-Picture suzib ochiladi va sticky bo'ladi")
def _():
    i = term("Picture-in-Picture")
    ok(win(i)["is_floating"])
    wait(lambda: i in st()["sticky"])


@case("'Open Source Notes' oddiy oyna bo'lib qoladi")
def _():
    ok(not floats("Open Source Notes"))


@case("Sarlavhada 'save' bo'lsa ham oddiy oyna qoladi")
def _():
    ok(not floats("how to save money"))


def foot(title, app):
    before = {w["id"] for w in windows()}
    niri("spawn", "--", "foot", "--app-id", app, "--title", title, "sh", "-c", "sleep 900")
    w = wait(lambda: [w for w in windows() if w["id"] not in before], 6, "oyna ochilmadi")[0]
    time.sleep(0.8)
    return w["id"]


@case("Steam xabari fokusni olmaydi")
def _():
    a = term("asosiy")
    b = foot("notificationtoasts_1_desktop", "steam")
    w = win(b)
    ok(w["is_floating"] and not w["is_focused"], w)
    ok(focused()["id"] == a)


@case("Scratchpad va Sozlamalar suzib ochiladi")
def _():
    ipc("settings")
    w = wait(lambda: next(x for x in windows() if x["title"] == "niri-desk settings"))
    ok(w["is_floating"])
    ok(w["layout"]["window_size"][0] == 860, w["layout"])


# ---------------------------------------------------------------------------------------
feature("columns", "Ustunlar va lenta")


@case("Mod+H va Mod+L ustunlar orasida yuradi")
def _():
    a = term("a"); b = term("b")
    key("mod", "h"); wait(lambda: focused()["id"] == a)
    key("mod", "l"); wait(lambda: focused()["id"] == b)


@case("Chetdagi ustunda Mod+L hech narsani buzmaydi")
def _():
    a = term("a")
    key("mod", "l"); key("mod", "l")
    ok(focused()["id"] == a)


@case("Mod+R kenglikni almashtiradi")
def _():
    term("a"); term("b")
    w0 = focused()["layout"]["tile_size"][0]
    key("mod", "r")
    wait(lambda: focused()["layout"]["tile_size"][0] != w0)


@case("Mod+Ctrl+L ustun o'rnini almashtiradi")
def _():
    a = term("a"); b = term("b")
    key("mod", "h")
    key("mod", "ctrl", "l")
    wait(lambda: win(a)["layout"]["pos_in_scrolling_layout"][0] == 2)


@case("Mod+M ustunni kengaytiradi")
def _():
    term("a"); term("b")
    w0 = focused()["layout"]["tile_size"][0]
    key("mod", "m")
    wait(lambda: focused()["layout"]["tile_size"][0] > w0)


@case("Mod+Shift+F to'liq ekran qiladi va qaytaradi")
def _():
    term("a")
    w0 = focused()["layout"]["tile_size"]
    key("mod", "shift", "f")
    wait(lambda: focused()["layout"]["tile_size"][1] >= 800)
    key("mod", "shift", "f")
    wait(lambda: focused()["layout"]["tile_size"] == w0)


@case("Mod+[ oynani qo'shni ustunga qo'shadi")
def _():
    a = term("a"); b = term("b")
    key("mod", "[")
    wait(lambda: win(a)["layout"]["pos_in_scrolling_layout"][0] == win(b)["layout"]["pos_in_scrolling_layout"][0])


@case("Mod+Minus ustunni toraytiradi")
def _():
    term("a"); term("b")
    w0 = focused()["layout"]["tile_size"][0]
    key("mod", "minus")
    wait(lambda: focused()["layout"]["tile_size"][0] < w0)


@case("Mod+Q yopadi va fokus qo'shni oynaga o'tadi")
def _():
    a = term("a"); b = term("b")
    key("mod", "q")
    wait(lambda: win(b) is None)
    wait(lambda: focused() and focused()["id"] == a)


@case("15 ta oyna ochilsa ham lenta ishlaydi")
def _():
    for n in range(15):
        term(f"w{n}")
    ok(len(windows()) == 15)
    for _n in range(14):
        key("mod", "h")
    wait(lambda: focused()["layout"]["pos_in_scrolling_layout"][0] == 1)


# ---------------------------------------------------------------------------------------
feature("floating", "Suzuvchi oynalar")


@case("Mod+Shift+Space suzuvchi qiladi va qaytaradi")
def _():
    i = term("a")
    key("mod", "shift", "space"); wait(lambda: win(i)["is_floating"])
    key("mod", "shift", "space"); wait(lambda: not win(i)["is_floating"])


@case("Mod+Alt+Space suzuvchi va oddiy oyna orasida o'tadi")
def _():
    a = term("a"); b = term("b")
    niri("move-window-to-floating", "--id", b)
    key("mod", "alt", "space"); wait(lambda: focused()["id"] == a)
    key("mod", "alt", "space"); wait(lambda: focused()["id"] == b)


@case("Suzuvchi oyna ustida Mod+Q faqat uni yopadi")
def _():
    a = term("a"); b = term("Save As")
    key("mod", "q")
    wait(lambda: win(b) is None)
    ok(win(a))


@case("Suzuvchi oyna bor joyda yangi oyna ochiladi")
def _():
    term("Save As")
    c = term("c")
    ok(win(c))
    ok(len(windows()) == 2)


@case("Suzuvchi oyna boshqa workspace'ga ko'chadi")
def _():
    i = term("Save As")
    key("mod", "ctrl", "2")
    wait(lambda: next(w for w in wsl() if w["id"] == win(i)["workspace_id"])["idx"] == 2)


@case("Mod+Ctrl+M oynani ekran chetigacha kengaytiradi")
def _():
    term("a")
    h0 = focused()["layout"]["tile_size"][1]
    key("mod", "ctrl", "m")
    wait(lambda: focused()["layout"]["tile_size"][1] > h0)


@case("Mod+Shift+= oyna balandligini oshiradi")
def _():
    a = term("a"); b = term("b")
    key("mod", "[")
    time.sleep(0.4)
    h0 = focused()["layout"]["tile_size"][1]
    key("mod", "shift", "equal")
    wait(lambda: focused()["layout"]["tile_size"][1] != h0)


@case("Mod+Ctrl+C ko'rinib turgan ustunlarni markazlaydi")
def _():
    term("a"); term("b")
    a = shot("c1", "0,50 1280x700")
    key("mod", "r")
    key("mod", "ctrl", "c")
    time.sleep(0.6)
    ok(shot("c2", "0,50 1280x700") != a)


@case("Mod+Ctrl+F bo'sh joyni to'ldiradi")
def _():
    term("a")
    niri("set-column-width", "30%")
    time.sleep(0.4)
    w0 = focused()["layout"]["tile_size"][0]
    key("mod", "ctrl", "f")
    wait(lambda: focused()["layout"]["tile_size"][0] > w0)


@case("Sichqoncha bilan Mod+sudrash oynani siljitadi")
def _():
    i = term("Save As")
    a = shot("m1")
    sh("ydotool key 125:1")
    drag(640, 400, 800, 500)
    sh("ydotool key 125:0")
    time.sleep(0.4)
    ok(shot("m2") != a, "oyna siljimadi")


# ---------------------------------------------------------------------------------------
feature("sticky", "Sticky oyna")


@case("Mod+S oynani suzuvchi va sticky qiladi")
def _():
    i = term("a")
    key("mod", "s")
    wait(lambda: i in st()["sticky"])
    wait(lambda: win(i)["is_floating"])
    toast("Sticky on")


@case("Workspace almashsa oyna ergashadi")
def _():
    i = term("a"); key("mod", "s"); wait(lambda: i in st()["sticky"])
    key("mod", "2")
    wait(lambda: next(w for w in wsl() if w["id"] == win(i)["workspace_id"])["idx"] == 2)


@case("Orqaga qaytganda ham ergashadi")
def _():
    i = term("a"); key("mod", "s"); wait(lambda: i in st()["sticky"])
    key("mod", "2"); time.sleep(0.5); key("mod", "1")
    wait(lambda: next(w for w in wsl() if w["id"] == win(i)["workspace_id"])["idx"] == 1)


@case("Mod+S qayta bosilsa o'chadi")
def _():
    i = term("a"); key("mod", "s"); wait(lambda: i in st()["sticky"])
    key("mod", "s")
    wait(lambda: i not in st()["sticky"])


@case("O'chirilgandan keyin ergashmaydi")
def _():
    i = term("a"); key("mod", "s"); wait(lambda: i in st()["sticky"])
    key("mod", "s"); wait(lambda: i not in st()["sticky"])
    ws0 = win(i)["workspace_id"]
    key("mod", "2"); time.sleep(0.6)
    ok(win(i)["workspace_id"] == ws0)


@case("Yopilgan oyna ro'yxatdan chiqadi")
def _():
    i = term("a"); key("mod", "s"); wait(lambda: i in st()["sticky"])
    niri("close-window", "--id", i)
    wait(lambda: i not in st()["sticky"])


@case("Oyna yo'q joyda Mod+S xato bermaydi")
def _():
    key("mod", "s")
    time.sleep(0.3)
    ok(st()["sticky"] == [])


@case("Ikkita sticky oyna birga ergashadi")
def _():
    a = term("a"); key("mod", "s"); wait(lambda: a in st()["sticky"])
    b = term("b"); key("mod", "s"); wait(lambda: b in st()["sticky"])
    key("mod", "2")
    # Bo'shagan workspace yo'qolishi mumkin, shuning uchun raqam emas, faol workspace tekshiriladi.
    wait(lambda: all(win(i)["workspace_id"] == next(w["id"] for w in wsl() if w["is_active"]) for i in (a, b)))


@case("Sticky oyna overview'dan keyin ham joyida")
def _():
    i = term("a"); key("mod", "s"); wait(lambda: i in st()["sticky"])
    key("mod", "o"); time.sleep(0.4); key("mod", "o"); time.sleep(0.4)
    ok(win(i) and i in st()["sticky"])


@case("Ketma-ket tez almashtirishda oyna yo'qolmaydi")
def _():
    i = term("a"); key("mod", "s"); wait(lambda: i in st()["sticky"])
    for n in (2, 1, 2, 1, 2, 1):
        key("mod", str(n))
    time.sleep(0.8)
    wait(lambda: next(w for w in wsl() if w["id"] == win(i)["workspace_id"])["idx"] == 1)


# ---------------------------------------------------------------------------------------
feature("alttab", "Alt+Tab")


def alt_tab(*extra, release=True):
    sh("ydotool key 56:1")
    for k in extra:
        sh(f"ydotool key {KEYC[k]}:1 {KEYC[k]}:0")
        time.sleep(0.25)
    time.sleep(0.25)
    if release:
        sh("ydotool key 56:0")
        time.sleep(0.5)


@case("Alt+Tab oldingi oynaga o'tadi")
def _():
    a = term("a"); time.sleep(0.7); b = term("b"); time.sleep(0.7)
    alt_tab("tab")
    wait(lambda: focused()["id"] == a)


@case("Ikki marta bosish oldingidan oldingisiga o'tadi")
def _():
    a = term("a"); time.sleep(0.7); b = term("b"); time.sleep(0.7); c = term("c"); time.sleep(0.7)
    alt_tab("tab", "tab")
    wait(lambda: focused()["id"] == a)


@case("Yagona oynada xato bermaydi")
def _():
    a = term("a"); time.sleep(0.7)
    alt_tab("tab")
    ok(focused()["id"] == a)


@case("Oyna yo'q joyda xato bermaydi")
def _():
    alt_tab("tab")
    ok(not windows())


@case("Esc bekor qiladi")
def _():
    a = term("a"); time.sleep(0.7); b = term("b"); time.sleep(0.7)
    alt_tab("tab", "esc")
    ok(focused()["id"] == b)


@case("Boshqa workspace'dagi oynaga ham o'tadi")
def _():
    a = term("a"); time.sleep(0.7)
    niri("focus-workspace", 2); b = term("b"); time.sleep(0.7)
    alt_tab("tab")
    wait(lambda: focused()["id"] == a)
    wait(lambda: active_ws() == 1)


@case("Alt+Tab ochiq turganda oynalar ko'rinadi")
def _():
    term("a"); time.sleep(0.7); term("b"); time.sleep(0.7)
    base = shot("a0")
    alt_tab("tab", release=False)
    time.sleep(0.4)
    img = shot("a1")
    sh("ydotool key 56:0")
    ok(img != base)


@case("Shift bilan teskari yo'nalishda yuradi")
def _():
    a = term("a"); time.sleep(0.7); b = term("b"); time.sleep(0.7); c = term("c"); time.sleep(0.7)
    sh("ydotool key 56:1 42:1 15:1 15:0 42:0")
    time.sleep(0.5)
    sh("ydotool key 56:0")
    time.sleep(0.5)
    wait(lambda: focused()["id"] in (a, b), 3, "teskari yo'nalish ishlamadi")


@case("Yopilgan oyna ro'yxatda qolmaydi")
def _():
    a = term("a"); time.sleep(0.7); b = term("b"); time.sleep(0.7); c = term("c"); time.sleep(0.7)
    niri("close-window", "--id", b)
    time.sleep(0.5)
    alt_tab("tab")
    ok(focused()["id"] in (a, c))


@case("Alt+Tab'dan keyin klaviatura shu oynaga ishlaydi")
def _():
    a = term("a"); time.sleep(0.7); b = term("b"); time.sleep(0.7)
    alt_tab("tab")
    wait(lambda: focused()["id"] == a)
    key("mod", "q")
    wait(lambda: win(a) is None)
    ok(win(b))


# ---------------------------------------------------------------------------------------
feature("scratch", "Scratchpad terminal")


def scratch():
    return next((w for w in windows() if w["app_id"] == "niri-desk-scratch"), None)


def tmuxc(*a):
    return sh(["tmux", "-L", "niri-desk", *a])


@case("Mod+` ochadi, suzib turadi va fokus oladi")
def _():
    tmuxc("kill-server")
    key("mod", "grave")
    w = wait(scratch, 6)
    ok(w["is_floating"] and w["is_focused"], w)


@case("Fokusda turganda qayta bosish yopadi")
def _():
    key("mod", "grave"); wait(scratch, 6); time.sleep(0.3)
    key("mod", "grave")
    wait(lambda: scratch() is None)


@case("Yopilganda sessiya tirik qoladi")
def _():
    key("mod", "grave"); wait(scratch, 6); time.sleep(0.4)
    key("mod", "grave"); wait(lambda: scratch() is None)
    ok(tmuxc("has-session", "-t", "scratch").returncode == 0)


@case("Qayta ochilganda oldingi matn turadi")
def _():
    tmuxc("kill-server")
    key("mod", "grave"); wait(scratch, 6); time.sleep(1.0)
    tmuxc("send-keys", "-t", "scratch", "echo sessiya-belgisi", "Enter")
    time.sleep(0.5)
    key("mod", "grave"); wait(lambda: scratch() is None)
    key("mod", "grave"); wait(scratch, 6); time.sleep(0.6)
    ok("sessiya-belgisi" in tmuxc("capture-pane", "-p", "-t", "scratch").stdout)


@case("Fokusda bo'lmasa bosish fokusni qaytaradi")
def _():
    key("mod", "grave"); s = wait(scratch, 6); time.sleep(0.3)
    a = term("a")
    wait(lambda: focused()["id"] == a)
    key("mod", "grave")
    wait(lambda: focused()["id"] == s["id"])
    ok(len([w for w in windows() if w["app_id"] == "niri-desk-scratch"]) == 1)


@case("Mod+Q bilan yopilsa ham sessiya tirik")
def _():
    key("mod", "grave"); wait(scratch, 6); time.sleep(0.4)
    key("mod", "q")
    wait(lambda: scratch() is None)
    ok(tmuxc("has-session", "-t", "scratch").returncode == 0)


@case("Boshqa workspace'da ham o'sha sessiya ochiladi")
def _():
    tmuxc("kill-server")
    term("a")
    key("mod", "grave"); wait(scratch, 6); time.sleep(0.8)
    tmuxc("send-keys", "-t", "scratch", "echo ws-belgi", "Enter"); time.sleep(0.4)
    key("mod", "grave"); wait(lambda: scratch() is None)
    key("mod", "2"); wait(lambda: active_ws() == 2)
    key("mod", "grave"); s = wait(scratch, 6); time.sleep(0.5)
    ok(next(w for w in wsl() if w["id"] == s["workspace_id"])["idx"] == 2)
    ok("ws-belgi" in tmuxc("capture-pane", "-p", "-t", "scratch").stdout)


@case("Tez-tez bosilganda ikkinchi nusxa ochilmaydi")
def _():
    for _n in range(5):
        key("mod", "grave")
        time.sleep(0.25)
    time.sleep(1.5)
    ok(len([w for w in windows() if w["app_id"] == "niri-desk-scratch"]) <= 1)


@case("Shell'dan exit qilinganda oyna yopiladi va keyingisi yangi")
def _():
    tmuxc("kill-server")
    key("mod", "grave"); wait(scratch, 6); time.sleep(0.8)
    tmuxc("send-keys", "-t", "scratch", "exit", "Enter")
    wait(lambda: scratch() is None, 6)
    key("mod", "grave"); wait(scratch, 6)


@case("Klavishi o'zgartirilsa yangi klavish ishlaydi")
def _():
    settings(binds__scratch="Mod+Y")
    key("mod", "y")
    wait(scratch, 6)


# ---------------------------------------------------------------------------------------
feature("raise", "Dastur oynasiga tez o'tish")

RAISE = str(HOME / ".local/bin/niri-desk-raise")


def do_raise(pattern, cls="rtest"):
    return sh([RAISE, pattern, "sh", "-c", f"setsid kitty --class {cls} --title {cls} sh -c 'sleep 900' >/dev/null 2>&1 &"])


def rcount(cls="rtest"):
    return [w for w in windows() if w["app_id"] == cls]


@case("Dastur yopiq bo'lsa ochadi")
def _():
    do_raise("^rtest$")
    wait(lambda: len(rcount()) == 1, 6)


@case("Ochiq bo'lsa yangisini ochmaydi, unga o'tadi")
def _():
    do_raise("^rtest$"); wait(lambda: len(rcount()) == 1, 6)
    a = term("a")
    do_raise("^rtest$"); time.sleep(0.5)
    ok(len(rcount()) == 1)
    wait(lambda: focused()["app_id"] == "rtest")


@case("Boshqa workspace'dagi oynaga o'tkazadi")
def _():
    do_raise("^rtest$"); wait(lambda: len(rcount()) == 1, 6)
    niri("focus-workspace", 2)
    do_raise("^rtest$")
    wait(lambda: active_ws() == 1)


@case("Harf katta-kichikligi farq qilmaydi")
def _():
    do_raise("^rtest$"); wait(lambda: len(rcount()) == 1, 6)
    term("a")
    do_raise("^RTEST$")
    wait(lambda: focused()["app_id"] == "rtest")
    ok(len(rcount()) == 1)


@case("Noto'g'ri regex xato qaytaradi va oyna ochmaydi")
def _():
    r = sh([RAISE, "(((", "kitty"])
    ok(r.returncode != 0, r)
    ok(not windows())


@case("Dastur o'rnatilmagan bo'lsa shell buzilmaydi")
def _():
    r = sh([RAISE, "^yoq$", "bunday-dastur-yoq"])
    ok(r.returncode != 0)
    ok(st() is not None)


@case("Bir nechta nusxadan oxirgi ishlatilganiga o'tadi")
def _():
    a = term("r1", "rtest"); time.sleep(0.8); b = term("r2", "rtest"); time.sleep(0.8)
    c = term("boshqa"); time.sleep(0.8)
    do_raise("^rtest$")
    wait(lambda: focused()["id"] == b)


@case("Mod+E fayl menejerini ochadi")
def _():
    key("mod", "e")
    wait(lambda: any("autilus" in (w["app_id"] or "") for w in windows()), 8)


@case("Mod+E ikkinchi marta yangisini ochmaydi")
def _():
    key("mod", "e")
    wait(lambda: any("autilus" in (w["app_id"] or "") for w in windows()), 8)
    term("a"); key("mod", "e"); time.sleep(0.8)
    ok(len([w for w in windows() if "autilus" in (w["app_id"] or "")]) == 1)
    wait(lambda: "autilus" in focused()["app_id"])


@case("Burp o'rnatilmagan bo'lsa Mod+Shift+B xato bermaydi")
def _():
    if shutil.which("burpsuite"):
        raise Skip("burpsuite o'rnatilgan")
    key("mod", "shift", "b")
    time.sleep(0.6)
    ok(st() is not None and not windows())


# ---------------------------------------------------------------------------------------
feature("launcher", "Qidiruv oynasi")


@case("Mod+Space ochadi, Esc yopadi")
def _():
    launcher()
    key("esc")
    wait(lambda: st()["popup"] == "")


@case("Mod+Space qayta bosilsa yopiladi")
def _():
    launcher()
    key("mod", "space")
    wait(lambda: st()["popup"] == "")


@case("Nomi bilan dastur topiladi va birinchi turadi")
def _():
    launcher("kit")
    r = st()["rows"]
    ok(r and r[0].startswith("Apps|") and "kitty" in r[0].lower(), r)


@case("Enter dasturni ochadi va oyna yopiladi")
def _():
    launcher("kitty")
    key("enter")
    wait(lambda: any(w["app_id"] == "kitty" for w in windows()), 6)
    wait(lambda: st()["popup"] == "")


@case("Topilmaydigan so'z bo'sh ro'yxat beradi, Enter hech narsa qilmaydi")
def _():
    launcher("zzxqwjjj")
    ok(st()["rows"] == [])
    key("enter")
    time.sleep(0.4)
    ok(not windows())
    key("esc")


@case("Pastga va tepaga tugmalari tanlovni siljitadi, chetdan chiqmaydi")
def _():
    launcher()
    key("up")
    ok(st()["selected"] == 0)
    key("down"); key("down")
    ok(st()["selected"] == 2)
    n = len(st()["rows"])
    for _n in range(n + 3):
        key("down")
    ok(st()["selected"] == n - 1)
    key("esc")


@case("Oyna tashqarisiga bosish yopadi")
def _():
    launcher()
    click(60, 700)
    wait(lambda: st()["popup"] == "")


@case("Qatorni sichqoncha bilan bosish ochadi")
def _():
    launcher("kitty")
    click(640, 257)
    wait(lambda: any(w["app_id"] == "kitty" for w in windows()), 6)


@case("Ochiq oyna nomi bilan unga o'tadi")
def _():
    a = term("maxsus-oyna"); b = term("boshqa")
    launcher("maxsus-oyna")
    wait(lambda: row("Open windows"))
    key("enter")
    wait(lambda: focused()["id"] == a)


@case("Aniq moslik bo'lsa taxminiy dastur chiqmaydi")
def _():
    sh("cliphist wipe")
    launcher("color")
    r = st()["rows"]
    ok(r and r[0].startswith("Actions|"), r)
    key("esc")


# ---------------------------------------------------------------------------------------
feature("calc", "Qidiruvda hisoblash")


def calc(q):
    launcher(q)
    return row("Calculator")


@case("2+2*3 amal tartibini to'g'ri hisoblaydi")
def _():
    ok(calc("2+2*3") == ["8"])
    key("esc")


@case("=2^10 ishlaydi")
def _():
    ok(calc("=2^10") == ["1024"])
    key("esc")


@case("Qavslar ishlaydi")
def _():
    ok(calc("(1+2)*3") == ["9"])
    key("esc")


@case("Kasr sonlar ishlaydi")
def _():
    ok(calc("0.1+0.2") == ["0.3"])
    key("esc")


@case("Nolga bo'lish xato bermaydi")
def _():
    ok("1/0" not in calc("1/0"))
    ok(st() is not None)
    key("esc")


@case("Tugallanmagan ifoda shell'ni buzmaydi")
def _():
    ok(calc("2+") == [])
    key("esc")


@case("Enter natijani nusxalaydi")
def _():
    calc("6*7")
    key("enter")
    wait(lambda: clip_text() == "42")


@case("IP manzil hisob deb qabul qilinmaydi")
def _():
    ok(calc("10.10.11.42") == [])
    key("esc")


@case("Kod yuborilsa bajarilmaydi")
def _():
    r = calc("=process.exit(1)")
    ok(r in ([], ["incomplete expression"]), r)
    ok(st() is not None)
    key("esc")


@case("Juda katta son xato bermaydi")
def _():
    calc("=9^9^9")
    ok(st() is not None)
    key("esc")


# ---------------------------------------------------------------------------------------
feature("encode", "Qidiruvda kodlash")


def enc(q):
    launcher(q)
    return row("Encoding")


@case("b64 kodlaydi")
def _():
    ok(enc("b64 admin:pass") == ["YWRtaW46cGFzcw=="])
    key("esc")


@case("b64d ochadi")
def _():
    ok(enc("b64d YWRtaW46cGFzcw==") == ["admin:pass"])
    key("esc")


@case("url kodlaydi")
def _():
    ok(enc("url a b&c") == ["a%20b%26c"])
    key("esc")


@case("urld ochadi")
def _():
    ok(enc("urld a%20b") == ["a b"])
    key("esc")


@case("hex kodlaydi")
def _():
    ok(enc("hex salom") == ["73616c6f6d"])
    key("esc")


@case("hexd ochadi")
def _():
    ok(enc("hexd 73616c6f6d") == ["salom"])
    key("esc")


@case("md5 hisoblaydi")
def _():
    ok(enc("md5 admin") == ["21232f297a57a5a743894a0e4a801fc3"])
    key("esc")


@case("Noto'g'ri base64 xato haqida aytadi")
def _():
    launcher("b64d @@@")
    ok(st()["rows"] == ["Encoding|Could not decode"], st()["rows"])
    key("esc")


@case("Enter natijani nusxalaydi")
def _():
    enc("b64 salom")
    key("enter")
    wait(lambda: clip_text() == "c2Fsb20=")


@case("Noto'g'ri urld shell'ni buzmaydi")
def _():
    launcher("urld %zz")
    ok(st() is not None)
    key("esc")


# ---------------------------------------------------------------------------------------
feature("command", "Qidiruvda buyruq va internet")


def run_cmd(c):
    launcher(">" + c)
    key("enter")
    time.sleep(0.8)


@case(">buyruq terminal ochib ishga tushiradi")
def _():
    run_cmd("touch /tmp/nd-a.flag")
    wait(lambda: os.path.exists("/tmp/nd-a.flag"), 5)


@case("Quvur va belgilar buzilmaydi")
def _():
    run_cmd("echo salom | tr a-z A-Z > /tmp/nd-b.flag")
    wait(lambda: Path("/tmp/nd-b.flag").exists() and Path("/tmp/nd-b.flag").read_text().strip() == "SALOM", 5)


@case("Qo'shtirnoqli buyruq ishlaydi")
def _():
    run_cmd("echo 'a b' > /tmp/nd-c.flag")
    wait(lambda: Path("/tmp/nd-c.flag").exists() and Path("/tmp/nd-c.flag").read_text().strip() == "a b", 5)


@case("Xato buyruqda terminal ochiq qoladi")
def _():
    run_cmd("bunday-buyruq-yoq")
    wait(lambda: any(w["app_id"] == "kitty" for w in windows()), 5)


@case("Enter bosilganda terminal yopiladi")
def _():
    run_cmd("true")
    wait(lambda: any(w["app_id"] == "kitty" for w in windows()), 5)
    time.sleep(0.6)
    key("enter")
    wait(lambda: not windows(), 5)


@case("Bo'sh > hech narsa ishga tushirmaydi")
def _():
    launcher(">")
    key("enter")
    time.sleep(0.5)
    ok(not windows())
    sh("true")


@case("Bo'sh joyli > ham xavfsiz")
def _():
    launcher(">   ")
    key("enter")
    time.sleep(0.5)
    ok(not [w for w in windows() if w["app_id"] == "kitty"], windows())


@case("?qidiruv qatorini ko'rsatadi")
def _():
    launcher("?sql injection")
    ok(row("Web") == ["sql injection"])
    key("esc")


@case("Bo'sh ? hech narsa ochmaydi")
def _():
    launcher("?")
    ok(row("Web") == [])
    key("esc")


@case("Faqat buyruq qatori chiqadi, boshqalar aralashmaydi")
def _():
    launcher(">kitty")
    ok(st()["rows"] == ["Command|kitty"], st()["rows"])
    key("esc")


# ---------------------------------------------------------------------------------------
feature("lab", "Pentest nishoni va lab holati")


def lab_wait(fn):
    wait(fn, 40)


@case("target buyrug'i nishonni yozadi")
def _():
    launcher("target 10.10.11.42")
    key("enter")
    wait(lambda: st()["target"] == "10.10.11.42", 5)


@case("Xavfli matn nishon sifatida qabul qilinmaydi")
def _():
    launcher("target $(touch /tmp/nd-x.flag)")
    ok(row("Pentest") == [])
    key("esc")
    ok(sh([str(HOME / ".local/bin/niri-desk-target"), "a;b"]).returncode != 0)
    ok(not os.path.exists("/tmp/nd-x.flag"))


@case("Domen nomi ham nishon bo'la oladi")
def _():
    launcher("target hack.example.com")
    key("enter")
    wait(lambda: st()["target"] == "hack.example.com", 5)


@case("Port ochilsa holat yangilanadi")
def _():
    settings(lab__target="127.0.0.1")
    subprocess.Popen(["python3", "-m", "http.server", "8080", "--bind", "127.0.0.1"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd="/tmp")
    try:
        ipc("dashboard")
        wait(lambda: 8080 in st()["labOpen"], 12)
    finally:
        sh("pkill -f 'http.server 8080'")


@case("Port yopilsa holat qaytadi")
def _():
    ipc("dashboard")
    wait(lambda: 8080 not in st()["labOpen"], 12)


@case("Bo'sh nishonda dashboard buzilmaydi")
def _():
    settings(lab__target="")
    ipc("dashboard")
    time.sleep(0.8)
    ok(st()["popup"] == "dashboard")


@case("VPN interfeysi paydo bo'lsa manzili ko'rinadi")
def _():
    sh("sudo -n ip link add tun0 type dummy; sudo -n ip addr add 10.8.0.5/24 dev tun0; sudo -n ip link set tun0 up")
    try:
        ipc("dashboard")
        wait(lambda: st()["vpn"] == "10.8.0.5", 12)
    finally:
        sh("sudo -n ip link del tun0")


@case("Dashboard'da nishonni bosish nusxalaydi")
def _():
    settings(lab__target="10.1.2.3")
    ipc("dashboardTab", "2")
    time.sleep(1.0)
    click(545, 73)
    wait(lambda: clip_text() == "10.1.2.3", 4)


@case("Skript noto'g'ri portni e'tiborsiz qoldiradi")
def _():
    r = sh([str(HOME / ".local/bin/niri-desk-lab"), "127.0.0.1", "tun0", "abc", "99999"])
    d = json.loads(r.stdout)
    ok(d["open"] == [], d)


@case("Portlar ro'yxati bo'sh bo'lsa ham ishlaydi")
def _():
    settings(lab__ports=[])
    ipc("dashboard")
    time.sleep(1.0)
    ok(st()["labOpen"] == [])


# ---------------------------------------------------------------------------------------
feature("clipboard", "Clipboard tarixi")


def copy(text):
    p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True)
    p.communicate(text)
    time.sleep(0.5)


@case("Nusxalangan matn tarixda ko'rinadi")
def _():
    copy("clip-birinchi")
    key("mod", "v")
    wait(lambda: "clip-birinchi" in row("Clipboard"), 4)
    key("esc")


@case("Mod+V faqat clipboard'ni ko'rsatadi")
def _():
    copy("clip-ikki")
    key("mod", "v")
    wait(lambda: st()["rows"])
    ok(all(r.startswith("Clipboard|") for r in st()["rows"]), st()["rows"])
    key("esc")


@case("Yozish tarixni filtrlaydi")
def _():
    copy("olma-belgi"); copy("nok-belgi")
    key("mod", "v"); wait(lambda: st()["rows"]); time.sleep(0.5)
    typ("nok-")
    wait(lambda: st()["rows"] and "nok-belgi" in st()["rows"][0], 3)
    key("esc")


@case("Enter tanlangan matnni qaytaradi")
def _():
    copy("eski-matn"); copy("yangi-matn")
    key("mod", "v"); wait(lambda: st()["rows"]); time.sleep(0.5)
    typ("eski-matn")
    time.sleep(0.3)
    rows = st()["rows"]
    key("enter")
    wait(lambda: clip_text() == "eski-matn", 4, f"{clip_text()!r} qatorlar={rows!r}")


@case("Xavfli belgili matn buyruq bo'lib ishlamaydi")
def _():
    bad = "$(touch /tmp/nd-pwn.flag);`touch /tmp/nd-pwn.flag`"
    copy(bad)
    key("mod", "v"); wait(lambda: st()["rows"]); time.sleep(0.5)
    key("enter")
    wait(lambda: clip_text() == bad, 4)
    time.sleep(0.4)
    ok(not os.path.exists("/tmp/nd-pwn.flag"))


@case("Ko'p qatorli matn to'liq qaytadi")
def _():
    text = "bir\nikki\nuch"
    copy(text)
    key("mod", "v"); wait(lambda: st()["rows"]); time.sleep(0.5)
    first = st()["rows"][0]
    key("enter")
    time.sleep(0.6)
    ok(clip_text() == text, f"{clip_text()!r} qator={first!r}")


@case("Kirill va o'zbek harflari buzilmaydi")
def _():
    copy("салом o'zbek")
    key("mod", "v"); wait(lambda: st()["rows"]); time.sleep(0.5)
    key("enter")
    wait(lambda: clip_text() == "салом o'zbek", 4)


@case("Mod+V ikkinchi bosish yopadi")
def _():
    key("mod", "v"); wait(lambda: st()["popup"] == "clipboard")
    key("mod", "v"); wait(lambda: st()["popup"] == "")


@case("Tarix bo'sh bo'lsa xato bermaydi")
def _():
    sh("cliphist wipe")
    time.sleep(0.3)
    key("mod", "v"); wait(lambda: st()["popup"] == "clipboard")
    time.sleep(0.4)
    ok(st()["rows"] == [])
    key("enter")
    time.sleep(0.2)
    key("esc")


@case("Juda uzun matn oynani buzmaydi")
def _():
    copy("x" * 20000)
    key("mod", "v"); wait(lambda: st()["rows"]); time.sleep(0.5)
    ok(st()["popup"] == "clipboard")
    key("esc")


# ---------------------------------------------------------------------------------------
feature("wallpaper", "Fon rasmi va ranglar")

WP = str(HOME / ".local/bin/niri-desk-wallpaper")
WDIR = HOME / "Pictures/Wallpapers"


def picker():
    key("mod", "w")
    wait(lambda: st()["popup"] == "wallpapers", 3)
    wait(lambda: st()["pickerFiles"] > 0, 3)
    time.sleep(0.5)


def wp_name():
    return (STATE / "wallpaper").resolve().name


def set_wp(name):
    sh([WP, str(WDIR / name)], timeout=20)
    time.sleep(0.3)


@case("Mod+W ochadi, Esc yopadi")
def _():
    picker()
    key("esc")
    wait(lambda: st()["popup"] == "")


@case("Hozirgi fon tanlangan holda ochiladi")
def _():
    set_wp("ormon.jpg")
    picker()
    ok(st()["pickerSelected"] == 1, st()["pickerSelected"])
    key("esc")


@case("O'ng va chap tugmalar chetdan chiqmaydi")
def _():
    set_wp("moviy-tun.jpg")
    picker()
    key("left")
    ok(st()["pickerSelected"] == 0)
    for _n in range(8):
        key("right")
    ok(st()["pickerSelected"] == st()["pickerFiles"] - 1)
    key("esc")


@case("Enter fonni almashtiradi")
def _():
    set_wp("moviy-tun.jpg")
    picker(); key("right"); key("enter")
    wait(lambda: wp_name() == "ormon.jpg", 8)


@case("Fon almashganda rang ham o'zgaradi")
def _():
    set_wp("moviy-tun.jpg")
    a = wait(lambda: st()["accent"])
    time.sleep(0.7)
    a = st()["accent"]
    set_wp("qizilqum.jpg")
    wait(lambda: st()["accent"] != a, 5)


@case("Kartani bosish fonni almashtiradi")
def _():
    set_wp("moviy-tun.jpg")
    picker()
    click(820, 400)
    wait(lambda: wp_name() == "qizilqum.jpg", 8)


@case("Yo'q fayl xato qaytaradi, joriy fon qoladi")
def _():
    set_wp("ormon.jpg")
    r = sh([WP, "/tmp/bunday-rasm-yoq.png"])
    ok(r.returncode != 0)
    ok(wp_name() == "ormon.jpg")


@case("Nomida bo'sh joy bor rasm ishlaydi")
def _():
    p = WDIR / "bo'sh joyli nom.jpg"
    shutil.copy(WDIR / "shafaq.jpg", p)
    try:
        r = sh([WP, str(p)], timeout=20)
        ok(r.returncode == 0, r.stderr)
        ok(wp_name() == p.name)
    finally:
        set_wp("moviy-tun.jpg")
        p.unlink()


@case("Rasm bo'lmagan fayl joriy holatni buzmaydi")
def _():
    set_wp("ormon.jpg")
    a = st()["accent"]
    p = Path("/tmp/nd-notimage.jpg")
    p.write_text("bu rasm emas")
    r = sh([WP, str(p)])
    ok(r.returncode != 0, "xato qaytarmadi")
    ok(wp_name() == "ormon.jpg", wp_name())


@case("Papka bo'sh bo'lsa xabar chiqadi")
def _():
    Path("/tmp/nd-empty").mkdir(exist_ok=True)
    settings(wallpaperDir="/tmp/nd-empty")
    key("mod", "w")
    wait(lambda: st()["popup"] == "wallpapers", 3)
    time.sleep(0.6)
    ok(st()["pickerFiles"] == 0, st()["pickerFiles"])
    key("esc")


# ---------------------------------------------------------------------------------------
feature("dashboard", "Dashboard")


def is_top_exclusive():
    return any(l["namespace"] == "niri-desk-top" and l["keyboard_interactivity"] == "Exclusive" for l in nj("layers"))


@case("Mod+D ochadi va klaviaturani oladi")
def _():
    key("mod", "d")
    wait(lambda: st()["popup"] == "dashboard")
    wait(is_top_exclusive)


@case("Esc yopadi va fokus oynaga qaytadi")
def _():
    a = term("a")
    key("mod", "d"); wait(is_top_exclusive)
    key("esc")
    wait(lambda: st()["popup"] == "")
    wait(lambda: focused() and focused()["id"] == a)


@case("Soatni bosish ochadi")
def _():
    click(640, 20)
    wait(lambda: st()["popup"] == "dashboard")


@case("Tashqariga bosish yopadi")
def _():
    click(640, 20); wait(lambda: st()["popup"] == "dashboard")
    time.sleep(0.5)
    click(640, 650)
    wait(lambda: st()["popup"] == "")


@case("Ichiga bosish yopmaydi")
def _():
    click(640, 20); wait(lambda: st()["popup"] == "dashboard")
    time.sleep(0.5)
    click(1000, 280)
    time.sleep(0.3)
    ok(st()["popup"] == "dashboard")


@case("Dashboard ochiq turganda boshqa panel ochilsa almashadi")
def _():
    key("mod", "d"); wait(lambda: st()["popup"] == "dashboard")
    key("mod", "c")
    wait(lambda: st()["popup"] == "control")


@case("Xabar dashboard yopilguncha kutadi")
def _():
    key("mod", "d"); wait(lambda: st()["popup"] == "dashboard")
    ipc("toast", "Kutish", "sinov")
    time.sleep(4.5)
    ok(st()["toast"] == "Kutish", st()["toast"])
    key("esc")


@case("CPU halqasini bosish monitor ochadi")
def _():
    ipc("dashboardTab", "1")
    wait(lambda: st()["popup"] == "dashboard" and st()["dashTab"] == 1)
    time.sleep(0.5)
    click(703, 124)
    w = wait(lambda: next(x for x in windows() if x["app_id"] == "niri-desk-tool"), 6)
    wait(lambda: sh("pgrep -x btop").returncode == 0, 4)
    # btop kamida 80 ustun talab qiladi: kitty katagi taxminan 9.6 piksel.
    ok(w["layout"]["window_size"][0] >= 800, w["layout"])
    sh("pkill -x btop")


@case("Ob-havo o'chirilsa ko'rinmaydi, qolgani ishlaydi")
def _():
    settings(weather__enabled=False)
    key("mod", "d")
    wait(lambda: st()["popup"] == "dashboard")
    time.sleep(0.5)
    ok(st()["popup"] == "dashboard")


@case("Tez ochib-yopishda holat chalkashmaydi")
def _():
    for _n in range(6):
        ipc("dashboard")
        time.sleep(0.05)
    time.sleep(0.6)
    ok(st()["popup"] == "")


# ---------------------------------------------------------------------------------------
feature("control", "Boshqaruv paneli")


def open_control():
    click(1215, 27)
    wait(lambda: st()["popup"] == "control", 3)
    time.sleep(0.5)


def sess_y():
    # Sessiya tugmalari panelning eng pastida: xabar yo'q paytdagi joyi.
    return 52 + st()["controlHeight"] - 16 - 19


def toggle_x(i):
    # Panel 400 kenglikda, o'ng chetdan 14. Oltita tugma 7 oraliq bilan.
    left = 1280 - 14 - 400 + 16
    w = (368 - 35) / 6
    return int(left + i * (w + 7) + w / 2)


@case("Holat tugmasini bosish ochadi")
def _():
    open_control()


@case("Mod+C ochadi, Esc yopadi")
def _():
    key("mod", "c"); wait(lambda: st()["popup"] == "control")
    key("esc"); wait(lambda: st()["popup"] == "")


@case("Tashqariga bosish yopadi")
def _():
    open_control()
    click(300, 650)
    wait(lambda: st()["popup"] == "")


@case("Kofe tugmasi ishlaydi va xabar chiqaradi")
def _():
    open_control()
    click(toggle_x(3), 91)
    wait(lambda: st()["caffeine"])
    toast("Caffeine on")


@case("Tungi rejim wlsunset'ni boshqaradi")
def _():
    open_control()
    click(toggle_x(4), 91)
    wait(lambda: sh("pgrep -x wlsunset").returncode == 0, 4)
    click(toggle_x(4), 91)
    wait(lambda: sh("pgrep -x wlsunset").returncode != 0, 4)


@case("'Bezovta qilmang' xabarlarni to'xtatadi")
def _():
    open_control()
    click(toggle_x(5), 91)
    wait(lambda: st()["dnd"])
    key("esc")
    sh(["notify-send", "Jim xabar"])
    time.sleep(0.8)
    ok(st()["toast"] == "", st()["toast"])
    ok("Jim xabar" in st()["history"])


@case("VPN buyrug'i yo'q bo'lsa qalqon tugmasi ishlamaydi")
def _():
    open_control()
    click(toggle_x(2), 91)
    time.sleep(0.4)
    ok(st()["popup"] == "control" and st()["error"] == "")


@case("VPN buyrug'i berilsa qalqon ishga tushiradi")
def _():
    settings(vpn__up="touch /tmp/nd-vpn.flag", vpn__down="true")
    open_control()
    click(toggle_x(2), 91)
    wait(lambda: os.path.exists("/tmp/nd-vpn.flag"), 4)


@case("Chiqish tugmasi birinchi bosishda bajarilmaydi")
def _():
    open_control()
    click(1065, sess_y())
    toast("Confirm", 3)
    ok(sh("pgrep -x niri").returncode == 0)


@case("Ochiq panelda Mod+Q oynani yopmaydi, panel saqlanadi")
def _():
    a = term("a")
    open_control()
    ok(win(a) is not None)
    ok(st()["popup"] == "control")


# ---------------------------------------------------------------------------------------
feature("audio", "Ovoz")


def vol():
    m = re.search(r"([\d.]+)", sh("wpctl get-volume @DEFAULT_AUDIO_SINK@").stdout)
    return float(m.group(1))


def setvol(v):
    sh(f"wpctl set-volume @DEFAULT_AUDIO_SINK@ {v}; wpctl set-mute @DEFAULT_AUDIO_SINK@ 0")
    time.sleep(0.3)


@case("Ovoz tugmasi oshiradi")
def _():
    setvol(0.5)
    key("volup")
    wait(lambda: vol() > 0.5)


@case("Ovoz tugmasi kamaytiradi")
def _():
    setvol(0.5)
    key("voldown")
    wait(lambda: vol() < 0.5)


@case("100% dan oshmaydi")
def _():
    setvol(0.98)
    for _n in range(3):
        key("volup")
    time.sleep(0.4)
    ok(vol() <= 1.0, vol())


@case("0% dan pastga tushmaydi")
def _():
    setvol(0.02)
    for _n in range(3):
        key("voldown")
    time.sleep(0.4)
    ok(vol() == 0, vol())
    setvol(0.5)


@case("O'chirish tugmasi ishlaydi va qaytaradi")
def _():
    setvol(0.5)
    key("mute"); wait(lambda: st()["muted"])
    key("mute"); wait(lambda: not st()["muted"])


@case("Orolda to'g'ri foiz ko'rinadi")
def _():
    setvol(0.5)
    time.sleep(2.0)
    key("volup")
    wait(lambda: st()["toast"] == f"Volume {round(vol()*100)}%", 3)


@case("Ketma-ket bosishda xabar navbatga to'planmaydi")
def _():
    setvol(0.3)
    for _n in range(8):
        key("volup")
    time.sleep(0.2)
    ok(st()["queue"] == 0, st()["queue"])


@case("Slider ovozni o'zgartiradi")
def _():
    setvol(0.2)
    open_control()
    click(1280 - 14 - 400 + 16 + 31 + 200, 139)
    wait(lambda: abs(vol() - 0.2) > 0.1, 3)


@case("Sliderni sudrash oxirigacha yetadi")
def _():
    setvol(0.2)
    open_control()
    drag(1280 - 14 - 400 + 16 + 40, 139, 1270, 139)
    wait(lambda: vol() >= 0.99, 3)
    setvol(0.5)


@case("Qurilma almashganda shell buzilmaydi")
def _():
    r = sh("pactl load-module module-null-sink sink_name=NdTest sink_properties=device.description=Sinov")
    mod = r.stdout.strip()
    try:
        sh("wpctl set-default $(wpctl status | grep -m1 Sinov | grep -oE '[0-9]+' | head -1)")
        time.sleep(0.6)
        ok(st()["volume"] >= 0)
    finally:
        sh(f"pactl unload-module {mod}")
        time.sleep(0.5)
    ok(st() is not None)


# ---------------------------------------------------------------------------------------
feature("notifications", "Xabarlar")


def notify(*a):
    sh(["notify-send", *a])
    time.sleep(0.25)


@case("Xabar orolda chiqadi")
def _():
    notify("Salom", "matn")
    toast("Salom")


@case("Vaqti o'tgach yo'qoladi")
def _():
    notify("Vaqtli")
    toast("Vaqtli")
    wait(lambda: st()["toast"] == "", 6)


@case("Bir nechta xabar navbat bilan chiqadi")
def _():
    notify("Bir"); notify("Ikki")
    toast("Bir")
    wait(lambda: st()["toast"] == "Ikki", 7)


@case("Tarixga yoziladi")
def _():
    notify("Tarixiy")
    wait(lambda: "Tarixiy" in st()["history"])


@case("O'qilmaganlar soni panel ochilganda nolga tushadi")
def _():
    notify("Oqilmagan")
    wait(lambda: st()["unread"] == 1)
    ipc("control")
    wait(lambda: st()["unread"] == 0)


@case("HTML teglar tozalanadi")
def _():
    notify("Teg", "<b>qalin</b> <script>x</script> matn")
    wait(lambda: st()["toastSub"] and "<" not in st()["toastSub"], 4, st()["toastSub"])


@case("Juda uzun matn oroldan chiqib ketmaydi")
def _():
    notify("Uzun", "x" * 3000)
    toast("Uzun")
    a = shot("n1", "300,0 680x80")
    ok(a)


@case("Muhim xabar o'zi yo'qolmaydi, bosilganda yopiladi")
def _():
    notify("-u", "critical", "Muhim")
    toast("Muhim")
    time.sleep(5)
    ok(st()["toast"] == "Muhim", st()["toast"])
    click(640, 30)
    wait(lambda: st()["toast"] == "", 3)


@case("Tarix chegarasi ishlaydi")
def _():
    settings(notifications__history=5)
    for n in range(8):
        notify(f"Son{n}")
    ok(len(st()["history"]) == 5, st()["history"])


@case("Xabar vaqtini sozlash ishlaydi")
def _():
    settings(notifications__seconds=1.0)
    notify("Qisqa")
    toast("Qisqa")
    wait(lambda: st()["toast"] == "", 2.2)


# ---------------------------------------------------------------------------------------
feature("tray", "Tray")


TRAY_APP = r"""
import dbus, dbus.service, dbus.mainloop.glib, sys
from gi.repository import GLib
"""


def tray_on():
    if not shutil.which("nm-applet"):
        raise Skip("nm-applet o'rnatilmagan")
    sh("pkill -x nm-applet")
    niri("spawn", "--", "nm-applet", "--indicator")
    wait(lambda: st()["trayCount"] >= 1, 6)


@case("Dastur tray'ga qo'shilsa hisoblanadi")
def _():
    tray_on()


@case("Dastur yopilsa ikonka yo'qoladi")
def _():
    tray_on()
    sh("pkill -x nm-applet")
    wait(lambda: st()["trayCount"] == 0, 6)


@case("Dastur qayta ochilsa qaytib keladi")
def _():
    tray_on()
    sh("pkill -x nm-applet")
    wait(lambda: st()["trayCount"] == 0, 6)
    tray_on()


@case("Ikonka panelda ko'rinadi")
def _():
    sh("pkill -x nm-applet"); wait(lambda: st()["trayCount"] == 0, 6)
    a = shot("t1", "1000,8 280x38")
    tray_on(); time.sleep(0.5)
    ok(shot("t2", "1000,8 280x38") != a)


@case("Sozlamada o'chirilsa panelda ko'rinmaydi")
def _():
    tray_on(); time.sleep(0.4)
    a = shot("t3", "1000,8 280x38")
    settings(panel__tray=False)
    ok(shot("t4", "1000,8 280x38") != a)


@case("O'ng tugma menyu ochadi")
def _():
    tray_on(); time.sleep(0.4)
    a = shot("t5")
    click(1067, 27, "0xC1")
    time.sleep(1.0)
    b = shot("t6")
    key("esc")
    ok(a != b, "menyu chiqmadi")


@case("Menyu Esc bilan yopiladi")
def _():
    tray_on(); time.sleep(0.4)
    click(1067, 27, "0xC1")
    wait(lambda: st()["popup"] == "tray", 3)
    key("esc")
    wait(lambda: st()["popup"] == "", 3)


def dumps():
    return len(sh("coredumpctl list --no-pager --no-legend").stdout.splitlines())


@case("Menyu ishlatilgandan keyin dastur yopilsa shell yiqilmaydi")
def _():
    n = dumps()
    tray_on(); time.sleep(0.4)
    click(1067, 27, "0xC1")
    wait(lambda: st()["popup"] == "tray", 3)
    key("esc"); time.sleep(0.3)
    sh("pkill -x nm-applet")
    time.sleep(1.5)
    ok(dumps() == n, "shell yiqildi")
    ok(st() is not None)


@case("Menyu ochiq turganda dastur yopilsa menyu yopiladi, shell yiqilmaydi")
def _():
    n = dumps()
    tray_on(); time.sleep(0.4)
    click(1067, 27, "0xC1")
    wait(lambda: st()["popup"] == "tray", 3)
    sh("pkill -x nm-applet")
    wait(lambda: st()["popup"] == "", 4)
    time.sleep(0.8)
    ok(dumps() == n, "shell yiqildi")


@case("Chap tugma shell'ni buzmaydi")
def _():
    tray_on(); time.sleep(0.4)
    click(1067, 27)
    time.sleep(0.6)
    key("esc")
    ok(st()["trayCount"] >= 1)


@case("O'rta tugma shell'ni buzmaydi")
def _():
    tray_on(); time.sleep(0.4)
    click(1067, 27, "0xC2")
    time.sleep(0.5)
    ok(st()["trayCount"] >= 1)


@case("Shell qayta ishga tushsa tray tiklanadi")
def _():
    tray_on()
    sh("pkill -x qs"); time.sleep(1.2)
    wait(lambda: st()["trayCount"] >= 1, 12)


# ---------------------------------------------------------------------------------------
feature("zen", "Fokus rejimi")


@case("Mod+F yoqadi va zen faylini yozadi")
def _():
    key("mod", "f")
    wait(lambda: st()["zen"], 3)
    ok((GEN / "zen.kdl").read_text().strip())


@case("Mod+F qayta bosilsa o'chadi")
def _():
    key("mod", "f"); wait(lambda: st()["zen"], 3)
    key("mod", "f"); wait(lambda: not st()["zen"], 3)


@case("Panel yashiriladi")
def _():
    a = shot("z1", "0,0 200x44")
    key("mod", "f"); wait(lambda: st()["zen"], 3); time.sleep(0.5)
    ok(shot("z2", "0,0 200x44") != a)


@case("Oynalar ekran balandligini to'ldiradi")
def _():
    term("a")
    h0 = focused()["layout"]["tile_size"][1]
    key("mod", "f"); wait(lambda: st()["zen"], 3)
    wait(lambda: focused()["layout"]["tile_size"][1] > h0, 4)


@case("Qaytganda eski o'lcham tiklanadi")
def _():
    term("a")
    h0 = focused()["layout"]["tile_size"][1]
    key("mod", "f"); wait(lambda: st()["zen"], 3); time.sleep(0.6)
    key("mod", "f"); wait(lambda: not st()["zen"], 3)
    wait(lambda: focused()["layout"]["tile_size"][1] == h0, 4)


@case("Zen'da qidiruv ishlaydi")
def _():
    key("mod", "f"); wait(lambda: st()["zen"], 3)
    launcher()
    key("esc")


@case("Zen'da Mod+D ochilishi shell'ni buzmaydi")
def _():
    key("mod", "f"); wait(lambda: st()["zen"], 3)
    key("mod", "d")
    time.sleep(0.5)
    ok(st() is not None)
    key("esc")


@case("Oyna yo'q joyda ham ishlaydi")
def _():
    ok(not windows())
    key("mod", "f"); wait(lambda: st()["zen"], 3)


@case("Tez-tez bosilganda niri config'i buzilmaydi")
def _():
    for _n in range(6):
        key("mod", "f")
    time.sleep(1.0)
    ok(sh(["niri", "validate"]).returncode == 0)


@case("Zen o'chirilgach sozlangan oraliq qaytadi")
def _():
    settings(windows__gaps=30)
    term("a")
    w0 = focused()["layout"]["tile_size"][1]
    key("mod", "f"); wait(lambda: st()["zen"], 3); time.sleep(0.5)
    key("mod", "f"); wait(lambda: not st()["zen"], 3)
    wait(lambda: focused()["layout"]["tile_size"][1] == w0, 4)


# ---------------------------------------------------------------------------------------
feature("screenshot", "Skrinshot va tahrirlash")

SHOTS = Path(sh("xdg-user-dir PICTURES").stdout.strip() or HOME / "Pictures") / "Screenshots"


def nshots():
    return len(list(SHOTS.glob("*.png")))


def take():
    key("mod", "shift", "s")
    time.sleep(0.9)
    key("enter")
    time.sleep(0.7)


@case("Mod+Shift+S va Enter fayl saqlaydi")
def _():
    n = nshots()
    take()
    wait(lambda: nshots() == n + 1, 4)


@case("O'zbekcha xabar chiqadi, inglizchasi yo'q")
def _():
    take()
    toast("Screenshot taken")
    ok("Screenshot captured" not in st()["history"], st()["history"])


@case("Clipboard'ga ham tushadi")
def _():
    take()
    wait(lambda: "image/png" in sh("wl-paste -l").stdout, 3)


@case("Esc bekor qiladi")
def _():
    n = nshots()
    key("mod", "shift", "s")
    time.sleep(0.8)
    key("esc")
    time.sleep(0.6)
    ok(nshots() == n)
    ok(st()["toast"] == "")


@case("Xabarni bosish tahrirlovchini ochadi")
def _():
    take()
    toast("Screenshot taken")
    click(640, 30)
    wait(lambda: any("satty" in (w["app_id"] or "") for w in windows()), 6)


@case("Tahrirlovchi yopilsa fayl joyida qoladi")
def _():
    n = nshots()
    take(); toast("Screenshot taken")
    click(640, 30)
    w = wait(lambda: next(w for w in windows() if "satty" in (w["app_id"] or "")), 6)
    niri("close-window", "--id", w["id"])
    time.sleep(0.5)
    ok(nshots() == n + 1)


@case("Xabar bosilmasa tahrirlovchi ochilmaydi")
def _():
    take(); toast("Screenshot taken")
    wait(lambda: st()["toast"] == "", 6)
    ok(not any("satty" in (w["app_id"] or "") for w in windows()))


@case("Print tugmasi ishlaydi")
def _():
    n = nshots()
    key("print")
    time.sleep(0.9)
    key("enter")
    wait(lambda: nshots() == n + 1, 4)


@case("Ctrl+Print butun ekranni oladi")
def _():
    n = nshots()
    key("ctrl", "print")
    wait(lambda: nshots() == n + 1, 4)


@case("Papka o'chirilgan bo'lsa ham shell buzilmaydi")
def _():
    tmp = SHOTS.with_name("Screenshots.nd")
    SHOTS.rename(tmp)
    try:
        key("ctrl", "print")
        time.sleep(1.0)
        ok(st() is not None)
    finally:
        if SHOTS.exists():
            for f in SHOTS.iterdir():
                shutil.move(str(f), tmp)
            SHOTS.rmdir()
        tmp.rename(SHOTS)


# ---------------------------------------------------------------------------------------
feature("record", "Ekranni yozish")

VIDEOS = Path(sh("xdg-user-dir VIDEOS").stdout.strip() or HOME / "Videos")


def nvideos():
    return len(list(VIDEOS.glob("*.mp4")))


def rec_start():
    key("mod", "shift", "r")
    wait(lambda: sh("pgrep -x slurp").returncode == 0, 3, "soha tanlash ochilmadi")
    time.sleep(0.2)
    drag(100, 100, 500, 400)
    wait(lambda: st()["recording"], 4)


def rec_stop():
    key("mod", "shift", "r")
    wait(lambda: not st()["recording"], 4)


@case("Soha tanlansa yozish boshlanadi")
def _():
    rec_start()
    ok(sh("pgrep -x wf-recorder").returncode == 0)
    rec_stop()


@case("Qayta bosish to'xtatadi va video saqlaydi")
def _():
    n = nvideos()
    rec_start(); time.sleep(1.5); rec_stop()
    wait(lambda: nvideos() == n + 1, 4)
    time.sleep(0.6)
    f = max(VIDEOS.glob("*.mp4"), key=lambda p: p.stat().st_mtime)
    ok(f.stat().st_size > 1000, f.stat().st_size)


@case("Video haqiqatan o'qiladi")
def _():
    rec_start(); time.sleep(2.0); rec_stop(); time.sleep(0.8)
    f = max(VIDEOS.glob("*.mp4"), key=lambda p: p.stat().st_mtime)
    d = float(sh(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(f)]).stdout or 0)
    ok(d > 1.0, d)


@case("Esc bilan bekor qilinsa yozish boshlanmaydi")
def _():
    key("mod", "shift", "r")
    wait(lambda: sh("pgrep -x slurp").returncode == 0, 3)
    time.sleep(0.2)
    key("esc")
    time.sleep(0.6)
    ok(not st()["recording"])
    ok(sh("pgrep -x wf-recorder").returncode != 0)


@case("Yozish paytida orolda qizil vaqt ko'rinadi")
def _():
    a = shot("rec0", "500,0 280x44")
    rec_start()
    time.sleep(1.2)
    ok(shot("rec1", "500,0 280x44") != a)
    rec_stop()


@case("Yozish paytida qidiruv ishlaydi")
def _():
    rec_start()
    launcher()
    key("esc")
    ok(st()["recording"])
    rec_stop()


@case("Shell qayta ishga tushsa yozish davom etadi va to'xtatsa bo'ladi")
def _():
    rec_start()
    sh("pkill -x qs"); time.sleep(1.2)
    wait(lambda: st() is not None, 10)
    ok(sh("pgrep -x wf-recorder").returncode == 0)
    key("mod", "shift", "r")
    wait(lambda: sh("pgrep -x wf-recorder").returncode != 0, 5)


@case("wf-recorder o'zi to'xtasa keyingi bosish yangisini boshlaydi")
def _():
    rec_start()
    sh("pkill -9 -x wf-recorder")
    time.sleep(0.4)
    key("mod", "shift", "r")
    wait(lambda: sh("pgrep -x slurp").returncode == 0, 3)
    key("esc")
    ipc("recording", "false")


@case("Videos papkasi yo'q bo'lsa yaratiladi")
def _():
    tmp = VIDEOS.with_name(VIDEOS.name + ".nd")
    VIDEOS.rename(tmp)
    try:
        rec_start(); time.sleep(1.0); rec_stop(); time.sleep(0.6)
        ok(any(VIDEOS.glob("*.mp4")))
    finally:
        if VIDEOS.exists():
            shutil.rmtree(VIDEOS)
        tmp.rename(VIDEOS)


@case("Ikki yozuv ketma-ket ishlaydi")
def _():
    n = nvideos()
    rec_start(); time.sleep(1.2); rec_stop(); time.sleep(1.1)
    rec_start(); time.sleep(1.2); rec_stop(); time.sleep(0.6)
    wait(lambda: nvideos() >= n + 2, 4)


# ---------------------------------------------------------------------------------------
feature("ocr", "Ekrandan matn va rang olish")


def term_text(text):
    niri("spawn", "--", "kitty", "--title", "ocr", "sh", "-c", f"clear; echo '{text}'; sleep 900")
    wait(windows, 5)
    time.sleep(1.2)


def ocr_region():
    key("mod", "p")
    wait(lambda: sh("pgrep -x slurp").returncode == 0, 3)
    time.sleep(0.2)


@case("Mod+P matnni nusxalaydi")
def _():
    settings(windows__centerSingle=False)
    term_text("SINOV 12345 MATNI")
    ocr_region()
    drag(10, 55, 640, 200)
    wait(lambda: "12345" in clip_text(), 8)


@case("Natija xabari chiqadi")
def _():
    settings(windows__centerSingle=False)
    term_text("XABAR 777")
    ocr_region()
    drag(10, 55, 640, 200)
    toast("Text copied", 8)


@case("Esc bekor qiladi, clipboard o'zgarmaydi")
def _():
    copy("tegmagan")
    ocr_region()
    key("esc")
    time.sleep(0.8)
    ok(clip_text() == "tegmagan", clip_text())


@case("Bo'sh sohada 'Matn topilmadi' deydi")
def _():
    settings(windows__centerSingle=False)
    term_text(" ")
    ocr_region()
    drag(300, 400, 500, 600)
    toast("No text found", 8)


@case("Kirill matn ham o'qiladi")
def _():
    settings(windows__centerSingle=False, appearance__terminalFontSize=18)
    term_text("ПРИВЕТ МИР")
    ocr_region()
    drag(10, 55, 640, 200)
    wait(lambda: "ПРИВЕТ" in clip_text().upper(), 8, clip_text())


@case("Kichik soha ham shell'ni buzmaydi")
def _():
    ocr_region()
    drag(100, 100, 103, 103)
    time.sleep(1.5)
    ok(st() is not None)


@case("Rang olish hex nusxalaydi")
def _():
    launcher("pick color")
    key("enter")
    time.sleep(0.8)
    click(400, 400)
    wait(lambda: re.fullmatch(r"#[0-9a-fA-F]{6}", clip_text()), 5, clip_text())


@case("Rang olishda xabar chiqadi")
def _():
    launcher("pick color")
    key("enter")
    time.sleep(0.8)
    click(500, 500)
    toast("Color copied", 5)


@case("Rang olishni Esc bekor qiladi")
def _():
    copy("rang-tegmagan")
    launcher("pick color")
    key("enter")
    time.sleep(0.8)
    key("esc")
    time.sleep(0.8)
    ok(clip_text() == "rang-tegmagan", clip_text())


@case("OCR ketma-ket ikki marta ishlaydi")
def _():
    settings(windows__centerSingle=False)
    term_text("BIRINCHI 111")
    ocr_region(); drag(10, 55, 640, 200)
    wait(lambda: "111" in clip_text(), 8)
    time.sleep(0.5)
    ocr_region(); drag(10, 55, 640, 200)
    time.sleep(1.5)
    ok("111" in clip_text())


# ---------------------------------------------------------------------------------------
feature("lock", "Bloklash va kofe rejimi")


def unlock():
    typ(PW)
    key("enter")
    wait(lambda: sh("pgrep -x hyprlock").returncode != 0, 6, "ochilmadi")
    time.sleep(0.5)


def locked():
    return sh("pgrep -x hyprlock").returncode == 0


def need_pw():
    if not PW:
        raise Skip("parol berilmagan")


@case("Mod+X bloklaydi")
def _():
    need_pw()
    key("mod", "x")
    wait(locked, 4)
    time.sleep(1)
    unlock()


@case("logind holati ham 'locked' bo'ladi")
def _():
    need_pw()
    key("mod", "x"); wait(locked, 4); time.sleep(0.8)
    sid = sh("loginctl list-sessions --no-legend").stdout.split()[0]
    ok("LockedHint=yes" in sh(f"loginctl show-session {sid} -p LockedHint").stdout)
    unlock()


@case("Noto'g'ri parol ochmaydi")
def _():
    need_pw()
    key("mod", "x"); wait(locked, 4); time.sleep(0.8)
    typ("notogri-parol"); key("enter")
    time.sleep(3)
    ok(locked())
    unlock()


@case("Bo'sh Enter ochmaydi")
def _():
    need_pw()
    key("mod", "x"); wait(locked, 4); time.sleep(0.8)
    key("enter"); time.sleep(1)
    ok(locked())
    unlock()


@case("Bloklanganda Mod+Space ishlamaydi")
def _():
    need_pw()
    key("mod", "x"); wait(locked, 4); time.sleep(0.8)
    key("mod", "space"); time.sleep(0.6)
    ok(st()["popup"] == "", st()["popup"])
    unlock()


@case("Bloklanganda ovoz tugmasi ishlaydi")
def _():
    need_pw()
    setvol(0.5)
    key("mod", "x"); wait(locked, 4); time.sleep(0.8)
    key("volup"); time.sleep(0.5)
    ok(vol() > 0.5, vol())
    unlock()


@case("Qayta Mod+X ikkinchi nusxa ochmaydi")
def _():
    need_pw()
    key("mod", "x"); wait(locked, 4); time.sleep(0.5)
    key("mod", "x"); time.sleep(1)
    ok(len(sh("pgrep -x hyprlock").stdout.split()) == 1)
    unlock()


@case("Shell o'ldirilsa ham ekran bloklangan qoladi")
def _():
    need_pw()
    key("mod", "x"); wait(locked, 4); time.sleep(0.8)
    sh("pkill -x qs"); time.sleep(1)
    ok(locked())
    wait(lambda: sh("pgrep -x qs").returncode == 0, 6, "shell qaytmadi")
    ok(locked())
    unlock()
    wait(lambda: "niri-desk-top" in layers(), 10)


@case("Bo'sh turganda avtomatik bloklanadi")
def _():
    need_pw()
    settings(idle__lock=3, idle__screenOff=0, idle__suspend=0)
    time.sleep(1.5)
    wait(locked, 15, "bloklanmadi")
    time.sleep(1)
    unlock()


@case("Kofe rejimida avtomatik bloklanmaydi")
def _():
    need_pw()
    settings(idle__lock=3, idle__screenOff=0, idle__suspend=0)
    open_control()
    click(toggle_x(3), 91)
    wait(lambda: st()["caffeine"], 3)
    key("esc")
    time.sleep(7)
    ok(not locked(), "kofe rejimiga qaramay bloklandi")


# ---------------------------------------------------------------------------------------
feature("set-look", "Sozlamalar: ko'rinish")


def accent():
    return st()["accent"]


def gen():
    return (GEN / "settings.kdl").read_text()


@case("Yorug' rejim ranglarni o'zgartiradi")
def _():
    a = st()["pill"]
    settings(appearance__mode="light")
    wait(lambda: st()["pill"] != a, 6)


@case("Rang uslubi o'zgarishi ranglarga ta'sir qiladi")
def _():
    a = accent()
    settings(appearance__scheme="scheme-monochrome")
    wait(lambda: accent() != a, 6)


@case("O'z rangini berish ishlaydi")
def _():
    a = accent()
    settings(appearance__accent="#ff0000")
    wait(lambda: accent() != a, 6)


@case("Noto'g'ri rang rad etiladi, eski rang qoladi")
def _():
    a = accent()
    settings(appearance__accent="qizil")
    wait(lambda: st()["error"], 5)
    ok(accent() == a)


@case("Noto'g'ri rang uslubi rad etiladi")
def _():
    a = accent()
    settings(appearance__scheme="yoq-uslub")
    wait(lambda: st()["error"], 6)
    time.sleep(0.4)
    ok(accent() == a)


@case("Matn o'lchami o'zgaradi")
def _():
    a = shot("f1", "0,0 400x44")
    settings(appearance__fontScale=1.3)
    ok(st()["fontScale"] == 1.3)
    ok(shot("f2", "0,0 400x44") != a)


@case("Panel shaffofligi o'zgaradi")
def _():
    a = shot("o1", "1040,8 240x40")
    settings(appearance__panelOpacity=0.4)
    time.sleep(0.3)
    ok(shot("o2", "1040,8 240x40") != a)


@case("Terminal shaffofligi kitty fayliga yoziladi")
def _():
    settings(appearance__terminalOpacity=0.5)
    wait(lambda: "background_opacity 0.5" in (HOME / ".config/kitty/niri-desk-user.conf").read_text(), 4)


@case("Mavjud bo'lmagan shrift shell'ni buzmaydi")
def _():
    settings(appearance__font="Bunday Shrift Yoq")
    ok(st() is not None)
    launcher()
    key("esc")


@case("Chegaradan tashqari matn o'lchami panelni qulatmaydi")
def _():
    settings(appearance__fontScale=5)
    ok(st() is not None)
    settings(appearance__fontScale=0.1)
    ok(st() is not None)


# ---------------------------------------------------------------------------------------
feature("set-win", "Sozlamalar: oynalar")


@case("Oraliq o'zgartirilsa oyna o'lchami o'zgaradi")
def _():
    term("a"); term("b")
    h = focused()["layout"]["tile_size"][1]
    settings(windows__gaps=40)
    wait(lambda: focused()["layout"]["tile_size"][1] != h, 5)


@case("Oraliq 0 ham ishlaydi")
def _():
    settings(windows__gaps=0)
    wait(lambda: "gaps 0" in gen(), 3)
    ok(sh(["niri", "validate"]).returncode == 0)


@case("Manfiy oraliq rad etiladi va eski config qoladi")
def _():
    before = gen()
    settings(windows__gaps=-5)
    wait(lambda: st()["error"], 5)
    ok(gen() == before)


@case("Matn berilsa rad etiladi")
def _():
    before = gen()
    settings(windows__gaps="katta")
    wait(lambda: st()["error"], 5)
    ok(gen() == before)


@case("Burchak yumaloqligi config'ga yoziladi")
def _():
    settings(windows__radius=0)
    wait(lambda: "geometry-corner-radius 0" in gen(), 3)


@case("Animatsiya o'chiriladi")
def _():
    settings(windows__animations=False)
    wait(lambda: re.search(r"animations \{\n\s+off", gen()), 3)
    ok(sh(["niri", "validate"]).returncode == 0)


@case("Xira fon o'chiriladi")
def _():
    settings(windows__blur=False)
    wait(lambda: re.search(r"blur \{\n\s+off", gen()), 3)


@case("Faol bo'lmagan oyna shaffofligi qo'shiladi")
def _():
    settings(windows__inactiveOpacity=0.6)
    wait(lambda: "opacity 0.6" in gen(), 3)
    term("a"); term("b")
    ok(sh(["niri", "validate"]).returncode == 0)


@case("Yangi oyna kengligi sozlamasi ishlaydi")
def _():
    settings(windows__defaultWidth=1, windows__centerSingle=False)
    time.sleep(0.5)
    term("a")
    ok(focused()["layout"]["tile_size"][0] > 1200, focused()["layout"])


@case("Yagona oynani markazlash o'chiriladi")
def _():
    settings(windows__centerSingle=False)
    wait(lambda: "always-center-single-column" not in gen(), 3)


# ---------------------------------------------------------------------------------------
feature("set-rules", "Sozlamalar: oyna qoidalari")


def rules(*r):
    settings(windows__rules=list(r))
    time.sleep(0.4)


@case("Qoida bilan dastur suzib ochiladi")
def _():
    rules({"app": "^qoida1$", "floating": True})
    ok(floats("x", "qoida1"))


@case("Sarlavha bo'yicha qoida ishlaydi")
def _():
    rules({"title": "^Maxsus sarlavha$", "floating": True})
    ok(floats("Maxsus sarlavha"))


@case("Boshqa dasturga ta'sir qilmaydi")
def _():
    rules({"app": "^qoida1$", "floating": True})
    ok(not floats("x", "boshqa"))


@case("Kenglik qoidasi ishlaydi")
def _():
    rules({"app": "^keng$", "width": 1.0})
    term("x", "keng")
    ok(focused()["layout"]["tile_size"][0] > 1200, focused()["layout"])


@case("Fokus olmaslik qoidasi ishlaydi")
def _():
    rules({"app": "^jim$", "noFocus": True})
    a = term("a")
    foot("x", "jim")
    ok(focused()["id"] == a, focused())


@case("Noto'g'ri regex rad etiladi")
def _():
    before = gen()
    rules({"app": "(((", "floating": True})
    wait(lambda: st()["error"], 5)
    ok(gen() == before)


@case("Bo'sh qoida e'tiborsiz qoldiriladi")
def _():
    rules({"app": "", "title": "", "floating": True})
    ok(sh(["niri", "validate"]).returncode == 0)
    ok(st()["error"] == "", st()["error"])


@case("Maxsus belgili regex KDL'ni buzmaydi")
def _():
    rules({"app": 'a"b\\.c#d', "floating": True})
    ok(sh(["niri", "validate"]).returncode == 0, st()["error"])


@case("Qoida o'chirilsa dastur oddiy ochiladi")
def _():
    rules({"app": "^qoida1$", "floating": True})
    rules()
    ok(not floats("x", "qoida1"))


@case("Yozuvdan yashirish qoidasi config'ga tushadi")
def _():
    rules({"app": "^maxfiy$", "hideFromCapture": True})
    wait(lambda: 'block-out-from "screen-capture"' in gen(), 3)


# ---------------------------------------------------------------------------------------
feature("set-panel", "Sozlamalar: panel")


def crop_top():
    return shot("pt", "0,0 1280x44")


def crop_bottom():
    return shot("pb", "0,756 1280x44")


@case("Panel pastga ko'chadi")
def _():
    t, b = crop_top(), crop_bottom()
    settings(panel__position="bottom")
    ok(st()["bottom"])
    time.sleep(0.4)
    ok(crop_top() != t and crop_bottom() != b)


@case("Pastda turganda oynalar panel ostiga kirmaydi")
def _():
    settings(panel__position="bottom", windows__centerSingle=False)
    time.sleep(0.6)
    term("a")
    time.sleep(0.5)
    ok(focused()["layout"]["tile_size"][1] <= 800 - 40 - 14, focused()["layout"])


@case("Pastda dashboard ochiladi")
def _():
    settings(panel__position="bottom")
    time.sleep(0.5)
    click(640, 780)
    wait(lambda: st()["popup"] == "dashboard", 3)


@case("Pastda raqam bosiladi")
def _():
    settings(panel__position="bottom")
    time.sleep(0.5)
    click(14 + 4 + 26 + 13, 800 - 27)
    wait(lambda: active_ws() == 2)


@case("Noto'g'ri joylashuv panelni yo'qotmaydi")
def _():
    settings(panel__position="chapda")
    ok(not st()["bottom"])
    term("a")
    click(14 + 4 + 26 + 13, 27)
    wait(lambda: active_ws() == 2)


@case("Raqamlarni yashirish ishlaydi")
def _():
    a = shot("pr1", "0,0 200x44")
    settings(panel__ribbon=False)
    ok(shot("pr2", "0,0 200x44") != a)


@case("Til, Wi-Fi, ovoz, batareya alohida yashiriladi")
def _():
    a = shot("ps1", "1000,0 280x44")
    settings(panel__lang=False)
    b = shot("ps2", "1000,0 280x44")
    ok(a != b)
    settings(panel__volume=False)
    c = shot("ps3", "1000,0 280x44")
    ok(b != c)


@case("Hammasi yashirilsa ham boshqaruv paneli ochiladi")
def _():
    settings(panel__lang=False, panel__wifi=False, panel__volume=False, panel__battery=False, panel__tray=False)
    time.sleep(0.4)
    click(1255, 27)
    wait(lambda: st()["popup"] == "control", 3)


@case("Soniya va sana ko'rsatiladi")
def _():
    a = shot("pc1", "400,0 480x44")
    settings(panel__clockSeconds=True, panel__clockDate=True)
    time.sleep(0.5)
    ok(shot("pc2", "400,0 480x44") != a)


@case("Bo'sh ish stoli soati o'chiriladi")
def _():
    wait(lambda: "niri-desk-clock" in layers(), 3)
    settings(panel__quietClock=False)
    wait(lambda: "niri-desk-clock" not in layers(), 3)


# ---------------------------------------------------------------------------------------
feature("set-keys", "Sozlamalar: klavishlar va klaviatura")


def binds_text():
    return (GEN / "binds.kdl").read_text()


@case("Klavishni o'zgartirish ishlaydi")
def _():
    settings(binds__launcher="Mod+Y")
    time.sleep(0.4)
    key("mod", "y")
    wait(lambda: st()["popup"] == "launcher", 3)


@case("Eski klavish endi ishlamaydi")
def _():
    settings(binds__launcher="Mod+Y")
    time.sleep(0.4)
    key("mod", "space")
    time.sleep(0.6)
    ok(st()["popup"] == "")


@case("Klavishni bo'sh qoldirish uni o'chiradi")
def _():
    settings(binds__dashboard="")
    time.sleep(0.4)
    key("mod", "d")
    time.sleep(0.5)
    ok(st()["popup"] == "")


@case("Bir klavish ikki amalga berilsa rad etiladi")
def _():
    before = binds_text()
    settings(binds__launcher="Mod+D")
    wait(lambda: "two actions" in st()["error"], 5, st()["error"])
    ok(binds_text() == before)


@case("Band tizim klavishi rad etiladi")
def _():
    before = binds_text()
    settings(binds__launcher="Mod+H")
    wait(lambda: "system shortcut" in st()["error"], 5, st()["error"])
    ok(binds_text() == before)
    key("mod", "space")
    wait(lambda: st()["popup"] == "launcher", 3)


@case("Mavjud bo'lmagan tugma nomi rad etiladi")
def _():
    before = binds_text()
    settings(binds__launcher="Mod+Bunday")
    wait(lambda: st()["error"], 5)
    ok(binds_text() == before)


@case("Xavfli matn klavish sifatida qabul qilinmaydi")
def _():
    before = binds_text()
    settings(binds__launcher='Mod+Y { spawn "touch" "/tmp/nd-k.flag"; }')
    wait(lambda: st()["error"], 5)
    ok(binds_text() == before)


@case("Yangi til qo'shiladi")
def _():
    settings(keyboard__layouts="us,ru,de")
    wait(lambda: "German" in sh("niri msg keyboard-layouts").stdout, 4)


@case("Noto'g'ri til config'ni buzmaydi")
def _():
    settings(keyboard__layouts="us,xx-yoq")
    time.sleep(0.6)
    ok(sh(["niri", "msg", "version"]).returncode == 0)
    ok(sh(["niri", "validate"]).returncode == 0)


@case("Har oyna o'z tilini eslaydi")
def _():
    a = term("a"); b = term("b")
    niri("switch-layout", "1")
    wait(lambda: st()["layout"] == "RU", 3)
    key("mod", "h")
    wait(lambda: st()["layout"] == "EN", 3)
    key("mod", "l")
    wait(lambda: st()["layout"] == "RU", 3)


# ---------------------------------------------------------------------------------------
feature("set-ui", "Sozlamalar oynasi")


def sw():
    return next((w for w in windows() if w["title"] == "niri-desk settings"), None)


def open_sw():
    key("mod", "comma")
    return wait(sw, 4)


def sw_origin():
    # Panel uchun 40 piksel ajratilgan, oyna qolgan joy markazida.
    return (1280 - 860) // 2, 40 + (800 - 40 - 640) // 2


@case("Mod+, ochadi va suzib turadi")
def _():
    ok(open_sw()["is_floating"])


@case("Qayta bosilsa yopiladi")
def _():
    open_sw()
    key("mod", "comma")
    wait(lambda: sw() is None, 4)
    ok(not st()["settings"])


@case("Mod+Q bilan yopilsa holat to'g'ri qoladi")
def _():
    open_sw()
    key("mod", "q")
    wait(lambda: sw() is None, 4)
    wait(lambda: not st()["settings"], 3)
    open_sw()


@case("Ikkinchi nusxa ochilmaydi")
def _():
    open_sw()
    ok(len([w for w in windows() if w["title"] == "niri-desk settings"]) == 1)


@case("Qidiruv oynasidan ham ochiladi")
def _():
    launcher("settings")
    key("enter")
    wait(sw, 4)


@case("Tugma bosilganda settings.json o'zgaradi")
def _():
    open_sw(); time.sleep(0.4)
    ox, oy = sw_origin()
    # Oynalar bo'limi, "Soya" tugmasi to'rtinchi qator.
    click(ox + 95, oy + 112)
    time.sleep(0.4)
    click(ox + 825, oy + 62 + 48 * 3 + 23)
    wait(lambda: json.loads(SET.read_text()).get("windows", {}).get("shadow") is False, 3, "settings.json o'zgarmadi")


@case("Bo'limlar orasida o'tish oynani buzmaydi")
def _():
    open_sw(); time.sleep(0.3)
    ox, oy = sw_origin()
    for i in range(7):
        click(ox + 95, oy + 74 + 38 * i)
        time.sleep(0.15)
    ok(sw() is not None and st()["error"] == "")


@case("Qidiruv maydoni sozlamani topadi")
def _():
    open_sw(); time.sleep(0.4)
    ox, oy = sw_origin()
    a = shot("uq0")
    click(ox + 500, oy + 34)
    typ("shadow")
    time.sleep(0.4)
    ok(shot("uq1") != a)


@case("Fayl qo'lda buzilsa eski sozlama qoladi va xabar chiqadi")
def _():
    SET.write_text("{ bu json emas")
    time.sleep(1.0)
    toast("The settings file is invalid", 4)
    ok(st() is not None)
    ok(sh(["niri", "validate"]).returncode == 0)


@case("Standartga qaytarish oynasi ikki bosish talab qiladi")
def _():
    settings(windows__gaps=33)
    open_sw(); time.sleep(0.4)
    ox, oy = sw_origin()
    click(ox + 95, oy + 434)
    time.sleep(0.5)
    ok(json.loads(SET.read_text())["windows"]["gaps"] == 33)
    click(ox + 95, oy + 434)
    wait(lambda: "windows" not in json.loads(SET.read_text()), 4)


# ---------------------------------------------------------------------------------------
feature("set-gui", "Sozlamalar oynasi boshqaruvlari")


def page(i):
    open_sw(); time.sleep(0.5)
    ox, oy = sw_origin()
    click(ox + 95, oy + 74 + 38 * i)
    time.sleep(0.4)
    return ox, oy


def row_y(oy, i):
    return oy + 62 + 48 * i + 23


def saved():
    return json.loads(SET.read_text() or "{}")


@case("Sliderni bosish qiymatni o'zgartiradi")
def _():
    ox, oy = page(1)
    click(ox + 590 + 100, row_y(oy, 0))
    wait(lambda: saved().get("windows", {}).get("gaps") == 20, 3, saved().get("windows"))
    wait(lambda: "gaps 20" in gen(), 4)


@case("Sliderni oxirigacha sudrash chegaradan oshmaydi")
def _():
    ox, oy = page(1)
    drag(ox + 620, row_y(oy, 1), ox + 840, row_y(oy, 1))
    wait(lambda: saved().get("windows", {}).get("radius") == 32, 3, saved().get("windows"))
    ok(sw() is not None)


@case("Tanlov tugmasi qiymatni o'zgartiradi")
def _():
    ox, oy = page(3)
    click(ox + 820, row_y(oy, 0))
    wait(lambda: saved().get("panel", {}).get("position") == "bottom", 3, saved().get("panel"))
    wait(lambda: st()["bottom"], 3)


@case("Matn maydoni Enter bilan saqlanadi")
def _():
    ox, oy = page(0)
    a = accent()
    click(ox + 700, row_y(oy, 3))
    typ("#00ff00")
    key("enter")
    wait(lambda: saved().get("appearance", {}).get("accent") == "#00ff00", 3, saved().get("appearance"))
    wait(lambda: accent() != a, 6)


@case("Noto'g'ri rang kiritilsa xato xabari chiqadi")
def _():
    ox, oy = page(0)
    click(ox + 700, row_y(oy, 3))
    typ("qizil")
    key("enter")
    wait(lambda: "color" in st()["error"], 5, st()["error"])


@case("Klavishni maydondan o'zgartirish ishlaydi")
def _():
    ox, oy = page(5)
    click(ox + 800, row_y(oy, 1))
    for _n in range(12):
        key("backspace")
    typ("Mod+Y")
    key("enter")
    wait(lambda: "Mod+Y hotkey" in binds_text(), 4, st()["error"])
    key("esc")
    time.sleep(0.4)
    key("mod", "y")
    wait(lambda: st()["popup"] == "launcher", 3)


@case("Yangi qoida tugmasi qoida qo'shadi")
def _():
    a = term("a", "qoidali")
    ox, oy = page(2)
    click(ox + 299, oy + 105)
    wait(lambda: saved().get("windows", {}).get("rules"), 3, "qoida qo'shilmadi")
    ok(saved()["windows"]["rules"][0]["app"] == "^qoidali$", saved()["windows"]["rules"])


@case("Qoidadagi Suzuvchi tugmasi ishlaydi va yangi oynaga ta'sir qiladi")
def _():
    settings(windows__rules=[{"app": "^qoidali$", "title": ""}])
    ox, oy = page(2)
    click(ox + 250, oy + 190)
    wait(lambda: saved()["windows"]["rules"][0].get("floating") is True, 3, saved()["windows"]["rules"])
    key("mod", "comma"); wait(lambda: sw() is None, 3)
    ok(floats("x", "qoidali"))


@case("Qidiruv natijasidagi tugma ishlaydi")
def _():
    open_sw(); time.sleep(0.5)
    ox, oy = sw_origin()
    click(ox + 500, oy + 34)
    typ("shadow")
    time.sleep(0.5)
    click(ox + 825, row_y(oy, 0))
    wait(lambda: saved().get("windows", {}).get("shadow") is False, 3, saved().get("windows"))


@case("Oyna qayta ochilganda qiymat saqlanib qoladi")
def _():
    ox, oy = page(1)
    click(ox + 590 + 100, row_y(oy, 0))
    wait(lambda: saved().get("windows", {}).get("gaps") == 20, 3)
    key("mod", "comma"); wait(lambda: sw() is None, 3)
    open_sw(); time.sleep(0.4)
    ok(saved()["windows"]["gaps"] == 20)
    ok(st()["error"] == "", st()["error"])


# ---------------------------------------------------------------------------------------
feature("session", "Barqarorlik")


@case("Bo'sh turganda shell protsessorni band qilmaydi")
def _():
    p = sh("pgrep -x qs").stdout.split()[0]
    t = lambda: sum(int(x) for x in Path(f"/proc/{p}/stat").read_text().split()[13:15])
    a = t(); time.sleep(5); b = t()
    ok(b - a < 25, b - a)


@case("Qayta yuklanganda bitta nusxa ishlaydi")
def _():
    ok(len(sh("pgrep -x qs").stdout.split()) == 1)


@case("Shell o'ldirilsa nazoratchi o'zi qaytaradi")
def _():
    sh("pkill -9 -x qs"); time.sleep(0.5)
    wait(lambda: "niri-desk-top" in layers(), 10)
    ok(len(sh("pgrep -x qs").stdout.split()) == 1)


@case("niri config xatosi shell'ga xabar qiladi")
def _():
    p = HOME / ".config/niri/cfg/user.kdl"
    old = p.read_text()
    try:
        p.write_text(old + "\nbu-notogri-kdl {{{\n")
        toast("Error in the niri config", 6)
    finally:
        p.write_text(old)
    time.sleep(0.5)


@case("Oyna yopilishida shell xato yozmaydi")
def _():
    for n in range(5):
        i = term(f"w{n}")
        niri("close-window", "--id", i)
    ok(st() is not None)


@case("Xotira tez o'smaydi")
def _():
    p = sh("pgrep -x qs").stdout.split()[0]
    rss = lambda: int(re.search(r"VmRSS:\s+(\d+)", Path(f"/proc/{p}/status").read_text()).group(1))
    a = rss()
    for _n in range(15):
        ipc("dashboard"); time.sleep(0.25)
    ipc("reset")
    ok(rss() - a < 80000, rss() - a)


@case("Monitor o'chib yonsa panel qoladi")
def _():
    niri("power-off-monitors"); time.sleep(0.8)
    niri("power-on-monitors"); time.sleep(0.8)
    ok("niri-desk-top" in layers())


@case("Masshtab o'zgarsa panel ishlaydi")
def _():
    o = next(iter(nj("outputs")))
    sh(["niri", "msg", "output", o, "scale", "1.25"]); time.sleep(1)
    ok("niri-desk-top" in layers())
    ok(st() is not None)
    sh(["niri", "msg", "output", o, "scale", "1"]); time.sleep(0.8)


@case("Monitor qayta ulansa panel qaytadi")
def _():
    o = next(iter(nj("outputs")))
    sh(["niri", "msg", "output", o, "off"])
    time.sleep(1.0)
    sh(["niri", "msg", "output", o, "on"])
    wait(lambda: "niri-desk-top" in layers(), 6)


@case("Uzoq ishlashdan keyin ham jurnalda xato ko'p emas")
def _():
    r = sh("timeout 4 qs -c niri-desk log </dev/null", timeout=8)
    text = re.sub(r"\x1b\[[0-9;]*m", "", r.stdout + r.stderr)
    bad = [l for l in text.splitlines() if " ERROR" in l and "pipewire" not in l]
    ok(len(bad) < 3, bad[:3])


# ---------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------
# Yangi funksiyalar
LBIN = HOME / ".local/bin"
PROFILES = HOME / ".config/niri-desk/profiles.json"
SNIPPETS = HOME / ".config/niri-desk/snippets.json"
AI_URL = "http://127.0.0.1:8765"
FAKE = None


def lq(q):
    launcher()
    ipc("launcherQuery", q)
    time.sleep(0.5)


def run(*argv, stdin=None, timeout=30):
    return sh([str(LBIN / argv[0]), *argv[1:]], stdin=stdin, timeout=timeout)


def dash(tab):
    ipc("dashboardTab", str(tab))
    wait(lambda: st()["popup"] == "dashboard" and st()["dashTab"] == tab, 3, "vkladka ochilmadi")
    time.sleep(0.5)


def ai_ready():
    global FAKE
    if FAKE is None or FAKE.poll() is not None:
        FAKE = subprocess.Popen([sys.executable, str(Path(__file__).with_name("fake_ai.py"))], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        time.sleep(0.8)
    sh(["rm", "-f", "/tmp/fake-ai.log", str(STATE / "ai-history.json")])
    settings(ai__baseUrl=AI_URL, ai__backend="api")
    sh(f"echo sk-test | {LBIN}/niri-desk-ai set-key")


def fake_log():
    try:
        return [json.loads(l) for l in open("/tmp/fake-ai.log")]
    except OSError:
        return []


def ai_say(text, done=True):
    dash(3)
    typ(text)
    key("enter")
    if done:
        wait(lambda: not st()["aiBusy"] and any(m.startswith(("assistant:", "error:")) for m in st()["aiMessages"][-1:]), 15, "javob kelmadi")


def write_json(path, data):
    path.write_text(json.dumps(data))
    time.sleep(0.6)


feature("dash", "Dashboard: 4 ta vkladka")

for _i, _name in enumerate(["Today", "Status", "Lab", "AI"]):
    @case(f"{_i + 1}-vkladka ({_name}) ochiladi")
    def _(i=_i):
        dash(i)
        ok(st()["dashTab"] == i)


@case("Soatni bosish birinchi vkladkani ochadi")
def _():
    click(640, 16)
    wait(lambda: st()["popup"] == "dashboard", 3, "ochilmadi")
    ok(st()["dashTab"] == 0)


@case("Vkladka nomini bosish uni tanlaydi")
def _():
    dash(0)
    click(702, 27)
    wait(lambda: st()["dashTab"] == 2, 2, "almashmadi")
    click(577, 27)
    wait(lambda: st()["dashTab"] == 1, 2, "almashmadi")


@case("Raqam tugmalari vkladkani almashtiradi")
def _():
    dash(0)
    key("2")
    wait(lambda: st()["dashTab"] == 1, 2, "2 ishlamadi")
    key("3")
    wait(lambda: st()["dashTab"] == 2, 2, "3 ishlamadi")


@case("Tab keyingisiga o'tadi va aylanadi")
def _():
    dash(1)
    key("tab")
    wait(lambda: st()["dashTab"] == 2, 2, f"Tab ishlamadi: {layers()} {focused()}")
    key("tab")
    wait(lambda: st()["dashTab"] == 3, 2, "AI ga o'tmadi")
    key("tab")
    wait(lambda: st()["dashTab"] == 0, 2, "AI ichida Tab ushlanib qoldi")


@case("Esc har vkladkada yopadi")
def _():
    for i in range(4):
        dash(i)
        key("esc")
        wait(lambda: st()["popup"] == "", 2, f"{i}-vkladka yopilmadi")


@case("Oxirgi tanlangan vkladka qayta ochilganda eslab qolinadi")
def _():
    dash(1)
    key("esc")
    wait(lambda: st()["popup"] == "", 2)
    ipc("dashboard")
    wait(lambda: st()["popup"] == "dashboard", 2)
    ok(st()["dashTab"] == 1)


feature("ai", "AI chat")


@case("Xabar yuboriladi va javob oqib keladi")
def _():
    ai_ready()
    ai_say("salom")
    ok(st()["aiMessages"][-1] == "assistant:Salom, bu javob: salom", st()["aiMessages"])


@case("Darhol yozilgan xabar tarix yuklanishida yo'qolmaydi")
def _():
    ai_ready()
    ai_say("tez")
    ok(st()["aiMessages"][-2] == "user:tez", st()["aiMessages"])


@case("Ikkinchi savolda tarix ham yuboriladi, thinking bloki buzilmaydi")
def _():
    ai_ready()
    ai_say("birinchi")
    ai_say("ikkinchi")
    sent = fake_log()[-1]["body"]["messages"]
    ok(len(sent) == 3 and sent[1]["content"][0]["type"] == "thinking" and sent[1]["content"][0]["signature"] == "sig123", sent)


@case("Standart model va sozlamalar to'g'ri yuboriladi")
def _():
    ai_ready()
    ai_say("model")
    r = fake_log()[-1]
    ok(r["body"]["model"] == "claude-opus-5-5" and r["body"]["stream"] and r["body"]["fallbacks"] == "default" and r["beta"] == "server-side-fallback-2026-07-01", r)


@case("Sozlamadagi model ishlatiladi")
def _():
    ai_ready()
    settings(ai__model="claude-haiku-5-5")
    ai_say("x")
    ok(fake_log()[-1]["body"]["model"] == "claude-haiku-5-5")


@case("Noto'g'ri kalit tushunarli xato beradi, tarix iflos bo'lmaydi")
def _():
    ai_ready()
    ai_say("401")
    ok(st()["aiMessages"][-1].startswith("error:The API key"), st()["aiMessages"])
    ok(json.loads(run("niri-desk-ai", "history").stdout) == [])


@case("Rad etilgan javob tarixga yozilmaydi")
def _():
    ai_ready()
    ai_say("refuse")
    ok(st()["aiMessages"][-1].startswith("error:The model"))
    ok(json.loads(run("niri-desk-ai", "history").stdout) == [])


@case("To'xtatish javobni kesadi va busy qoldirmaydi")
def _():
    ai_ready()
    ai_say("sekin", done=False)
    wait(lambda: st()["aiBusy"], 3, "boshlanmadi")
    click(996, 525)
    wait(lambda: not st()["aiBusy"], 4, "to'xtamadi")


@case("Javob kutilganda ikkinchi xabar yuborilmaydi")
def _():
    ai_ready()
    ai_say("sekin", done=False)
    wait(lambda: st()["aiBusy"], 3)
    typ("yana")
    key("enter")
    time.sleep(0.5)
    ok(sum(m.startswith("user:") for m in st()["aiMessages"]) == 1, st()["aiMessages"])


@case("Kalit fayli faqat egasiga ochiq va settings.json ga tushmaydi")
def _():
    ai_ready()
    path = HOME / ".config/niri-desk/secrets/anthropic-key"
    ok(oct(path.stat().st_mode)[-3:] == "600")
    ok("sk-test" not in SET.read_text())


@case("Tozalash suhbatni va faylni o'chiradi")
def _():
    ai_ready()
    ai_say("salom")
    click(996, 525)
    wait(lambda: st()["aiMessages"] == [], 3, "tozalanmadi")
    time.sleep(0.4)
    ok(json.loads(run("niri-desk-ai", "history").stdout) == [])


feature("aicc", "AI chat: Claude Code obunasi")

FAKE_CLAUDE = Path(__file__).with_name("fake_claude.py")
CLOG = Path("/tmp/fake-claude.log")
AISESSION = STATE / "ai-session"


def cc_ready():
    FAKE_CLAUDE.chmod(0o755)
    CLOG.unlink(missing_ok=True)
    sh(["rm", "-f", str(STATE / "ai-history.json"), str(AISESSION)])
    settings(ai__backend="claude-code", ai__claudePath=str(FAKE_CLAUDE))


def cc_log():
    return [json.loads(l) for l in CLOG.read_text().splitlines()]


@case("Javob oqib keladi va tarixga yoziladi")
def _():
    cc_ready()
    ai_say("salom")
    ok(st()["aiMessages"][-1] == "assistant:Salom, bu javob: salom", st()["aiMessages"])
    ok(json.loads(run("niri-desk-ai", "history").stdout)[-1]["text"] == "Salom, bu javob: salom")


@case("Asboblar, MCP va sozlama fayllari o'chiq")
def _():
    cc_ready()
    ai_say("salom")
    a = cc_log()[-1]["args"]
    ok(a[a.index("--tools") + 1] == "" and "--strict-mcp-config" in a and a[a.index("--setting-sources") + 1] == "" and "--disable-slash-commands" in a, a)


@case("Ikkinchi xabar o'sha suhbatni davom ettiradi")
def _():
    cc_ready()
    ai_say("birinchi")
    ok("--resume" not in cc_log()[-1]["args"])
    ai_say("ikkinchi")
    a = cc_log()[-1]["args"]
    ok(a[a.index("--resume") + 1] == "session-1", a)


@case("API kaliti obuna so'roviga o'tkazilmaydi")
def _():
    cc_ready()
    r = sh(f"echo salom | ANTHROPIC_API_KEY=sk-x ANTHROPIC_AUTH_TOKEN=t {LBIN}/niri-desk-ai send")
    ok('"done"' in r.stdout, r.stdout)
    ok(cc_log()[-1]["api_key"] is None and cc_log()[-1]["token"] is None, cc_log()[-1])


@case("Kirilmagan bo'lsa tushunarli xato")
def _():
    cc_ready()
    ai_say("login")
    ok("claude auth login" in st()["aiMessages"][-1], st()["aiMessages"])


@case("Obuna limiti aytiladi, tarix iflos bo'lmaydi")
def _():
    cc_ready()
    ai_say("limit")
    ok(st()["aiMessages"][-1].startswith("error:Subscription limit"), st()["aiMessages"])
    ok(json.loads(run("niri-desk-ai", "history").stdout) == [])


@case("Rad etilgan javob tarixga yozilmaydi")
def _():
    cc_ready()
    ai_say("refuse")
    ok(st()["aiMessages"][-1].startswith("error:The model"))
    ok(json.loads(run("niri-desk-ai", "history").stdout) == [])


@case("Yo'qolgan suhbat o'rniga yangisi boshlanadi")
def _():
    cc_ready()
    AISESSION.write_text("lost-session")
    ai_say("salom")
    ok(st()["aiMessages"][-1].startswith("assistant:"), st()["aiMessages"])
    ok(AISESSION.read_text() == "session-1")


@case("To'xtatish claude jarayonini ham o'ldiradi")
def _():
    cc_ready()
    ai_say("sekin", done=False)
    wait(lambda: st()["aiBusy"], 3)
    wait(CLOG.exists, 4)
    pid = cc_log()[-1]["pid"]
    click(996, 525)
    wait(lambda: not st()["aiBusy"], 4, "to'xtamadi")
    wait(lambda: not Path(f"/proc/{pid}").exists(), 4, "jarayon qoldi")


@case("Tozalash suhbat identifikatorini ham o'chiradi")
def _():
    cc_ready()
    ai_say("salom")
    ok(AISESSION.exists())
    click(996, 525)
    wait(lambda: st()["aiMessages"] == [], 3)
    wait(lambda: not AISESSION.exists(), 3, "qoldi")


@case("claude topilmasa tushunarli xato")
def _():
    cc_ready()
    settings(ai__claudePath="/yoq/claude")
    ai_say("salom")
    ok(st()["aiMessages"][-1].startswith("error:Claude Code not found"), st()["aiMessages"])


@case("Auto rejim claude bo'lsa obunani tanlaydi")
def _():
    cc_ready()
    settings(ai__backend="auto")
    ok(json.loads(run("niri-desk-ai", "status").stdout)["backend"] == "claude-code")
    settings(ai__claudePath="/yoq/claude")
    time.sleep(0.2)
    ok(json.loads(run("niri-desk-ai", "status").stdout)["backend"] == "api")


feature("lab2", "Lab vkladkasi: nishon va qaydlar")


def notes_path(t):
    return HOME / "Pentest" / t / "notes.md"


@case("Qayd yozilsa nishon papkasiga saqlanadi")
def _():
    settings(lab__target="10.0.0.7")
    sh(["rm", "-rf", str(HOME / "Pentest")])
    dash(2)
    click(840, 200)
    typ("parol admin")
    wait(lambda: notes_path("10.0.0.7").exists() and "parol admin" in notes_path("10.0.0.7").read_text(), 4, "saqlanmadi")


@case("Qayd fayli faqat egasiga ochiq")
def _():
    settings(lab__target="10.0.0.7")
    sh(["rm", "-rf", str(HOME / "Pentest")])
    dash(2)
    click(840, 200)
    typ("x")
    wait(notes_path("10.0.0.7").exists, 4)
    ok(oct(notes_path("10.0.0.7").stat().st_mode)[-3:] == "600")


@case("Esc bosilsa oxirgi yozuv ham saqlanadi")
def _():
    settings(lab__target="10.0.0.8")
    sh(["rm", "-rf", str(HOME / "Pentest")])
    dash(2)
    click(840, 200)
    typ("oxirgi")
    key("esc")
    wait(lambda: notes_path("10.0.0.8").exists() and "oxirgi" in notes_path("10.0.0.8").read_text(), 3, "yo'qoldi")


@case("Qayta ochilganda qayd joyida turadi")
def _():
    settings(lab__target="10.0.0.9")
    notes_path("10.0.0.9").parent.mkdir(parents=True, exist_ok=True)
    notes_path("10.0.0.9").write_text("eski")
    dash(2)
    time.sleep(0.4)
    click(840, 200)
    typ("+")
    key("esc")
    wait(lambda: "+" in notes_path("10.0.0.9").read_text(), 3, "saqlanmadi")
    ok("eski" in notes_path("10.0.0.9").read_text(), "eski qayd yo'qoldi")


@case("Nishon almashganda qaydlar aralashmaydi")
def _():
    sh(["rm", "-rf", str(HOME / "Pentest")])
    settings(lab__target="10.0.0.1")
    dash(2)
    click(840, 200)
    typ("birinchi")
    time.sleep(1.2)
    settings(lab__target="10.0.0.2")
    time.sleep(0.8)
    ok("birinchi" in notes_path("10.0.0.1").read_text())
    ok(not notes_path("10.0.0.2").exists() or "birinchi" not in notes_path("10.0.0.2").read_text())


@case("Yo'ldan chiqadigan nishon qaydni yozdirmaydi")
def _():
    settings(lab__target="../evil")
    dash(2)
    click(840, 200)
    typ("x")
    time.sleep(1.2)
    ok(not (HOME / "evil").exists() and not (HOME / "notes.md").exists())


@case("Nishonsiz qayd maydoni faqat o'qish uchun")
def _():
    settings(lab__target="")
    dash(2)
    click(840, 200)
    typ("x")
    time.sleep(1.2)
    ok(not (HOME / "Pentest/notes.md").exists())


@case("Nishonni kiritish maydonidan o'zgartirish mumkin")
def _():
    settings(lab__target="")
    dash(2)
    click(390, 73)
    typ("10.9.8.7")
    key("enter")
    wait(lambda: st()["target"] == "10.9.8.7", 3, "o'zgarmadi")


@case("Nusxa tugmasi nishonni clipboard'ga qo'yadi")
def _():
    settings(lab__target="10.1.1.1")
    dash(2)
    click(545, 73)
    wait(lambda: clip_text() == "10.1.1.1", 3, "nusxalanmadi")


@case("Barcha terminal uchun nishon fayli yangilanadi")
def _():
    settings(lab__target="10.2.2.2")
    wait(lambda: (STATE / "target").read_text().strip() == "10.2.2.2", 4, "yangilanmadi")
    r = sh(["bash", "-c", f'source {HOME}/.config/niri-desk/shell.bash; eval "$PROMPT_COMMAND"; echo $TARGET'])
    ok(r.stdout.strip() == "10.2.2.2", r.stdout)


feature("pomo", "Pomodoro")


@case("Boshlash ish bosqichini va to'g'ri vaqtni qo'yadi")
def _():
    dash(0)
    click(287, 298)
    wait(lambda: st()["pomodoro"] == "work", 2, "boshlanmadi")
    ok(st()["pomodoroLeft"] > 1490)


@case("Sozlamadagi daqiqa ishlatiladi")
def _():
    settings(pomodoro__work=10)
    dash(0)
    click(287, 298)
    wait(lambda: st()["pomodoro"] == "work", 2)
    ok(590 < st()["pomodoroLeft"] <= 600)


@case("Vaqt kamayib boradi")
def _():
    ipc("pomodoro", "100")
    a = st()["pomodoroLeft"]
    time.sleep(2.2)
    ok(st()["pomodoroLeft"] < a)


@case("To'xtatilganda vaqt turadi")
def _():
    ipc("pomodoro", "100")
    dash(0)
    click(287, 298)
    wait(lambda: st()["pomodoroPaused"], 2, "to'xtamadi")
    a = st()["pomodoroLeft"]
    time.sleep(2.2)
    ok(st()["pomodoroLeft"] == a)


@case("Davom etish vaqtni yana yuradi")
def _():
    ipc("pomodoro", "100")
    dash(0)
    click(287, 298)
    wait(lambda: st()["pomodoroPaused"], 2)
    click(287, 298)
    wait(lambda: not st()["pomodoroPaused"], 2)
    a = st()["pomodoroLeft"]
    time.sleep(2.2)
    ok(st()["pomodoroLeft"] < a)


@case("Ish tugasa dam olishga o'tadi va xabar beradi")
def _():
    ipc("pomodoro", "2")
    wait(lambda: st()["pomodoro"] == "rest", 5, "o'tmadi")
    ok(st()["toast"] == "Time for a break")


@case("Dam olish tugasa ishga qaytadi")
def _():
    settings(pomodoro__rest=0.05)
    ipc("pomodoro", "1")
    wait(lambda: st()["pomodoro"] == "rest", 4)
    wait(lambda: st()["pomodoro"] == "work", 7, "qaytmadi")


@case("Bekor qilish hammasini tozalaydi")
def _():
    ipc("pomodoro", "100")
    dash(0)
    click(335, 298)
    wait(lambda: st()["pomodoro"] == "idle", 2, "bekor bo'lmadi")
    ok(st()["pomodoroLeft"] == 0)


@case("Panel yopilsa ham taymer davom etadi")
def _():
    ipc("pomodoro", "100")
    dash(0)
    key("esc")
    a = st()["pomodoroLeft"]
    time.sleep(2.2)
    ok(st()["pomodoro"] == "work" and st()["pomodoroLeft"] < a)


@case("Noto'g'ri qiymatda standart vaqt olinadi")
def _():
    settings(pomodoro__work=-3)
    dash(0)
    click(287, 298)
    wait(lambda: st()["pomodoro"] == "work", 2)
    ok(st()["pomodoroLeft"] > 1490)


feature("profile", "Ish profillari")

FOOTA = {"workspace": 1, "cmd": "foot --app-id prof-a sleep 900", "match": "^prof-a$"}
FOOTB = {"workspace": 2, "cmd": "foot --app-id prof-b sleep 900", "match": "^prof-b$"}


def wsof(app):
    ids = {w["id"]: w["idx"] for w in wsl()}
    return next((ids[w["workspace_id"]] for w in windows() if w["app_id"] == app), None)


@case("Dasturlar o'z workspace'ida ochiladi")
def _():
    write_json(PROFILES, [{"name": "T", "windows": [FOOTA, FOOTB]}])
    ok(run("niri-desk-profile", "T").returncode == 0)
    ok(wsof("prof-a") == 1 and wsof("prof-b") == 2, windows())


@case("Oxirida birinchi workspace'ga qaytadi")
def _():
    write_json(PROFILES, [{"name": "T", "windows": [FOOTA, FOOTB]}])
    run("niri-desk-profile", "T")
    ok(active_ws() == 1, active_ws())


@case("Ochiq dastur qayta ochilmaydi")
def _():
    write_json(PROFILES, [{"name": "T", "windows": [FOOTA]}])
    run("niri-desk-profile", "T")
    run("niri-desk-profile", "T")
    ok(sum(w["app_id"] == "prof-a" for w in windows()) == 1)


@case("O'rnatilmagan dastur xato chiqarmaydi va xabarda aytiladi")
def _():
    write_json(PROFILES, [{"name": "T", "windows": [{"workspace": 2, "cmd": "yoq-dastur"}, FOOTB]}])
    ok(run("niri-desk-profile", "T").returncode == 0)
    ok(wsof("prof-b") is not None)
    wait(lambda: "yoq-dastur" in st()["toastSub"], 4, "aytilmadi")


@case("Noma'lum profil xato qaytaradi")
def _():
    ok(run("niri-desk-profile", "yoq").returncode == 1)


@case("Noto'g'ri fayl dasturni yiqitmaydi")
def _():
    PROFILES.write_text("{buzuq")
    time.sleep(0.6)
    ok(run("niri-desk-profile", "T").returncode == 1)


@case("Launcher @ bilan profillarni ko'rsatadi")
def _():
    write_json(PROFILES, [{"name": "Pentest"}, {"name": "Kod"}])
    lq("@")
    ok(len(row("Work profiles")) == 2, st()["rows"])
    ipc("launcherQuery", "@pen")
    time.sleep(0.4)
    ok(len(row("Work profiles")) == 1)


@case("Launcher'dan ochish ishlaydi")
def _():
    write_json(PROFILES, [{"name": "T", "windows": [FOOTA]}])
    lq("@T")
    key("enter")
    wait(lambda: wsof("prof-a") == 1, 6, "ochilmadi")


@case("VPN yoqilgan profil VPN buyrug'ini bajaradi")
def _():
    settings(vpn__up="touch /tmp/nd-vpn.flag")
    write_json(PROFILES, [{"name": "T", "vpn": True, "windows": []}])
    run("niri-desk-profile", "T")
    wait(lambda: Path("/tmp/nd-vpn.flag").exists(), 3, "bajarilmadi")


@case("Fayl o'zgarsa ro'yxat qayta o'qiladi")
def _():
    write_json(PROFILES, [{"name": "A"}])
    wait(lambda: st()["profiles"] == 1, 3)
    write_json(PROFILES, [{"name": "A"}, {"name": "B"}, {"name": "C"}])
    wait(lambda: st()["profiles"] == 3, 3, "yangilanmadi")


feature("restore", "Sessiyani tiklash")

SESSION = STATE / "session.json"


@case("Saqlash ochiq oynalarni workspace bilan yozadi")
def _():
    foot("a", "foot")
    run("niri-desk-session", "save")
    items = json.loads(SESSION.read_text())
    ok(len(items) == 1 and items[0]["exe"] == "foot", items)


@case("Xizmat oynalari saqlanmaydi")
def _():
    term("t", cls="niri-desk-tool")
    run("niri-desk-session", "save")
    ok(json.loads(SESSION.read_text()) == [])


@case("Tiklash dasturni ochadi")
def _():
    write_json(SESSION, [{"app": "foot", "exe": "foot", "workspace": 1, "share": 0}])
    run("niri-desk-session", "restore", "--force")
    wait(lambda: windows(), 6, "ochilmadi")


@case("Argumentlar qayta bajarilmaydi")
def _():
    w = foot("a", "foot")
    run("niri-desk-session", "save")
    niri("close-window", "--id", w)
    wait(lambda: not windows(), 3)
    run("niri-desk-session", "restore", "--force")
    w2 = wait(windows, 6)[0]
    args = Path(f"/proc/{w2['pid']}/cmdline").read_bytes()
    ok(b"sleep" not in args, args)


@case("Ochiq oyna bo'lsa tiklash hech narsa qilmaydi")
def _():
    write_json(SESSION, [{"app": "foot", "exe": "foot", "workspace": 1}])
    term("t")
    run("niri-desk-session", "restore", "--force")
    ok(len(windows()) == 1)


@case("Sozlama o'chiq bo'lsa kirishda tiklanmaydi")
def _():
    write_json(SESSION, [{"app": "foot", "exe": "foot", "workspace": 1}])
    settings(session__restore=False)
    run("niri-desk-session", "restore")
    time.sleep(0.8)
    ok(windows() == [])


@case("Buzuq fayl xato bermaydi")
def _():
    SESSION.write_text("{")
    ok(run("niri-desk-session", "restore", "--force").returncode == 0)


@case("O'rnatilmagan dastur o'tkazib yuboriladi")
def _():
    write_json(SESSION, [{"exe": "yoq-dastur", "workspace": 1}, {"exe": "foot", "workspace": 1}])
    r = run("niri-desk-session", "restore", "--force")
    ok(r.returncode == 0, r.stderr)
    ok(len(windows()) == 1, f"{windows()} {SESSION.read_text()[:120]}")


@case("Yo'l ko'rinishidagi buyruq bajarilmaydi")
def _():
    write_json(SESSION, [{"exe": "/tmp/nd-x", "workspace": 1}])
    Path("/tmp/nd-x").write_text("#!/bin/sh\ntouch /tmp/nd-ran.flag\n")
    Path("/tmp/nd-x").chmod(0o755)
    run("niri-desk-session", "restore", "--force")
    time.sleep(0.5)
    ok(not Path("/tmp/nd-ran.flag").exists())


@case("Workspace to'g'ri tiklanadi")
def _():
    write_json(SESSION, [{"exe": "foot", "workspace": 1}, {"exe": "kitty", "workspace": 2}])
    run("niri-desk-session", "restore", "--force")
    ok(wsof("foot") == 1 and wsof("kitty") == 2, windows())


feature("files", "Launcher: fayl qidiruvi")

FDIR = HOME / "nd-fayllar"


def fileset():
    sh(["rm", "-rf", str(FDIR)])
    FDIR.mkdir()
    (FDIR / "parol-royxat.txt").write_text("x")
    (FDIR / "hisobot 2026.txt").write_text("x")
    (FDIR / ".yashirin-parol").write_text("x")


def names():
    return row("Files")


for _q, _want in [("/parol-royxat", True), ("/PAROL-ROYXAT", True), ("/hisobot 2026", True), ("/yoq-bunday-fayl", False)]:
    @case(f"{_q} qidiruvi")
    def _(q=_q, want=_want):
        fileset()
        lq(q)
        if want:
            wait(lambda: len(names()) >= 1, 4, "topilmadi")
        else:
            time.sleep(1)
            ok(names() == [])


@case("Bitta harfda qidiruv boshlanmaydi")
def _():
    lq("/p")
    ok(names() == ["Type at least 2 letters"], names())


@case("Yashirin fayllar chiqmaydi")
def _():
    fileset()
    lq("/yashirin")
    time.sleep(1)
    ok(names() == [])


@case("Maxsus belgilar buyruq sifatida bajarilmaydi")
def _():
    lq("/; touch /tmp/nd-inj.flag")
    time.sleep(1)
    ok(not Path("/tmp/nd-inj.flag").exists())


@case("-- bilan boshlangan so'z fd bayrog'iga aylanmaydi")
def _():
    lq("/--help")
    time.sleep(1)
    ok(st()["popup"] == "launcher")


@case("Natijalar 9 tadan oshmaydi")
def _():
    fileset()
    for i in range(14):
        (FDIR / f"ko'p-{i}.txt").write_text("x")
    lq("/ko'p")
    wait(lambda: len(names()) >= 1, 4)
    ok(len(names()) <= 9)


@case("Enter faylni ochadi")
def _():
    fileset()
    lq("/parol-royxat")
    wait(lambda: len(names()) >= 1, 4)
    key("enter")
    wait(lambda: st()["popup"] == "", 3, "yopilmadi")


feature("snip", "Snippetlar")


@case("; hammasini ko'rsatadi")
def _():
    lq(";")
    ok(len(row("Snippets")) >= 5, st()["rows"])


@case("Nom bo'yicha filtrlaydi")
def _():
    lq(";rev")
    ok(len(row("Snippets")) == 1 and "rev-bash" in row("Snippets")[0])


@case("{target} joriy nishon bilan to'ldiriladi")
def _():
    settings(lab__target="10.5.5.5")
    lq(";nmap-quick")
    ok("10.5.5.5" in row("Snippets")[0], row("Snippets"))


@case("{lport} sozlamadan olinadi")
def _():
    settings(lab__lport=9001)
    lq(";listener")
    ok("9001" in row("Snippets")[0])


@case("{lhost} VPN yo'q bo'lsa sozlamadan olinadi")
def _():
    settings(lab__lhost="10.6.6.6")
    lq(";rev")
    ok("10.6.6.6" in row("Snippets")[0])


@case("Oddiy snippet Enter bilan nusxalanadi")
def _():
    settings(lab__lhost="10.6.6.6")
    lq(";rev")
    key("enter")
    wait(lambda: "10.6.6.6" in clip_text(), 3, "nusxalanmadi")


@case("run snippet terminalda ishlaydi")
def _():
    write_json(SNIPPETS, [{"name": "x", "text": "touch /tmp/nd-snip.flag", "run": True}])
    lq(";x")
    key("enter")
    wait(lambda: Path("/tmp/nd-snip.flag").exists(), 4, "ishlamadi")


@case("Nishon bo'sh bo'lsa run snippet bajarilmaydi, nusxalanadi")
def _():
    settings(lab__target="")
    write_json(SNIPPETS, [{"name": "x", "text": "touch /tmp/nd-empty.flag {target}", "run": True}])
    lq(";x")
    key("enter")
    time.sleep(0.8)
    ok(not Path("/tmp/nd-empty.flag").exists())
    ok("{target}" in clip_text())


@case("Xavfli nishon buyruqqa kirmaydi")
def _():
    settings(lab__target="1;touch /tmp/nd-inj.flag")
    write_json(SNIPPETS, [{"name": "x", "text": "echo {target}", "run": True}])
    lq(";x")
    key("enter")
    time.sleep(0.8)
    ok(not Path("/tmp/nd-inj.flag").exists())


@case("Buzuq fayl eski ro'yxatni saqlab xabar beradi")
def _():
    n = st()["snippets"]
    SNIPPETS.write_text("[{")
    wait(lambda: st()["toast"] == "Could not read a file", 3, "aytilmadi")
    ok(st()["snippets"] == n)


feature("evidence", "Skrinshot va video nishon papkasiga")


def edir(t="10.3.3.3"):
    return HOME / "Pentest" / t


def on(t="10.3.3.3"):
    settings(lab__target=t, lab__evidence=True)
    wait(lambda: (STATE / "evidence-dir").read_text().strip() != "", 4, "yoqilmadi")


@case("Yoqilganda papka yaratiladi")
def _():
    sh(["rm", "-rf", str(HOME / "Pentest")])
    on()
    ok((edir() / "shots").is_dir())


@case("Skrinshot nishon papkasiga tushadi")
def _():
    sh(["rm", "-rf", str(HOME / "Pentest")])
    on()
    time.sleep(1)
    niri("screenshot-screen")
    wait(lambda: list((edir() / "shots").glob("*.png")), 4, "tushmadi")


@case("Fayl nomida sana va vaqt bor")
def _():
    sh(["rm", "-rf", str(HOME / "Pentest")])
    on()
    time.sleep(1)
    niri("screenshot-screen")
    f = wait(lambda: list((edir() / "shots").glob("*.png")), 4)[0]
    ok(re.fullmatch(r"\d{4}-\d\d-\d\d_\d\d-\d\d-\d\d\.png", f.name), f.name)


@case("O'chiq bo'lsa odatiy papka ishlatiladi")
def _():
    settings(lab__target="10.3.3.3", lab__evidence=False)
    ok("Pentest" not in (GEN / "settings.kdl").read_text())


@case("Nishon almashsa yo'l ham almashadi")
def _():
    on("10.3.3.4")
    wait(lambda: "10.3.3.4" in (GEN / "settings.kdl").read_text(), 3, "almashmadi")


@case("Nishonsiz yig'ilmaydi")
def _():
    settings(lab__target="", lab__evidence=True)
    ok("Pentest" not in (GEN / "settings.kdl").read_text())


@case("Xavfli nishon ishlatilmaydi")
def _():
    settings(lab__target="../../x", lab__evidence=True)
    ok("Pentest" not in (GEN / "settings.kdl").read_text())
    ok(not (HOME.parent / "x").exists())


@case("IPv6 nishon papka nomida ishlaydi")
def _():
    on("fe80::1")
    ok((HOME / "Pentest/fe80__1/shots").is_dir())


@case("Boshqa papka tanlash mumkin")
def _():
    settings(lab__target="10.3.3.3", lab__evidence=True, lab__dir="~/Boshqa")
    wait(lambda: (HOME / "Boshqa/10.3.3.3/shots").is_dir(), 3, "yaratilmadi")
    sh(["rm", "-rf", str(HOME / "Boshqa")])


@case("Video yozuvi ham shu papkaga yo'naltiriladi")
def _():
    on()
    ok(str(edir()) in (STATE / "evidence-dir").read_text())
    ok("evidence" in (LBIN / "niri-desk-record").read_text())


feature("hosts", "HTB/THM: /etc/hosts")


def hosts_clean():
    sh("sudo sed -i '/nd-test/d' /etc/hosts")


@case("Nom qo'shiladi")
def _():
    hosts_clean()
    settings(lab__target="10.7.7.7")
    ok(run("niri-desk-hosts", "nd-test.htb").returncode == 0)
    ok("10.7.7.7\tnd-test.htb" in Path("/etc/hosts").read_text())
    hosts_clean()


@case("Takror qo'shilmaydi")
def _():
    hosts_clean()
    settings(lab__target="10.7.7.7")
    run("niri-desk-hosts", "nd-test.htb")
    run("niri-desk-hosts", "nd-test.htb")
    ok(Path("/etc/hosts").read_text().count("nd-test.htb") == 1)
    hosts_clean()


@case("IP qo'lda berilishi mumkin")
def _():
    hosts_clean()
    run("niri-desk-hosts", "nd-test2.htb", "10.8.8.8")
    ok("10.8.8.8\tnd-test2.htb" in Path("/etc/hosts").read_text())
    hosts_clean()


for _n, _bad in enumerate(["a b", "x;touch /tmp/nd-h", "-rf", "$(id)"]):
    @case(f"Noto'g'ri nom rad etiladi ({_bad})")
    def _(bad=_bad):
        before = Path("/etc/hosts").read_text()
        ok(run("niri-desk-hosts", bad, "10.0.0.1").returncode == 2)
        ok(Path("/etc/hosts").read_text() == before)


@case("Noto'g'ri IP rad etiladi")
def _():
    ok(run("niri-desk-hosts", "nd-test.htb", "abc;id").returncode == 2)


@case("Nishon bo'sh bo'lsa rad etiladi")
def _():
    settings(lab__target="")
    ok(run("niri-desk-hosts", "nd-test.htb").returncode == 2)


@case("Launcher hosts buyrug'ini ko'rsatadi")
def _():
    settings(lab__target="10.7.7.7")
    lq("hosts box.htb")
    ok(any("box.htb" in r for r in row("Pentest")), st()["rows"])


feature("encode2", "Yangi kodlashlar")

for _q, _label, _value in [
    ("sha256 abc", "SHA-256", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
    ("html <b>", "HTML encoded", "&lt;b&gt;"),
    ("htmld &lt;b&gt;", "HTML decoded", "<b>"),
    ("jwt eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWRtaW4ifQ.x", "JWT", "admin"),
    ("hashid 5f4dcc3b5aa765d61d8327deb882cf99", "Xesh", "MD5"),
    ("hashid da39a3ee5e6b4b0d3255bfef95601890afd80709", "Xesh", "SHA-1"),
    ("hashid $2y$10$abcdefghij", "Xesh", "bcrypt"),
    ("hashid $6$salt$hash", "Xesh", "SHA-512"),
]:
    @case(f"{_q[:28]}")
    def _(q=_q, value=_value):
        lq(q)
        ok(any(value in r for r in st()["rows"]), st()["rows"])


@case("Buzuq JWT ochilmaydi, xato bermaydi")
def _():
    lq("jwt abc")
    ok(any("Could not decode" in r for r in st()["rows"]), st()["rows"])


@case("Natija Enter bilan nusxalanadi")
def _():
    lq("sha256 abc")
    key("enter")
    wait(lambda: clip_text().startswith("ba7816bf"), 3, "nusxalanmadi")


feature("layoutfix", "Noto'g'ri klaviatura tuzatish")

for _q, _want in [("лшеен", "kitty"), ("ащще", "foot"), ("ащ", "foot")]:
    @case(f"{_q} -> {_want}")
    def _(q=_q, want=_want):
        lq(q)
        ok(any(want in r.lower() for r in st()["rows"]), st()["rows"])


@case("Lotin yozuvi oldingidek ishlaydi")
def _():
    lq("kitty")
    ok(any("kitty" in r.lower() for r in st()["rows"]))


@case("To'g'ri moslik birinchi turadi")
def _():
    lq("kitty")
    ok("kitty" in st()["rows"][0].lower(), st()["rows"])


@case("Enter tuzatilgan natijani ochadi")
def _():
    lq("лшеен")
    key("enter")
    wait(windows, 6, "ochilmadi")


@case("Bo'sh qidiruv buzilmaydi")
def _():
    lq("")
    ok(st()["popup"] == "launcher" and st()["rows"])


@case("Raqam va belgilar o'zgarmaydi")
def _():
    lq("=2+2")
    ok(any("4" in r for r in st()["rows"]), st()["rows"])


@case("Topilmagan so'z bo'sh ro'yxat beradi")
def _():
    lq("зшщзшщзшщ")
    ok(not any("kitty" in r for r in st()["rows"]))


@case("Aralash yozuv yiqitmaydi")
def _():
    lq("kлш")
    ok(st()["popup"] == "launcher")


feature("translate", "Ekrandan tarjima")

SHIM = Path("/tmp/nd-shim")


def shim(text="Hello", trans_ok=True, slurp_ok=True):
    SHIM.mkdir(exist_ok=True)
    Path("/tmp/nd-trans.args").unlink(missing_ok=True)
    tools = {
        "slurp": "echo '0,0 10x10'" if slurp_ok else "exit 1",
        "grim": "echo png",
        "tesseract": f'case "$1" in --list-langs) printf "List\\neng\\nosd\\n";; *) cat >/dev/null; echo "$*" > /tmp/nd-tess.args; printf %s "{text}";; esac',
        "trans": 'echo "$*" > /tmp/nd-trans.args; echo Salom' if trans_ok else "exit 1",
    }
    for name, body in tools.items():
        p = SHIM / name
        p.write_text(f"#!/bin/sh\n{body}\n")
        p.chmod(0o755)


def tr():
    return sh(f"PATH={SHIM}:$PATH {LBIN}/niri-desk-translate", timeout=8)


def tr_bg():
    # Haqiqiy klavish kabi niri orqali: oyna niri muhitida ochiladi.
    niri("spawn", "--", "sh", "-c", f"PATH={SHIM}:$PATH exec {LBIN}/niri-desk-translate")


@case("Natija oynada ochiladi")
def _():
    shim()
    tr_bg()
    w = wait(windows, 12, sh("pgrep -a kitty; pgrep -af translate; ls -la /tmp/nd-trans.args").stdout)[0]
    ok(w["title"] == "niri-desk translate", w)


@case("Oyna suzib turadi")
def _():
    shim()
    tr_bg()
    ok(wait(windows, 12)[0]["is_floating"])


@case("Natija clipboard'ga tushadi")
def _():
    shim()
    tr_bg()
    wait(lambda: clip_text() == "Salom", 5, "nusxalanmadi")
    wait(windows, 12, "ochilmadi")


@case("Tanlov bekor qilinsa hech narsa bo'lmaydi")
def _():
    shim(slurp_ok=False)
    ok(tr().returncode == 0)
    ok(windows() == [])


@case("Matn bo'lmasa xabar beradi")
def _():
    shim(text="")
    tr()
    wait(lambda: st()["toast"] == "No text found", 3, "aytilmadi")


@case("Internet bo'lmasa asl matn nusxalanadi")
def _():
    shim(trans_ok=False)
    tr()
    wait(lambda: st()["toast"] == "Translation failed", 3, "aytilmadi")
    ok(clip_text() == "Hello")


@case("Til sozlamadan olinadi")
def _():
    settings(translate__to="ru")
    shim()
    tr_bg()
    wait(lambda: Path("/tmp/nd-trans.args").exists() and ":ru" in Path("/tmp/nd-trans.args").read_text(), 5, "til o'tmadi")


@case("Standart til o'zbekcha")
def _():
    shim()
    tr_bg()
    wait(lambda: Path("/tmp/nd-trans.args").exists() and ":en" in Path("/tmp/nd-trans.args").read_text(), 5, "til o'tmadi")


@case("OCR xato qilsa jim to'xtamaydi, xabar beradi")
def _():
    shim()
    (SHIM / "tesseract").write_text('#!/bin/sh\ncase "$1" in --list-langs) echo List;; *) exit 3;; esac\n')
    tr()
    wait(lambda: st()["toast"] == "No text found", 3, "aytilmadi")


@case("Klavish sozlangan")
def _():
    ok("niri-desk-translate" in (GEN / "binds.kdl").read_text())


@case("Launcher'da bor")
def _():
    lq("translate")
    ok(any("translate" in r.lower() for r in st()["rows"]))


feature("monitors", "Monitor profillari")


def out():
    return next(iter(json.loads(sh("niri msg --json outputs").stdout).items()))


def outname():
    return out()[0]


@case("Masshtab qo'llanadi")
def _():
    settings(**{f"monitors__{outname()}__scale": 1.25})
    wait(lambda: abs(out()[1]["logical"]["scale"] - 1.25) < 0.01, 4, "qo'llanmadi")


@case("Aylantirish qo'llanadi")
def _():
    settings(**{f"monitors__{outname()}__transform": "90"})
    wait(lambda: out()[1]["logical"]["transform"] == "90" or out()[1]["logical"]["transform"] == "Rotate90", 4, str(out()[1]["logical"]))


@case("Joy qo'llanadi")
def _():
    settings(**{f"monitors__{outname()}__x": 100, f"monitors__{outname()}__y": 50})
    wait(lambda: out()[1]["logical"]["x"] == 100, 4, "qo'llanmadi")


@case("Faqat X berilsa Y nol olinadi")
def _():
    settings(**{f"monitors__{outname()}__x": 200})
    ok("position x=200 y=0" in (GEN / "settings.kdl").read_text())


@case("Sozlama olib tashlansa asliga qaytadi")
def _():
    settings(**{f"monitors__{outname()}__scale": 1.5})
    wait(lambda: abs(out()[1]["logical"]["scale"] - 1.5) < 0.01, 4)
    SET.write_text(GOOD)
    wait(lambda: abs(out()[1]["logical"]["scale"] - 1) < 0.01, 4, "qaytmadi")


@case("Ulanmagan monitor uchun qoida xato bermaydi")
def _():
    settings(**{"monitors__HDMI-A-9__scale": 2})
    ok('output "HDMI-A-9"' in (GEN / "settings.kdl").read_text())


@case("off yoqilsa kdl'ga yoziladi")
def _():
    settings(**{"monitors__HDMI-A-9__off": True})
    wait(lambda: "HDMI-A-9" in (GEN / "settings.kdl").read_text() and "off" in (GEN / "settings.kdl").read_text(), 4, "yozilmadi")


@case("Chegaradan tashqari masshtab rad etiladi va eski saqlanadi")
def _():
    settings(**{f"monitors__{outname()}__scale": 99})
    wait(lambda: st()["error"] != "", 3, "xato aytilmadi")
    ok("scale 99" not in (GEN / "settings.kdl").read_text())


@case("Noto'g'ri aylantirish rad etiladi")
def _():
    settings(**{f"monitors__{outname()}__transform": "45"})
    wait(lambda: st()["error"] != "", 3, "xato aytilmadi")


@case("Sozlamalarda Monitorlar sahifasi bor")
def _():
    ok('Tr.t("Monitors")' in (HOME / ".config/quickshell/niri-desk/modules/SettingsWindow.qml").read_text())


feature("sched", "Kechki rejim jadvali")


def hm(delta=0):
    return time.strftime("%H:%M", time.localtime(time.time() + delta * 60))


def mode():
    return json.loads(SET.read_text()).get("appearance", {}).get("mode", "dark")


@case("Yorug' vaqtda yorug' rejim yoqiladi")
def _():
    settings(schedule__mode=True, schedule__lightFrom=hm(-60), schedule__darkFrom=hm(60))
    wait(lambda: mode() == "light", 4, "yoqilmadi")


@case("Qorong'i vaqtda qorong'i rejim yoqiladi")
def _():
    settings(appearance__mode="light", schedule__mode=True, schedule__lightFrom=hm(60), schedule__darkFrom=hm(-60))
    wait(lambda: mode() == "dark", 4, "yoqilmadi")


@case("O'chiq bo'lsa o'zgartirmaydi")
def _():
    settings(schedule__mode=False, schedule__lightFrom=hm(-60), schedule__darkFrom=hm(60))
    time.sleep(1)
    ok(mode() == "dark")


@case("Noto'g'ri vaqt standartga tushadi va yiqitmaydi")
def _():
    settings(schedule__mode=True, schedule__lightFrom="abc", schedule__darkFrom="99")
    time.sleep(1)
    ok("niri-desk-top" in layers())


@case("Rang rejimga qarab o'zgaradi")
def _():
    a = st()["accent"]
    settings(schedule__mode=True, schedule__lightFrom=hm(-60), schedule__darkFrom=hm(60))
    wait(lambda: st()["accent"] != a, 6, "rang o'zgarmadi")


@case("Tungi jadval wlsunset vaqtlari bilan ishlaydi")
def _():
    settings(nightlight__auto=True, nightlight__from="21:00", nightlight__to="06:30")
    ipc("reset")
    wait(lambda: "-s 21:00" in sh("ps -eo args | grep [w]lsunset").stdout, 4, "ishlamadi")
    ok("-S 06:30" in sh("ps -eo args | grep [w]lsunset").stdout)


@case("Tungi jadval o'chsa qo'lda rejim eski holatda")
def _():
    settings(nightlight__auto=False)
    ipc("reset")
    time.sleep(0.5)
    ok(sh("pgrep -x wlsunset").returncode != 0)


@case("Tungi harorat jadvalda ham qo'llanadi")
def _():
    settings(nightlight__auto=True, nightlight__temperature=3500)
    ipc("reset")
    wait(lambda: "-t 3500" in sh("ps -eo args | grep [w]lsunset").stdout, 4, "qo'llanmadi")


@case("Yarim tunni kesib o'tgan jadval")
def _():
    settings(schedule__mode=True, schedule__lightFrom=hm(-1), schedule__darkFrom=hm(-2))
    wait(lambda: mode() == "light", 4, "hisob xato")


@case("Sozlamalarda vaqt maydonlari bor")
def _():
    text = (HOME / ".config/quickshell/niri-desk/modules/SettingsWindow.qml").read_text()
    ok("schedule.lightFrom" in text and "nightlight.from" in text)


feature("backup", "Sozlamalarni zaxiralash")

BK = Path("/tmp/nd-backup.tar.gz")


def export():
    BK.unlink(missing_ok=True)
    ok(run("niri-desk-backup", "export", str(BK)).returncode == 0)


def members(path=BK):
    import tarfile
    with tarfile.open(path) as t:
        return t.getnames()


@case("Eksport fayl yaratadi")
def _():
    export()
    ok(BK.stat().st_size > 0)


@case("Yo'l berilmasa uy papkasiga yozadi")
def _():
    p = Path(run("niri-desk-backup", "export").stdout.strip())
    ok(p.parent == HOME and p.exists())
    p.unlink()


@case("API kaliti zaxiraga kirmaydi")
def _():
    sh(f"echo sk-test | {LBIN}/niri-desk-ai set-key")
    export()
    ok(not any("secret" in n or "key" in n for n in members()), members())


@case("Sozlama va profillar bor")
def _():
    export()
    ok("niri-desk/settings.json" in members() and "niri-desk/profiles.json" in members())


@case("Import sozlamani qaytaradi")
def _():
    settings(windows__gaps=7)
    export()
    SET.write_text(GOOD)
    time.sleep(0.8)
    ok(run("niri-desk-backup", "import", str(BK)).returncode == 0)
    ok(json.loads(SET.read_text())["windows"]["gaps"] == 7)


@case("Import niri'ga qo'llanadi")
def _():
    settings(windows__gaps=7)
    export()
    SET.write_text(GOOD)
    time.sleep(0.8)
    run("niri-desk-backup", "import", str(BK))
    ok("gaps 7" in (GEN / "settings.kdl").read_text())


def evil(names):
    import io, tarfile
    p = Path("/tmp/nd-evil.tar.gz")
    with tarfile.open(p, "w:gz") as t:
        for n in names:
            info = tarfile.TarInfo(n)
            data = b"{}"
            info.size = len(data)
            t.addfile(info, io.BytesIO(data))
    return p


@case("Tashqi yo'lli arxiv rad etiladi")
def _():
    p = evil(["../../nd-pwn"])
    ok(run("niri-desk-backup", "import", str(p)).returncode == 1)
    ok(not (HOME.parent / "nd-pwn").exists())


@case("Boshqa konfig faylini almashtira olmaydi")
def _():
    p = evil(["hypr/hyprlock.conf"])
    ok(run("niri-desk-backup", "import", str(p)).returncode == 1)


@case("Buzuq fayl sozlamani buzmaydi")
def _():
    Path("/tmp/nd-bad.tar.gz").write_text("emas")
    before = SET.read_text()
    ok(run("niri-desk-backup", "import", "/tmp/nd-bad.tar.gz").returncode == 1)
    ok(SET.read_text() == before)


@case("Yo'q fayl xato qaytaradi")
def _():
    ok(run("niri-desk-backup", "import", "/tmp/nd-yoq.tar.gz").returncode == 1)



feature("i18n", "Interfeys tili")

CATALOG = HOME / ".config/niri-desk/i18n-ru.json"
QS = HOME / ".config/quickshell/niri-desk"


@case("Inglizcha tanlansa matn inglizcha")
def _():
    settings(appearance__language="en")
    wait(lambda: st()["lang"] == "en" and st()["sample"] == "Settings", 3, "almashmadi")


@case("Ruscha tanlansa matn ruscha")
def _():
    settings(appearance__language="ru")
    wait(lambda: st()["lang"] == "ru" and st()["sample"] == "Настройки", 3, "almashmadi")


@case("Launcher bo'limlari tilga ergashadi")
def _():
    settings(appearance__language="ru")
    wait(lambda: st()["lang"] == "ru", 3)
    lq("=2+2")
    ok(any(r.startswith("Калькулятор|") for r in st()["rows"]), st()["rows"])


@case("Skript xabari tilga ergashadi")
def _():
    settings(appearance__language="ru")
    ok(run("niri-desk-profile", "yoq").returncode == 1)
    wait(lambda: st()["toast"] == "Профиль не найден", 3, "tarjima bo'lmadi")


@case("Klavish sarlavhalari tilga ergashadi")
def _():
    settings(appearance__language="ru")
    wait(lambda: "Закрыть окно" in (GEN / "binds.kdl").read_text(), 4, "tarjima bo'lmadi")


@case("Bloklash ekrani matni tilga ergashadi")
def _():
    settings(appearance__language="ru")
    path = HOME / ".config/hypr/niri-desk-lang.conf"
    wait(lambda: "Пароль" in path.read_text(), 4, "tarjima bo'lmadi")
    settings(appearance__language="en")
    wait(lambda: "Password" in path.read_text(), 4, "qaytmadi")


@case("Sozlama xatosi tilga ergashadi")
def _():
    settings(appearance__language="ru", windows__gaps=9999)
    wait(lambda: "должно быть" in st()["error"], 4, st()["error"])


@case("AI xatosi tilga ergashadi")
def _():
    settings(appearance__language="ru", ai__baseUrl="http://127.0.0.1:1")
    r = sh(f"echo x | {LBIN}/niri-desk-ai send")
    ok("интернету" in r.stdout or "Ключ" in r.stdout, r.stdout)


@case("Kodda ishlatilgan har bir matnning ruscha tarjimasi bor")
def _():
    cat = json.loads(CATALOG.read_text())
    used = set()
    for f in QS.rglob("*.qml"):
        used |= set(re.findall(r'Tr\.t\("([^"]+)"\)', f.read_text()))
    for f in LBIN.glob("niri-desk-*"):
        text = f.read_text(errors="ignore")
        used |= set(re.findall(r'\btr\(\s*"([^"]+)"', text))
        used |= set(re.findall(r'_t "([^"]+)"', text))
    missing = sorted(u for u in used if u not in cat and not re.fullmatch(r"[A-Z0-9 .+-]{1,4}", u))
    ok(len(used) > 250 and not missing, missing[:12])


@case("Kataloglarda o'zbekcha matn qolmagan")
def _():
    uz = re.compile(r"\b(yoq|o'chiq|Tozalash|Nusxalandi|Sozlamalar|bo'l|qiling|noto'g'ri|topilmadi)\b")
    bad = []
    for f in list(QS.rglob("*.qml")) + list(LBIN.glob("niri-desk-*")):
        for i, line in enumerate(f.read_text(errors="ignore").splitlines(), 1):
            code = line.strip()
            if code.startswith(("//", "#")):
                continue
            for lit in re.findall(r'"([^"]*)"', line):
                if uz.search(lit):
                    bad.append(f"{f.name}:{i}:{lit[:40]}")
    ok(not bad, bad[:10])


def main():
    global GOOD
    args = sys.argv[1:]
    only = None
    if "--only" in args:
        only = set(args[args.index("--only") + 1].split(","))
    if "--list" in args:
        for f in FEATURES:
            print(f["id"], len(f["cases"]), f["title"])
        return
    FAILDIR.mkdir(exist_ok=True)
    # Sinov paytida ekran o'zi bloklanmasin. Oxirida foydalanuvchi sozlamasi qaytariladi.
    original = SET.read_text()
    base = json.loads(original or "{}")
    base.setdefault("appearance", {})["language"] = "en"
    base["idle"] = {"lock": 0, "screenOff": 0, "suspend": 0}
    GOOD = json.dumps(base, indent=2)
    if sh("pgrep -x hyprlock").returncode == 0 and PW:
        typ(PW)
        key("enter")
        time.sleep(1)
    SET.write_text(GOOD)
    time.sleep(1.5)
    report = json.loads(Path("/tmp/niri-desk-report.json").read_text()) if only and Path("/tmp/niri-desk-report.json").exists() else {}
    for f in FEATURES:
        if only and f["id"] not in only:
            continue
        results = []
        for n, (desc, fn) in enumerate(f["cases"], 1):
            status, note = "PASS", ""
            try:
                reset()
                fn()
            except Skip as e:
                status, note = "SKIP", str(e)
            except Exception as e:
                status, note = "FAIL", f"{type(e).__name__}: {e}"[:300]
                try:
                    shot_path = FAILDIR / f"{f['id']}-{n}.png"
                    sh(["grim", str(shot_path)])
                except Exception:
                    pass
            results.append({"n": n, "desc": desc, "status": status, "note": note})
            print(f"{status} {f['id']}#{n} {desc}" + (f"  <- {note}" if note else ""), flush=True)
        report[f["id"]] = {"title": f["title"], "cases": results}
        Path("/tmp/niri-desk-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1))
    try:
        reset()
    except Exception:
        pass
    SET.write_text(original)
    all_cases = [c for r in report.values() for c in r["cases"]]
    print("JAMI", len(all_cases), {s: sum(c["status"] == s for c in all_cases) for s in ("PASS", "FAIL", "SKIP")})


main()
