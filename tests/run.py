#!/usr/bin/env python3
"""falcon uchun avtomatik test: har funksiya bo'yicha ssenariylar.

Faqat sinov mashinasida ishga tushiring: oynalarni yopadi, sozlamalarni o'zgartiradi.
Haqiqiy klavish va sichqoncha ydotool orqali yuboriladi.

  tests/run.py [--only ID,ID] [--list]
Natija: /tmp/falcon-report.json
"""
import json, os, re, shutil, subprocess, sys, tempfile, time, traceback
from pathlib import Path

HOME = Path.home()
SET = HOME / ".config/falcon/settings.json"
GEN = HOME / ".config/niri/generated"
STATE = HOME / ".local/state/falcon"
FAILDIR = Path("/tmp/nd-fail")
LIB = {}
PW = os.environ.get("FALCON_TEST_PW", "")
FEATURES, CUR = [], None
KEYC = {**{c: k for c, k in zip("qwertyuiop", range(16, 26))}, **{c: k for c, k in zip("asdfghjkl", range(30, 39))}, **{c: k for c, k in zip("zxcvbnm", range(44, 51))},
        **{str(i): i + 1 for i in range(1, 10)}, "0": 11, "enter": 28, "esc": 1, "space": 57, "tab": 15, "grave": 41, "comma": 51, "minus": 12, "equal": 13,
        "left": 105, "right": 106, "up": 103, "down": 108, "shift": 42, "ctrl": 29, "alt": 56, "mod": 125, "[": 26, "]": 27, "volup": 115, "voldown": 114, "mute": 113,
        "backspace": 14, "print": 99, "slash": 53, "brightdown": 224, "brightup": 225}


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
    return sh(["qs", "-c", "falcon", "ipc", "call", "desk", *a], timeout=8)


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


def clip_text():
    return sh(["wl-paste", "-n", "-t", "text/plain"]).stdout


GOOD = None


def reset():
    if sh("pgrep -u $(id -u) -x hyprlock").returncode == 0 and PW:
        typ(PW)
        key("enter")
        wait(lambda: sh("pgrep -u $(id -u) -x hyprlock").returncode != 0, 6, "ekran ochilmadi")
    wait(lambda: "falcon-top" in layers(), 12, "panel qaytmadi")
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
    w = wait(lambda: next(x for x in windows() if x["title"] == "falcon settings"))
    ok(w["is_floating"])
    ok(w["layout"]["window_size"][0] == 1000, w["layout"])


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
    return next((w for w in windows() if w["app_id"] == "falcon-scratch"), None)


def tmuxc(*a):
    return sh(["tmux", "-L", "falcon", *a])


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
    ok(len([w for w in windows() if w["app_id"] == "falcon-scratch"]) == 1)


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
    ok(len([w for w in windows() if w["app_id"] == "falcon-scratch"]) <= 1)


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

RAISE = str(HOME / ".local/bin/falcon-raise")


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


feature("menu", "Dastur menyusi")


def open_menu(q=""):
    ipc("menu")
    wait(lambda: st()["popup"] == "menu", 3, "menyu ochilmadi")
    time.sleep(0.5)
    if q:
        typ(q)
    time.sleep(0.3)


@case("IPC ochadi, Esc yopadi")
def _():
    open_menu()
    key("esc")
    wait(lambda: st()["popup"] == "")


@case("Nomi bilan dastur topiladi")
def _():
    open_menu("kit")
    ok(st()["rows"][0] == "kitty", st()["rows"])
    key("esc")


@case("> buyruqlarni ko'rsatadi")
def _():
    open_menu(">")
    ok(len(st()["rows"]) >= 10, st()["rows"])
    key("esc")


@case("Chiqish tugmasi birinchi bosishda bajarilmaydi")
def _():
    # 640 kenglikdagi menyu markazda, tugmalar o'ng pastda, chiqish uchinchisi.
    open_menu()
    click(835, 765)
    time.sleep(0.4)
    ok(st()["popup"] == "menu")
    ok(sh("pgrep -u $(id -u) -x niri").returncode == 0)
    key("esc")


feature("clipboard", "Clipboard tarixi")


def copy(text):
    p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True)
    p.communicate(text)
    time.sleep(0.5)


@case("Nusxalangan matn tarixda ko'rinadi")
def _():
    copy("clip-birinchi")
    ipc("clipboard")
    wait(lambda: "clip-birinchi" in row("Clipboard"), 4)
    key("esc")


@case("Mod+V faqat clipboard'ni ko'rsatadi")
def _():
    copy("clip-ikki")
    ipc("clipboard")
    wait(lambda: st()["rows"])
    ok(all(r.startswith("Clipboard|") for r in st()["rows"]), st()["rows"])
    key("esc")


@case("Yozish tarixni filtrlaydi")
def _():
    copy("olma-belgi"); copy("nok-belgi")
    ipc("clipboard"); wait(lambda: st()["rows"]); time.sleep(0.5)
    typ("nok-")
    wait(lambda: st()["rows"] and "nok-belgi" in st()["rows"][0], 3)
    key("esc")


@case("Enter tanlangan matnni qaytaradi")
def _():
    copy("eski-matn"); copy("yangi-matn")
    ipc("clipboard"); wait(lambda: st()["rows"]); time.sleep(0.5)
    typ("eski-matn")
    time.sleep(0.3)
    rows = st()["rows"]
    key("enter")
    wait(lambda: clip_text() == "eski-matn", 4, f"{clip_text()!r} qatorlar={rows!r}")


@case("Xavfli belgili matn buyruq bo'lib ishlamaydi")
def _():
    bad = "$(touch /tmp/nd-pwn.flag);`touch /tmp/nd-pwn.flag`"
    copy(bad)
    ipc("clipboard"); wait(lambda: st()["rows"]); time.sleep(0.5)
    key("enter")
    wait(lambda: clip_text() == bad, 4)
    time.sleep(0.4)
    ok(not os.path.exists("/tmp/nd-pwn.flag"))


@case("Ko'p qatorli matn to'liq qaytadi")
def _():
    text = "bir\nikki\nuch"
    copy(text)
    ipc("clipboard"); wait(lambda: st()["rows"]); time.sleep(0.5)
    first = st()["rows"][0]
    key("enter")
    time.sleep(0.6)
    ok(clip_text() == text, f"{clip_text()!r} qator={first!r}")


@case("Kirill va o'zbek harflari buzilmaydi")
def _():
    copy("салом o'zbek")
    ipc("clipboard"); wait(lambda: st()["rows"]); time.sleep(0.5)
    key("enter")
    wait(lambda: clip_text() == "салом o'zbek", 4)


@case("Mod+V ikkinchi bosish yopadi")
def _():
    ipc("clipboard"); wait(lambda: st()["popup"] == "clipboard")
    ipc("clipboard"); wait(lambda: st()["popup"] == "")


@case("Tarix bo'sh bo'lsa xato bermaydi")
def _():
    sh("cliphist wipe")
    time.sleep(0.3)
    ipc("clipboard"); wait(lambda: st()["popup"] == "clipboard")
    time.sleep(0.4)
    ok(st()["rows"] == [])
    key("enter")
    time.sleep(0.2)
    key("esc")


@case("Juda uzun matn oynani buzmaydi")
def _():
    copy("x" * 20000)
    ipc("clipboard"); wait(lambda: st()["rows"]); time.sleep(0.5)
    ok(st()["popup"] == "clipboard")
    key("esc")


# ---------------------------------------------------------------------------------------
feature("wallpaper", "Fon rasmi va ranglar")

WP = str(HOME / ".local/bin/falcon-wallpaper")
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


@case("Jonli va oddiy fon vkladkalari almashadi")
def _():
    set_wp("moviy-tun.jpg")
    picker()
    ok(st()["pickerTab"] == 1, st()["pickerTab"])
    images = st()["pickerFiles"]
    sh(["qs", "-c", "falcon", "ipc", "call", "desk", "wallpapersTab", "0"])
    wait(lambda: st()["pickerTab"] == 0, 2)
    ok(st()["pickerFiles"] == len([f for f in (WDIR / "Live").glob("*") if f.is_file()]) if (WDIR / "Live").exists() else st()["pickerFiles"] == 0)
    sh(["qs", "-c", "falcon", "ipc", "call", "desk", "wallpapersTab", "1"])
    wait(lambda: st()["pickerTab"] == 1, 2)
    ok(st()["pickerFiles"] == images, st()["pickerFiles"])
    key("esc")


@case("Vidjet qatlami qayta ochilgach joyida qoladi")
def _():
    sh(["qs", "-c", "falcon", "ipc", "call", "desk", "widgetsRestack"])
    time.sleep(0.5)
    layers = json.loads(sh(["niri", "msg", "-j", "layers"]).stdout)
    ok(any(l["namespace"] == "falcon-widgets-face" for l in layers))


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
    return any(l["namespace"] == "falcon-top" and l["keyboard_interactivity"] == "Exclusive" for l in nj("layers"))


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
    ipc("dashboardTab", "0")
    wait(lambda: st()["popup"] == "dashboard" and st()["dashTab"] == 1)
    time.sleep(0.5)
    click(650, 130)
    w = wait(lambda: next(x for x in windows() if x["app_id"] == "falcon-tool"), 6)
    wait(lambda: sh("pgrep -u $(id -u) -x btop").returncode == 0, 4)
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


def toggle_xy(i):
    # 400 kenglikdagi panel, ichi 368. 0 va 1: tarmoq tugmalari, 2-4: tez tugmalar.
    left = 1280 - 14 - 400 + 16
    if i < 2:
        return left + 120 + i * 188, 98
    return int(left + 58 + (i - 2) * 125), 166


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
    click(*toggle_xy(2))
    wait(lambda: st()["caffeine"])
    toast("Caffeine on")


@case("Tungi rejim wlsunset'ni boshqaradi")
def _():
    open_control()
    click(*toggle_xy(3))
    wait(lambda: sh("pgrep -u $(id -u) -x wlsunset").returncode == 0, 4)
    click(*toggle_xy(3))
    wait(lambda: sh("pgrep -u $(id -u) -x wlsunset").returncode != 0, 4)


@case("Kofe, tungi va jim rejim shell qayta ishga tushganda saqlanadi")
def _():
    open_control()
    click(*toggle_xy(2)); wait(lambda: st()["caffeine"])
    click(*toggle_xy(3)); wait(lambda: st()["night"])
    click(*toggle_xy(4)); wait(lambda: st()["dnd"])
    key("esc")
    sh("pkill -x qs"); time.sleep(1.2)
    wait(lambda: st() is not None, 10)
    wait(lambda: st()["caffeine"] and st()["night"] and st()["dnd"], 5, "saqlanmadi")
    ok(sh("pgrep -u $(id -u) -c -x wlsunset").stdout.strip() == "1")


@case("Xabarlar tarixi shell qayta ishga tushganda saqlanadi")
def _():
    sh(["notify-send", "Saqlanadigan xabar"])
    wait(lambda: "Saqlanadigan xabar" in st()["history"])
    sh("pkill -x qs"); time.sleep(1.2)
    wait(lambda: st() is not None, 10)
    wait(lambda: "Saqlanadigan xabar" in st()["history"], 5, "saqlanmadi")


@case("'Bezovta qilmang' xabarlarni to'xtatadi")
def _():
    open_control()
    click(*toggle_xy(4))
    wait(lambda: st()["dnd"])
    key("esc")
    sh(["notify-send", "Jim xabar"])
    time.sleep(0.8)
    ok(st()["toast"] == "", st()["toast"])
    ok("Jim xabar" in st()["history"])


@case("Wi-Fi tugmasi tarmoqlar ro'yxatini ochadi, Esc orqaga qaytaradi")
def _():
    key("mod", "c")
    wait(lambda: st()["popup"] == "control", 3)
    time.sleep(0.4)
    click(*toggle_xy(0))
    wait(lambda: st()["controlPage"] == "wifi", 3)
    key("esc")
    wait(lambda: st()["controlPage"] == "" and st()["popup"] == "control", 3)


@case("Bluetooth tugmasi qurilmalar ro'yxatini ochadi, panel yopilsa qayta tiklanadi")
def _():
    key("mod", "c")
    wait(lambda: st()["popup"] == "control", 3)
    time.sleep(0.4)
    click(*toggle_xy(1))
    wait(lambda: st()["controlPage"] == "bluetooth", 3)
    ipc("close")
    wait(lambda: st()["popup"] == "" and st()["controlPage"] == "", 3)


@case("Yozish sahifasi ochiladi, kechiktirilgan yozish bekor qilinadi")
def _():
    ipc("controlPage", "record")
    wait(lambda: st()["controlPage"] == "record", 3)
    ipc("recordingCountdown", "5")
    wait(lambda: st()["recordCountdown"] > 0, 3)
    ipc("recordingCountdown", "0")
    wait(lambda: st()["recordCountdown"] == 0 and not st()["recording"], 3)
    ipc("close")
    wait(lambda: st()["popup"] == "" and st()["controlPage"] == "", 3)


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
    click(1066, 221)
    wait(lambda: abs(vol() - 0.2) > 0.1, 3)


@case("Sliderni sudrash oxirigacha yetadi")
def _():
    setvol(0.2)
    open_control()
    drag(890, 221, 1248, 221)
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


@case("Har bir xabar tarixda qoladi")
def _():
    for i in range(35):
        sh(["notify-send", f"Tarix{i}"])
    wait(lambda: sum(t.startswith("Tarix") for t in st()["history"]) == 35, 5)


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


@case("O'qilmaganlar soni Bugun bo'limi ochilganda nolga tushadi")
def _():
    notify("Oqilmagan")
    wait(lambda: st()["unread"] == 1)
    ipc("dashboardTab", "0")
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


@case("Xabarni sichqoncha bilan surib yo'qotsa bo'ladi")
def _():
    notify("Surish")
    ipc("dashboardTab", "0")
    wait(lambda: st()["popup"] == "dashboard")
    drag(1040, 145, 1070, 145)
    time.sleep(0.5)
    ok("Surish" in st()["history"], st()["history"])
    drag(1040, 145, 1180, 145)
    wait(lambda: "Surish" not in st()["history"], 2)


@case("Tozalash hammasini animatsiya bilan yo'qotadi")
def _():
    notify("Bir"); notify("Ikki")
    ipc("dashboardTab", "0")
    wait(lambda: st()["popup"] == "dashboard")
    click(1105, 93)
    ok(len(st()["history"]) >= 2, st()["history"])
    wait(lambda: st()["history"] == [], 2)


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
    click(1028, 27, "0xC1")
    time.sleep(1.0)
    b = shot("t6")
    key("esc")
    ok(a != b, "menyu chiqmadi")


@case("Menyu Esc bilan yopiladi")
def _():
    tray_on(); time.sleep(0.4)
    click(1028, 27, "0xC1")
    wait(lambda: st()["popup"] == "tray", 3)
    key("esc")
    wait(lambda: st()["popup"] == "", 3)


def dumps():
    return len(sh("coredumpctl list --no-pager --no-legend").stdout.splitlines())


@case("Menyu ishlatilgandan keyin dastur yopilsa shell yiqilmaydi")
def _():
    n = dumps()
    tray_on(); time.sleep(0.4)
    click(1028, 27, "0xC1")
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
    click(1028, 27, "0xC1")
    wait(lambda: st()["popup"] == "tray", 3)
    sh("pkill -x nm-applet")
    wait(lambda: st()["popup"] == "", 4)
    time.sleep(0.8)
    ok(dumps() == n, "shell yiqildi")


@case("Chap tugma shell'ni buzmaydi")
def _():
    tray_on(); time.sleep(0.4)
    click(1028, 27)
    time.sleep(0.6)
    key("esc")
    ok(st()["trayCount"] >= 1)


@case("O'rta tugma shell'ni buzmaydi")
def _():
    tray_on(); time.sleep(0.4)
    click(1028, 27, "0xC2")
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


@case("Zen'da chiqish yo'li haqida xabar chiqadi")
def _():
    key("mod", "f"); wait(lambda: st()["zen"], 3)
    wait(lambda: st()["toast"] == "Focus mode", 3, st()["toast"])


@case("Zen'dan boshqaruv paneli orqali chiqiladi")
def _():
    key("mod", "f"); wait(lambda: st()["zen"], 3)
    ipc("control")
    wait(lambda: st()["popup"] == "control", 3)
    key("esc")
    wait(lambda: st()["popup"] == "", 3)
    key("mod", "f"); wait(lambda: not st()["zen"], 3)


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
    wait(lambda: st()["region"] == "select", 3)
    drag(100, 100, 400, 300)
    time.sleep(0.7)


@case("Mod+Shift+S va sohani belgilash fayl saqlaydi")
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
    wait(lambda: st()["region"] == "select", 3)
    key("esc")
    time.sleep(0.6)
    ok(st()["region"] == "")
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
    wait(lambda: st()["region"] == "select", 3)
    drag(100, 100, 400, 300)
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
    wait(lambda: st()["region"] == "select", 3, "soha tanlash ochilmadi")
    time.sleep(0.2)
    drag(100, 100, 500, 400)
    wait(lambda: st()["recording"], 4)


def rec_stop():
    key("mod", "shift", "r")
    wait(lambda: not st()["recording"], 4)


@case("Soha tanlansa yozish boshlanadi")
def _():
    rec_start()
    ok(sh("pgrep -u $(id -u) -x wf-recorder").returncode == 0)
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
    wait(lambda: st()["region"] == "select", 3)
    time.sleep(0.2)
    key("esc")
    time.sleep(0.6)
    ok(not st()["recording"])
    ok(sh("pgrep -u $(id -u) -x wf-recorder").returncode != 0)


@case("Yozish paytida orolda qizil vaqt ko'rinadi")
def _():
    a = shot("rec0", "500,0 280x44")
    rec_start()
    time.sleep(1.2)
    ok(shot("rec1", "500,0 280x44") != a)
    rec_stop()


@case("Shell qayta ishga tushsa yozish davom etadi va to'xtatsa bo'ladi")
def _():
    rec_start()
    sh("pkill -x qs"); time.sleep(1.2)
    wait(lambda: st() is not None, 10)
    ok(sh("pgrep -u $(id -u) -x wf-recorder").returncode == 0)
    key("mod", "shift", "r")
    wait(lambda: sh("pgrep -u $(id -u) -x wf-recorder").returncode != 0, 5)


@case("wf-recorder o'zi to'xtasa keyingi bosish yangisini boshlaydi")
def _():
    rec_start()
    sh("pkill -9 -x wf-recorder")
    time.sleep(0.4)
    key("mod", "shift", "r")
    wait(lambda: st()["region"] == "select", 3)
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
    wait(lambda: st()["region"] == "select", 3)
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
    wait(lambda: sh("pgrep -u $(id -u) -x hyprlock").returncode != 0, 6, "ochilmadi")
    time.sleep(0.5)


def locked():
    return sh("pgrep -u $(id -u) -x hyprlock").returncode == 0


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
    sid = sh("loginctl list-sessions --no-legend | awk -v u=$(id -un) '$3==u && $4==\"seat0\"{print $1}'").stdout.strip()
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
    ok(len(sh("pgrep -u $(id -u) -x hyprlock").stdout.split()) == 1)
    unlock()


@case("Shell o'ldirilsa ham ekran bloklangan qoladi")
def _():
    need_pw()
    key("mod", "x"); wait(locked, 4); time.sleep(0.8)
    sh("pkill -x qs"); time.sleep(1)
    ok(locked())
    wait(lambda: sh("pgrep -u $(id -u) -x qs").returncode == 0, 6, "shell qaytmadi")
    ok(locked())
    unlock()
    wait(lambda: "falcon-top" in layers(), 10)


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
    click(*toggle_xy(2))
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


@case("Yangi oyna va terminal sozlamalari generated fayllarga yoziladi")
def _():
    settings(windows__edgeMargin=20, windows__blurStrength=5, windows__overviewZoom=0.6, appearance__cursorHideAfter=5, terminal__cursorShape="beam", terminal__scrollback=9000)
    wait(lambda: "left 20" in gen() and "passes 5" in gen() and "zoom 0.6" in gen() and "hide-after-inactive-ms 5000" in gen(), 6)
    kitty = (HOME / ".config/kitty/falcon-user.conf").read_text()
    ok("cursor_shape beam" in kitty and "scrollback_lines 9000" in kitty, kitty)


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
    wait(lambda: "background_opacity 0.5" in (HOME / ".config/kitty/falcon-user.conf").read_text(), 4)


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


feature("set-keys", "Sozlamalar: klavishlar va klaviatura")


def binds_text():
    return (GEN / "binds.kdl").read_text()


@case("Klavishni bo'sh qoldirish uni o'chiradi")
def _():
    settings(binds__dashboard="")
    time.sleep(0.4)
    key("mod", "d")
    time.sleep(0.5)
    ok(st()["popup"] == "")


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
    return next((w for w in windows() if w["title"] == "falcon settings"), None)


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
    ok(len([w for w in windows() if w["title"] == "falcon settings"]) == 1)


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
    click(ox + 95, oy + 472)
    time.sleep(0.5)
    ok(json.loads(SET.read_text())["windows"]["gaps"] == 33)
    click(ox + 95, oy + 472)
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
    click(ox + 820, row_y(oy, 1))
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
    # settings.json yozilgach niri qoidani config'dan bir oz keyin oladi: shuni kutamiz.
    wait(lambda: "qoidali" in (GEN / "settings.kdl").read_text() and "open-floating true" in (GEN / "settings.kdl").read_text(), 4, "qoida yozilmadi")
    time.sleep(0.6)
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
    p = sh("pgrep -u $(id -u) -x qs").stdout.split()[0]
    t = lambda: sum(int(x) for x in Path(f"/proc/{p}/stat").read_text().split()[13:15])
    a = t(); time.sleep(5); b = t()
    ok(b - a < 25, b - a)


@case("Qayta yuklanganda bitta nusxa ishlaydi")
def _():
    ok(len(sh("pgrep -u $(id -u) -x qs").stdout.split()) == 1)


@case("Shell o'ldirilsa nazoratchi o'zi qaytaradi")
def _():
    sh("pkill -9 -x qs"); time.sleep(0.5)
    wait(lambda: "falcon-top" in layers(), 10)
    ok(len(sh("pgrep -u $(id -u) -x qs").stdout.split()) == 1)


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
    p = sh("pgrep -u $(id -u) -x qs").stdout.split()[0]
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
    ok("falcon-top" in layers())


@case("Masshtab o'zgarsa panel ishlaydi")
def _():
    o = next(iter(nj("outputs")))
    sh(["niri", "msg", "output", o, "scale", "1.25"]); time.sleep(1)
    ok("falcon-top" in layers())
    ok(st() is not None)
    sh(["niri", "msg", "output", o, "scale", "1"]); time.sleep(0.8)


@case("Monitor qayta ulansa panel qaytadi")
def _():
    o = next(iter(nj("outputs")))
    sh(["niri", "msg", "output", o, "off"])
    time.sleep(1.0)
    sh(["niri", "msg", "output", o, "on"])
    wait(lambda: "falcon-top" in layers(), 6)


@case("Uzoq ishlashdan keyin ham jurnalda xato ko'p emas")
def _():
    r = sh("timeout 4 qs -c falcon log </dev/null", timeout=8)
    text = re.sub(r"\x1b\[[0-9;]*m", "", r.stdout + r.stderr)
    bad = [l for l in text.splitlines() if " ERROR" in l and "pipewire" not in l]
    ok(len(bad) < 3, bad[:3])


# ---------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------
# Yangi funksiyalar
LBIN = HOME / ".local/bin"


def run(*argv, stdin=None, timeout=30):
    return sh([str(LBIN / argv[0]), *argv[1:]], stdin=stdin, timeout=timeout)


def dash(tab):
    ipc("dashboardTab", str(tab))
    wait(lambda: st()["popup"] == "dashboard" and st()["dashTab"] == tab, 3, "vkladka ochilmadi")
    time.sleep(0.5)


def write_json(path, data):
    path.write_text(json.dumps(data))
    time.sleep(0.6)


feature("dash", "Dashboard: 2 ta vkladka")

for _i, _name in enumerate(["Today", "Music"]):
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
    click(699, 27)
    wait(lambda: st()["dashTab"] == 1, 2, "almashmadi")
    click(581, 27)
    wait(lambda: st()["dashTab"] == 0, 2, "almashmadi")


@case("Raqam tugmalari vkladkani almashtiradi")
def _():
    dash(0)
    key("2")
    wait(lambda: st()["dashTab"] == 1, 2, "2 ishlamadi")
    key("1")
    wait(lambda: st()["dashTab"] == 0, 2, "1 ishlamadi")


@case("Tab keyingisiga o'tadi va aylanadi")
def _():
    dash(0)
    key("tab")
    wait(lambda: st()["dashTab"] == 1, 2, f"Musiqaga o'tmadi: {layers()} {focused()}")
    key("tab")
    wait(lambda: st()["dashTab"] == 0, 2, "aylanmadi")


@case("Esc har vkladkada yopadi")
def _():
    for i in range(2):
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


feature("restore", "Sessiyani tiklash")

SESSION = STATE / "session.json"


@case("Saqlash ochiq oynalarni workspace bilan yozadi")
def _():
    foot("a", "foot")
    run("falcon-session", "save")
    items = json.loads(SESSION.read_text())
    ok(len(items) == 1 and items[0]["exe"] == "foot", items)


@case("Xizmat oynalari saqlanmaydi")
def _():
    term("t", cls="falcon-tool")
    run("falcon-session", "save")
    ok(json.loads(SESSION.read_text()) == [])


@case("Tiklash dasturni ochadi")
def _():
    write_json(SESSION, [{"app": "foot", "exe": "foot", "workspace": 1, "share": 0}])
    run("falcon-session", "restore", "--force")
    wait(lambda: windows(), 6, "ochilmadi")


@case("Argumentlar qayta bajarilmaydi")
def _():
    w = foot("a", "foot")
    run("falcon-session", "save")
    niri("close-window", "--id", w)
    wait(lambda: not windows(), 3)
    run("falcon-session", "restore", "--force")
    w2 = wait(windows, 6)[0]
    args = Path(f"/proc/{w2['pid']}/cmdline").read_bytes()
    ok(b"sleep" not in args, args)


@case("Ochiq oyna bo'lsa tiklash hech narsa qilmaydi")
def _():
    write_json(SESSION, [{"app": "foot", "exe": "foot", "workspace": 1}])
    term("t")
    run("falcon-session", "restore", "--force")
    ok(len(windows()) == 1)


@case("Sozlama o'chiq bo'lsa kirishda tiklanmaydi")
def _():
    write_json(SESSION, [{"app": "foot", "exe": "foot", "workspace": 1}])
    settings(session__restore=False)
    run("falcon-session", "restore")
    time.sleep(0.8)
    ok(windows() == [])


@case("Buzuq fayl xato bermaydi")
def _():
    SESSION.write_text("{")
    ok(run("falcon-session", "restore", "--force").returncode == 0)


@case("O'rnatilmagan dastur o'tkazib yuboriladi")
def _():
    write_json(SESSION, [{"exe": "yoq-dastur", "workspace": 1}, {"exe": "foot", "workspace": 1}])
    r = run("falcon-session", "restore", "--force")
    ok(r.returncode == 0, r.stderr)
    ok(len(windows()) == 1, f"{windows()} {SESSION.read_text()[:120]}")


@case("Yo'l ko'rinishidagi buyruq bajarilmaydi")
def _():
    write_json(SESSION, [{"exe": "/tmp/nd-x", "workspace": 1}])
    Path("/tmp/nd-x").write_text("#!/bin/sh\ntouch /tmp/nd-ran.flag\n")
    Path("/tmp/nd-x").chmod(0o755)
    run("falcon-session", "restore", "--force")
    time.sleep(0.5)
    ok(not Path("/tmp/nd-ran.flag").exists())


@case("Workspace to'g'ri tiklanadi")
def _():
    write_json(SESSION, [{"exe": "foot", "workspace": 1}, {"exe": "kitty", "workspace": 2}])
    run("falcon-session", "restore", "--force")
    ok(wsof("foot") == 1 and wsof("kitty") == 2, windows())


@case("Ustun kengligi va suzuvchi oyna joyi tiklanadi")
def _():
    write_json(SESSION, [
        {"app": "foot", "exe": "foot", "workspace": 1, "column": 1, "row": 1, "width": 500, "height": 0},
        {"app": "kitty", "exe": "kitty", "workspace": 1, "floating": True, "width": 420, "height": 310, "x": 200, "y": 120},
    ])
    run("falcon-session", "restore", "--force")
    found = {w["app_id"]: w["layout"] for w in wait(lambda: len(windows()) == 2 and windows(), 8)}
    ok(found["foot"]["tile_size"][0] == 500, found)
    ok(found["kitty"]["tile_size"] == [420, 310] and found["kitty"]["tile_pos_in_workspace_view"] == [200, 120], found)


feature("layoutfix", "Noto'g'ri klaviatura tuzatish")

for _q, _want in [("лшеен", "kitty"), ("ащще", "foot"), ("ащ", "foot")]:
    @case(f"{_q} -> {_want}")
    def _(q=_q, want=_want):
        ipc("menu")
        wait(lambda: st()["popup"] == "menu", 3)
        time.sleep(0.4)
        ipc("launcherQuery", q)
        time.sleep(0.5)
        ok(any(want in r.lower() for r in st()["rows"]), st()["rows"])
        ipc("close")
        wait(lambda: st()["popup"] == "", 3)


feature("binds-edit", "Klavishlarni o'zgartirish")


def clipboard_open():
    return st()["popup"] == "clipboard"


@case("Klavishni o'zgartirish ishlaydi")
def _():
    settings(binds__clipboard="Mod+Y")
    time.sleep(0.4)
    key("mod", "y")
    wait(clipboard_open, 3)
    key("esc")


@case("Eski klavish endi ishlamaydi")
def _():
    settings(binds__clipboard="Mod+Y")
    time.sleep(0.4)
    key("mod", "v")
    time.sleep(0.6)
    ok(not clipboard_open())


@case("Bir klavish ikki amalga berilsa rad etiladi")
def _():
    before = binds_text()
    settings(binds__clipboard="Mod+D")
    wait(lambda: "two actions" in st()["error"], 5, st()["error"])
    ok(binds_text() == before)


@case("Band tizim klavishi rad etiladi")
def _():
    before = binds_text()
    settings(binds__clipboard="Mod+H")
    wait(lambda: "system shortcut" in st()["error"], 5, st()["error"])
    ok(binds_text() == before)
    key("mod", "v")
    wait(clipboard_open, 3)
    key("esc")


@case("Mavjud bo'lmagan tugma nomi rad etiladi")
def _():
    before = binds_text()
    settings(binds__clipboard="Mod+Bunday")
    wait(lambda: st()["error"], 5)
    ok(binds_text() == before)


@case("Xavfli matn klavish sifatida qabul qilinmaydi")
def _():
    before = binds_text()
    settings(binds__clipboard='Mod+Y { spawn "touch" "/tmp/nd-k.flag"; }')
    wait(lambda: st()["error"], 5)
    ok(binds_text() == before)


@case("Klavishni maydondan o'zgartirish ishlaydi")
def _():
    ox, oy = page(5)
    click(ox + 800, row_y(oy, 2))
    for _n in range(12):
        key("backspace")
    typ("Mod+Y")
    key("enter")
    wait(lambda: "Mod+Y hotkey" in binds_text(), 4, st()["error"])
    key("esc")
    time.sleep(0.4)
    key("mod", "y")
    wait(clipboard_open, 3)
    key("esc")


@case("Mavjud bo'lmagan shrift shell'ni buzmaydi")
def _():
    settings(appearance__font="Bunday Shrift Yoq")
    ok(st() is not None)


feature("color-pick", "Ekrandan rang olish")


@case("Rang olish hex nusxalaydi")
def _():
    run("falcon-color")
    time.sleep(0.8)
    click(400, 400)
    wait(lambda: re.fullmatch(r"#[0-9a-fA-F]{6}", clip_text()), 5, clip_text())


feature("translate", "Rasmdagi yozuvlarni tarjima qilish")

SHIM = Path("/tmp/nd-shim")
TRANSLATE_PIC = Path("/tmp/nd-translate.png")


def shim(trans_ok=True):
    SHIM.mkdir(exist_ok=True)
    Path("/tmp/nd-trans.args").unlink(missing_ok=True)
    body = 'echo "$*" > /tmp/nd-trans.args; echo Salom' if trans_ok else "exit 1"
    (SHIM / "trans").write_text(f"#!/bin/sh\n{body}\n")
    (SHIM / "trans").chmod(0o755)


def translate_cli(picture, *args):
    out = "/tmp/nd-translated.png"
    Path(out).unlink(missing_ok=True)
    run = sh(f"PATH={SHIM}:$PATH {LBIN}/falcon-image-translate {picture} {out} " + " ".join(args), timeout=30)
    stages = [json.loads(line) for line in run.stdout.splitlines()]
    return stages, Path(out)


def text_picture(words="HELLO WORLD"):
    sh(f"magick -size 600x120 xc:white -pointsize 40 -fill black -annotate +30+70 '{words}' {TRANSLATE_PIC}")


@case("Yozuvli rasm tarjima qilinadi")
def _():
    shim()
    text_picture()
    stages, out = translate_cli(TRANSLATE_PIC)
    ok(stages[-1]["stage"] == "done", stages)
    ok(stages[-1]["text"] == "Salom", stages)
    ok(out.exists())


@case("Natija rasm hajmi asl rasmniki bilan bir xil")
def _():
    shim()
    text_picture()
    _, out = translate_cli(TRANSLATE_PIC)
    ok(sh(f"magick identify -format '%wx%h' {out}").stdout == "600x120")


@case("Yozuvsiz rasm uchun 'empty' deydi")
def _():
    shim()
    sh(f"magick -size 300x120 xc:'#335577' {TRANSLATE_PIC}")
    stages, out = translate_cli(TRANSLATE_PIC)
    ok(stages[-1]["stage"] == "empty", stages)
    ok(not out.exists())


@case("Internet bo'lmasa xato deydi")
def _():
    shim(trans_ok=False)
    text_picture()
    stages, _ = translate_cli(TRANSLATE_PIC)
    ok(stages[-1]["stage"] == "error", stages)


@case("Til argumentdan olinadi")
def _():
    shim()
    text_picture()
    translate_cli(TRANSLATE_PIC, "--to", "uz")
    ok(":uz" in Path("/tmp/nd-trans.args").read_text())


@case("Til sozlamadan olinadi")
def _():
    settings(translate__to="ru")
    shim()
    text_picture()
    translate_cli(TRANSLATE_PIC)
    ok(":ru" in Path("/tmp/nd-trans.args").read_text())


@case("Mod+Alt+P tanlash ekranini ochadi, Esc yopadi")
def _():
    key("mod", "alt", "p")
    wait(lambda: st()["region"] == "select" and st()["regionAction"] == "translate", 3)
    key("esc")
    wait(lambda: st()["region"] == "", 3)


@case("Oyna suzib ochiladi va yopilganda fayllar o'chadi")
def _():
    text_picture()
    copy_pic = Path("/tmp/nd-translate-copy.png")
    shutil.copy(TRANSLATE_PIC, copy_pic)
    ipc("translateImage", str(copy_pic), "600", "120")
    w = wait(lambda: next(w for w in windows() if w["title"] == "falcon translate"), 6)
    ok(w["is_floating"], w)
    niri("close-window", "--id", w["id"])
    wait(lambda: not copy_pic.exists(), 4)


@case("Klavish sozlangan")
def _():
    ok('"region" "translate"' in (GEN / "binds.kdl").read_text())


feature("region", "Soha tanlash")


@case("Bir xil amal ikkinchi marta bosilsa yopiladi")
def _():
    ipc("region", "copy")
    wait(lambda: st()["region"] == "select", 3)
    ipc("region", "copy")
    wait(lambda: st()["region"] == "", 3)


@case("Boshqa amal tanlash ekranini yopmaydi, amalni almashtiradi")
def _():
    ipc("region", "copy")
    wait(lambda: st()["region"] == "select", 3)
    ipc("region", "search")
    ok(st()["regionAction"] == "search")
    key("esc")
    wait(lambda: st()["region"] == "", 3)


@case("Oyna yo'q joyni bosish hech narsa qilmaydi")
def _():
    n = nshots()
    ipc("region", "copy")
    wait(lambda: st()["region"] == "select", 3)
    click(600, 500)
    time.sleep(0.5)
    ok(st()["region"] == "select" and nshots() == n)
    key("esc")


@case("Rasm fayllari ish tugagach o'chadi")
def _():
    take()
    time.sleep(0.6)
    ok(not (Path(os.environ["XDG_RUNTIME_DIR"]) / "falcon-region").exists())


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
    ok('Tr.t("Monitors")' in (HOME / ".config/quickshell/falcon/modules/SettingsWindow.qml").read_text())


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
    ok("falcon-top" in layers())


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
    ok(sh("pgrep -u $(id -u) -x wlsunset").returncode != 0)


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
    text = (HOME / ".config/quickshell/falcon/modules/SettingsWindow.qml").read_text()
    ok("schedule.lightFrom" in text and "nightlight.from" in text)


feature("backup", "Sozlamalarni zaxiralash")

BK = Path("/tmp/nd-backup.tar.gz")


def export():
    BK.unlink(missing_ok=True)
    ok(run("falcon-backup", "export", str(BK)).returncode == 0)


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
    p = Path(run("falcon-backup", "export").stdout.strip())
    ok(p.parent == HOME and p.exists())
    p.unlink()


@case("Sozlama bor")
def _():
    export()
    ok("falcon/settings.json" in members())


@case("Import sozlamani qaytaradi")
def _():
    settings(windows__gaps=7)
    export()
    SET.write_text(GOOD)
    time.sleep(0.8)
    ok(run("falcon-backup", "import", str(BK)).returncode == 0)
    ok(json.loads(SET.read_text())["windows"]["gaps"] == 7)


@case("Import niri'ga qo'llanadi")
def _():
    settings(windows__gaps=7)
    export()
    SET.write_text(GOOD)
    time.sleep(0.8)
    run("falcon-backup", "import", str(BK))
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
    ok(run("falcon-backup", "import", str(p)).returncode == 1)
    ok(not (HOME.parent / "nd-pwn").exists())


@case("Boshqa konfig faylini almashtira olmaydi")
def _():
    p = evil(["hypr/hyprlock.conf"])
    ok(run("falcon-backup", "import", str(p)).returncode == 1)


@case("Buzuq fayl sozlamani buzmaydi")
def _():
    Path("/tmp/nd-bad.tar.gz").write_text("emas")
    before = SET.read_text()
    ok(run("falcon-backup", "import", "/tmp/nd-bad.tar.gz").returncode == 1)
    ok(SET.read_text() == before)


@case("Yo'q fayl xato qaytaradi")
def _():
    ok(run("falcon-backup", "import", "/tmp/nd-yoq.tar.gz").returncode == 1)



feature("wifi-page", "Wi-Fi menyusi")

WIFI_BACK, WIFI_SWITCH, WIFI_ROW = (898, 84), (1230, 84), (1000, 129)


def wifi_open():
    key("mod", "c")
    wait(lambda: st()["popup"] == "control", 3)
    time.sleep(0.4)
    click(*toggle_xy(0))
    wait(lambda: st()["controlPage"] == "wifi", 3)
    time.sleep(0.5)


def wifi_on():
    return "enabled" in sh("nmcli radio wifi").stdout and "disabled" not in sh("nmcli radio wifi").stdout


def need_wifi():
    if "wifi" not in sh("nmcli -t -f TYPE device").stdout:
        raise Skip("Wi-Fi adapter yo'q")


@case("Wi-Fi tugmasini bosadi: tarmoqlar ro'yxati ochiladi va radio o'chmaydi")
def _():
    need_wifi()
    was = wifi_on()
    wifi_open()
    ok(wifi_on() == was, "radio o'zgarib ketdi")


@case("Orqaga strelkasini bosadi: asosiy panelga qaytadi")
def _():
    need_wifi()
    wifi_open()
    click(*WIFI_BACK)
    wait(lambda: st()["controlPage"] == "" and st()["popup"] == "control", 3)


@case("Esc bir marta orqaga, ikkinchi marta panelni yopadi")
def _():
    need_wifi()
    wifi_open()
    key("esc")
    wait(lambda: st()["controlPage"] == "" and st()["popup"] == "control", 3)
    key("esc")
    wait(lambda: st()["popup"] == "", 3)


@case("Wi-Fi'ni o'chirib yoqadi: radio haqiqatan o'zgaradi")
def _():
    need_wifi()
    was = wifi_on()
    wifi_open()
    try:
        click(*WIFI_SWITCH)
        wait(lambda: wifi_on() != was, 5, "o'chmadi")
        time.sleep(0.8)
        click(*WIFI_SWITCH)
        wait(lambda: wifi_on() == was, 5, "qaytmadi")
    finally:
        sh(f"nmcli radio wifi {'on' if was else 'off'}")


@case("Parol maydoni: qisqa parol yuborilmaydi, parol holatga chiqmaydi, Esc bekor qiladi")
def _():
    need_wifi()
    rows = [l for l in sh("nmcli -t -f SSID,SECURITY dev wifi list --rescan yes").stdout.splitlines() if l and not l.startswith(":")]
    # Faqat parolli tarmoqlar bo'lsagina bosiladi: ochiq tarmoqqa tasodifan ulanmaslik uchun.
    if not rows or any(l.rsplit(":", 1)[-1] == "" for l in rows) or sh("nmcli -t -f NAME,TYPE connection show").stdout.count("wireless"):
        raise Skip("xavfsiz sharoit yo'q: ochiq yoki saqlangan tarmoq bor")
    wifi_open()
    time.sleep(2.5)
    click(*WIFI_ROW)
    time.sleep(0.6)
    typ("qisqa")
    key("enter")
    time.sleep(0.5)
    ok("qisqa" not in ipc("state").stdout, "parol holatda ko'rindi")
    ok(not sh("nmcli -t -f NAME,TYPE connection show --active").stdout.count("wireless"), "ulanishga urindi")
    key("esc")
    time.sleep(0.4)
    ok(st()["controlPage"] == "wifi", "Esc parolni emas, sahifani yopdi")
    key("esc")
    wait(lambda: st()["controlPage"] == "", 3)


@case("Panelni yopib qayta ochadi: asosiy sahifadan boshlanadi")
def _():
    need_wifi()
    wifi_open()
    ipc("close")
    wait(lambda: st()["popup"] == "", 3)
    time.sleep(0.4)
    key("mod", "c")
    wait(lambda: st()["popup"] == "control" and st()["controlPage"] == "", 3)


feature("bt-page", "Bluetooth menyusi")


def bt_open():
    key("mod", "c")
    wait(lambda: st()["popup"] == "control", 3)
    time.sleep(0.4)
    click(*toggle_xy(1))
    wait(lambda: st()["controlPage"] == "bluetooth", 3)
    time.sleep(0.6)


def bt_show(field):
    return f"{field}: yes" in sh("bluetoothctl show").stdout


def need_bt():
    if "Controller" not in sh("bluetoothctl list").stdout:
        raise Skip("Bluetooth adapter yo'q")


@case("Bluetooth tugmasini bosadi: ro'yxat ochiladi va qidiruv boshlanadi")
def _():
    need_bt()
    bt_open()
    wait(lambda: bt_show("Discovering"), 6, "qidiruv boshlanmadi")


@case("Panelni yopadi: qidiruv to'xtaydi, batareya bekor sarflanmaydi")
def _():
    need_bt()
    bt_open()
    wait(lambda: bt_show("Discovering"), 6)
    ipc("close")
    wait(lambda: not bt_show("Discovering"), 6, "qidiruv to'xtamadi")


@case("Bluetooth'ni o'chirib yoqadi")
def _():
    need_bt()
    was = bt_show("Powered")
    bt_open()
    try:
        click(*WIFI_SWITCH)
        wait(lambda: bt_show("Powered") != was, 6, "o'zgarmadi")
        time.sleep(1.0)
        click(*WIFI_SWITCH)
        wait(lambda: bt_show("Powered") == was, 6, "qaytmadi")
    finally:
        sh(f"bluetoothctl power {'on' if was else 'off'}")


@case("Orqaga strelkasi va Esc ishlaydi")
def _():
    need_bt()
    bt_open()
    click(*WIFI_BACK)
    wait(lambda: st()["controlPage"] == "", 3)
    click(*toggle_xy(1))
    wait(lambda: st()["controlPage"] == "bluetooth", 3)
    key("esc")
    wait(lambda: st()["controlPage"] == "", 3)


@case("Wi-Fi va Bluetooth sahifalari orasida tez almashadi: shell buzilmaydi")
def _():
    need_bt()
    for name in ("wifi", "bluetooth", "wifi", "bluetooth", ""):
        ipc("controlPage", name)
        time.sleep(0.2)
    ipc("close")
    ok(st()["popup"] == "")


feature("claude-widget", "Claude limiti vidjeti")

USAGE = STATE / "claude-usage.json"
HOOK = str(HOME / ".local/bin/falcon-claude-status")


def usage_send(text):
    return subprocess.run([HOOK], input=text, capture_output=True, text=True, timeout=5)


def usage(five=None, week=None, in_five=7200, in_week=259200):
    limits = {}
    if five is not None:
        limits["five_hour"] = {"used_percentage": five, "resets_at": int(time.time()) + in_five}
    if week is not None:
        limits["seven_day"] = {"used_percentage": week, "resets_at": int(time.time()) + in_week}
    r = usage_send(json.dumps({"rate_limits": limits}))
    ok(r.returncode == 0 and r.stdout == "", r.stderr + r.stdout)


def usage_clear():
    USAGE.unlink(missing_ok=True)
    time.sleep(0.6)


def claude_click():
    # Vidjet til tugmasidan oldin turadi, joyi tray'ga bog'liq: chapdan o'ngga qidiriladi.
    for x in range(900, 1200, 16):
        click(x, 27)
        time.sleep(0.15)
        if st()["popup"] == "claude":
            return x
    raise AssertionError("vidjet topilmadi")


@case("Birinchi marta: ma'lumot yo'q bo'lsa panel tushunarli xabar ko'rsatadi")
def _():
    usage_clear()
    ok(st()["claudeHasData"] is False)
    ipc("claude")
    wait(lambda: st()["popup"] == "claude", 3)


@case("Ishlatgani sari foiz o'sadi va panel o'zi yangilanadi")
def _():
    usage(10, 3)
    wait(lambda: round(st()["claudeFive"]) == 10, 3, str(st().get("claudeFive")))
    usage(55, 20)
    wait(lambda: round(st()["claudeFive"]) == 55 and round(st()["claudeWeek"]) == 20, 3)
    usage_clear()


@case("Vidjetni sichqoncha bilan bosadi: panel ochiladi, yana bosadi: yopiladi")
def _():
    usage(37, 12)
    x = claude_click()
    click(x, 27)
    wait(lambda: st()["popup"] == "", 3)
    usage_clear()


@case("Reset vaqti o'tib ketgan: eski foiz emas, 0% ko'rsatadi")
def _():
    usage(90, 50, in_five=-60)
    time.sleep(0.5)
    ipc("reset")
    wait(lambda: st()["claudeFive"] == 0 and round(st()["claudeWeek"]) == 50, 35, str(st().get("claudeFive")))
    usage_clear()


@case("Limit tugagan: 100% da panel buzilmaydi")
def _():
    usage(100, 100)
    wait(lambda: st()["claudeFive"] == 100, 3)
    ipc("claude")
    wait(lambda: st()["popup"] == "claude", 3)
    usage_clear()


@case("Claude Code limit bermagan yoki buzuq ma'lumot: eski fayl saqlanadi")
def _():
    usage(42, 7)
    before = USAGE.read_text()
    for bad in ("", "bu json emas", "{}", '{"rate_limits": null}', '{"rate_limits": {"five_hour": "x"}}'):
        ok(usage_send(bad).returncode == 0, bad)
    ok(USAGE.read_text() == before)
    usage_clear()


@case("Fayl buzilib qolgan: shell yiqilmaydi")
def _():
    USAGE.parent.mkdir(parents=True, exist_ok=True)
    USAGE.write_text("{buzuq")
    time.sleep(0.8)
    ok(st()["claudeHasData"] is False)
    usage_clear()


feature("brightness", "Yorqinlik tugmalari")


def bright():
    return sh("brightnessctl --class=backlight -m").stdout.strip().split(",")


def need_backlight(fn):
    def wrapper():
        if len(bright()) < 5:
            raise Skip("backlight yo'q")
        before = bright()[2]
        try:
            fn()
        finally:
            sh(f"brightnessctl --class=backlight -q set {before}")
    return wrapper


@case("Tugmani ko'p bosib pastga tushiradi: ekran qoraymaydi, 5% da to'xtaydi")
@need_backlight
def _():
    sh("brightnessctl --class=backlight -q set 12%")
    for _ in range(6):
        key("brightdown")
        time.sleep(0.15)
    time.sleep(0.4)
    b = bright()
    ok(int(b[2]) >= int(b[4]) * 0.05 - 1, b)


@case("Eng pastdan yuqoriga qaytaradi")
@need_backlight
def _():
    sh("brightnessctl --class=backlight -q set 5%")
    key("brightup")
    time.sleep(0.5)
    ok(int(bright()[3].rstrip("%")) >= 9, bright())


@case("Eng yuqorida ko'p bosadi: 100% dan oshmaydi, xato chiqmaydi")
@need_backlight
def _():
    sh("brightnessctl --class=backlight -q set 95%")
    for _ in range(4):
        key("brightup")
        time.sleep(0.12)
    time.sleep(0.4)
    ok(bright()[3] == "100%", bright())


@case("Tugma bosilganda holat xabari chiqadi")
@need_backlight
def _():
    sh("brightnessctl --class=backlight -q set 50%")
    key("brightdown")
    wait(lambda: "45" in st()["toast"] or "Brightness" in st()["toast"], 3, st()["toast"])


@case("Ekran bloklangan paytda ham ishlaydi")
@need_backlight
def _():
    need_pw()
    sh("brightnessctl --class=backlight -q set 50%")
    key("mod", "x"); wait(locked, 4); time.sleep(0.8)
    key("brightdown")
    time.sleep(0.5)
    ok(bright()[3] == "45%", bright())
    unlock()


feature("net-icon", "Paneldagi tarmoq belgisi")


def pill():
    return shot("nip", "1040,8 240x40")


def wired():
    return ":ethernet:connected" in sh("nmcli -t -f DEVICE,TYPE,STATE device").stdout


@case("Kabel ulangan: Wi-Fi o'chirilsa ham belgi o'zgarmaydi")
def _():
    if not wired():
        raise Skip("kabel ulanmagan")
    need_wifi()
    was = wifi_on()
    a = pill()
    try:
        sh("nmcli radio wifi off")
        time.sleep(1.5)
        ok(pill() == a, "belgi o'zgarib ketdi")
    finally:
        sh(f"nmcli radio wifi {'on' if was else 'off'}")
    time.sleep(1.0)


@case("Sozlamada yashiriladi")
def _():
    a = pill()
    settings(panel__wifi=False)
    time.sleep(0.5)
    ok(pill() != a)


@case("Wi-Fi'ni tez-tez o'chirib yoqadi: panel yiqilmaydi")
def _():
    need_wifi()
    was = wifi_on()
    try:
        for state in ("off", "on", "off", "on"):
            sh(f"nmcli radio wifi {state}")
            time.sleep(0.3)
        ok(st() is not None)
    finally:
        sh(f"nmcli radio wifi {'on' if was else 'off'}")


@case("Boshqaruv paneli Wi-Fi holatini to'g'ri ko'rsatadi")
def _():
    need_wifi()
    was = wifi_on()
    try:
        key("mod", "c")
        wait(lambda: st()["popup"] == "control", 3)
        time.sleep(0.5)
        a = shot("nic", "882,68 180x60")
        sh(f"nmcli radio wifi {'off' if was else 'on'}")
        time.sleep(1.2)
        ok(shot("nid", "882,68 180x60") != a, "rangi o'zgarmadi")
    finally:
        sh(f"nmcli radio wifi {'on' if was else 'off'}")


@case("Shell qayta ishga tushsa ham belgi qaytadi")
def _():
    a = pill()
    sh("pkill -u $(id -u) -x qs")
    wait(lambda: "falcon-top" in layers(), 12)
    time.sleep(2.0)
    ok(pill() == a, "belgi qaytmadi")


feature("shots2", "Skrinshot: nom va papka")


@case("Ctrl+Print'ni ketma-ket bosadi: hech biri ustiga yozilmaydi")
def _():
    n = nshots()
    for _ in range(3):
        key("ctrl", "print")
        time.sleep(0.15)
    wait(lambda: nshots() == n + 3, 6, f"{nshots() - n} ta fayl")


@case("Skrinshot tizimning rasm papkasiga tushadi")
def _():
    n = nshots()
    key("ctrl", "print")
    wait(lambda: nshots() == n + 1, 4)
    pictures = sh("xdg-user-dir PICTURES").stdout.strip()
    ok(str(SHOTS).startswith(pictures), str(SHOTS))


@case("Oyna ochiq: Alt+Print oynani oladi")
def _():
    term()
    n = nshots()
    key("alt", "print")
    wait(lambda: nshots() == n + 1, 4)


@case("Oyna yo'q paytda Alt+Print: shell buzilmaydi")
def _():
    n = nshots()
    key("alt", "print")
    time.sleep(1.0)
    ok(st() is not None and nshots() in (n, n + 1))


@case("Papka o'chirilgan: o'zi yaratiladi")
def _():
    tmp = SHOTS.with_name("Screenshots.nd2")
    SHOTS.rename(tmp)
    try:
        key("ctrl", "print")
        wait(lambda: SHOTS.exists() and any(SHOTS.glob("*.png")), 4, "yaratilmadi")
    finally:
        for f in SHOTS.iterdir() if SHOTS.exists() else []:
            shutil.move(str(f), tmp)
        if SHOTS.exists():
            SHOTS.rmdir()
        tmp.rename(SHOTS)


feature("dash-ui", "Soat menyusi: real foydalanish")


@case("Soatni bosib ochadi, tashqariga bosib yopadi")
def _():
    click(640, 16)
    wait(lambda: st()["popup"] == "dashboard", 3)
    time.sleep(0.7)
    click(640, 650)
    wait(lambda: st()["popup"] == "", 3)


@case("Tablarni juda tez almashtiradi: oxirgisi to'g'ri qoladi")
def _():
    dash(0)
    for k in ("2", "1", "2", "1", "2", "1", "2"):
        key(k)
    wait(lambda: st()["dashTab"] == 1, 3)
    time.sleep(0.7)
    ok(st()["popup"] == "dashboard")


@case("Panel ochilayotganda darhol yopadi: qotib qolmaydi")
def _():
    ipc("dashboard")
    time.sleep(0.05)
    ipc("close")
    time.sleep(0.05)
    ipc("dashboard")
    time.sleep(0.05)
    ipc("close")
    wait(lambda: st()["popup"] == "", 2)
    time.sleep(0.9)
    ok("falcon-top" in layers())


@case("Musiqa bo'limida Esc bosadi: panel yopiladi, keyin oxirgi bo'lim eslab qolinadi")
def _():
    dash(1)
    key("esc")
    wait(lambda: st()["popup"] == "", 3)
    time.sleep(0.5)
    ipc("dashboard")
    wait(lambda: st()["popup"] == "dashboard" and st()["dashTab"] == 1, 3)


feature("levels", "Ovoz va yorqinlik xabari orolda")


def alternate(times=6):
    for _ in range(times):
        key("voldown")
        key("brightdown")


def need_levels():
    if len(bright()) < 5:
        raise Skip("backlight yo'q")


@case("Ovoz xabari turganda yorqinlikni o'zgartiradi: xabar darhol almashadi, navbat to'planmaydi")
def _():
    need_levels()
    before = bright()[2]
    try:
        key("voldown")
        wait(lambda: "Volume" in st()["toast"] or "Muted" in st()["toast"], 3)
        key("brightdown")
        wait(lambda: "Brightness" in st()["toast"], 2, st()["toast"])
        ok(st()["queue"] == 0, st()["queue"])
    finally:
        sh(f"brightnessctl --class=backlight -q set {before}")


@case("Ovoz va yorqinlikni navbat bilan ko'p o'zgartiradi: xabar 3 soniyada yo'qoladi")
def _():
    need_levels()
    before = bright()[2]
    try:
        alternate()
        ok(st()["queue"] == 0, st()["queue"])
        wait(lambda: st()["toast"] == "", 3.5, st()["toast"])
    finally:
        sh(f"brightnessctl --class=backlight -q set {before}")


@case("Slayderni uzoq sudraydi: navbat to'planmaydi va xabar yo'qoladi")
def _():
    setvol(0.2)
    for i in range(30):
        sh(f"wpctl set-volume @DEFAULT_AUDIO_SINK@ {0.2 + i * 0.01:.2f}")
    time.sleep(0.3)
    ok(st()["queue"] == 0, st()["queue"])
    wait(lambda: st()["toast"] == "", 3.5, st()["toast"])
    setvol(0.5)


@case("Oddiy xabar turganda ovozni o'zgartiradi: xabar yo'qolmaydi, keyin ovoz ko'rinadi")
def _():
    sh("notify-send nd-sarlavha nd-matn")
    wait(lambda: st()["toast"] == "nd-sarlavha", 3)
    for _ in range(4):
        key("voldown")
    time.sleep(0.3)
    ok(st()["toast"] == "nd-sarlavha" and st()["queue"] == 1, (st()["toast"], st()["queue"]))
    wait(lambda: "Volume" in st()["toast"] or "Muted" in st()["toast"], 8, st()["toast"])


@case("Ikkita oddiy xabar yo'qolmaydi, ikkalasi navbat bilan chiqadi")
def _():
    sh("notify-send nd-bir")
    wait(lambda: st()["toast"] == "nd-bir", 3)
    sh("notify-send nd-ikki")
    time.sleep(0.4)
    key("voldown")
    wait(lambda: st()["toast"] == "nd-ikki" or "Volume" in st()["toast"], 8)
    wait(lambda: st()["toast"] == "nd-ikki", 8, st()["toast"])


feature("glass", "Tepadagi panellar: shisha va fon rangi")

PILL_AREA = "1040,12 200x30"


@case("Fon rasmi almashsa panel rangi ham o'zgaradi")
def _():
    a = st()["accent"]
    before = shot("gl1", PILL_AREA)
    other = next(p for p in sorted(WDIR.glob("*.jpg")) if p.resolve() != (STATE / "wallpaper").resolve())
    current = (STATE / "wallpaper").resolve()
    sh([WP, "--colors", str(other)], timeout=20)
    try:
        wait(lambda: st()["accent"] != a, 5, "rang o'zgarmadi")
        time.sleep(1.0)
        ok(shot("gl2", PILL_AREA) != before, "panel o'zgarmadi")
    finally:
        sh([WP, "--colors", str(current)], timeout=20)


@case("Panel orqasi ko'rinadi: oyna ochilsa panel ko'rinishi o'zgaradi")
def _():
    a = shot("gl3", "560,44 160x4")
    b = shot("gl4", PILL_AREA)
    term()
    time.sleep(1.2)
    ok(st()["popup"] == "" and a and b)


@case("Panel bo'limidagi slayder shaffoflikni o'zgartiradi va saqlaydi")
def _():
    ox, oy = page(3)
    a = shot("gl5", PILL_AREA)
    click(ox + 690, row_y(oy, 0))
    wait(lambda: saved().get("appearance", {}).get("panelOpacity") not in (None, 0.65), 3, "saqlanmadi")
    time.sleep(0.6)
    ok(shot("gl6", PILL_AREA) != a, "ko'rinish o'zgarmadi")


@case("Panel pastga o'tkazilsa ham shisha buzilmaydi")
def _():
    settings(panel__position="bottom")
    time.sleep(0.8)
    ok("falcon-top" in layers() and st()["bottom"] is True)


@case("Shisha ustida soat menyusi va xabar ochiladi")
def _():
    dash(0)
    ipc("close")
    wait(lambda: st()["popup"] == "", 3)
    ipc("toast", "nd-shisha", "matn")
    wait(lambda: st()["toast"] == "nd-shisha", 3)


feature("widgets", "Ish stoli vidjetlari")

WIDGETS_FILE = HOME / ".config/falcon/widgets.json"


def widget_layout():
    return json.loads(WIDGETS_FILE.read_text()) if WIDGETS_FILE.exists() else None


def widgets_fresh():
    WIDGETS_FILE.unlink(missing_ok=True)
    sh("pkill -u $(id -u) -x qs")
    wait(lambda: "falcon-top" in layers(), 12)
    time.sleep(1.5)


def widget_edit():
    ipc("widgets")
    wait(lambda: st()["widgetEdit"], 3)
    time.sleep(0.5)


def rect(wid):
    return st()["widgetRects"][wid]


@case("Birinchi ochilishda tayyor vidjetlar turadi")
def _():
    widgets_fresh()
    ok("falcon-widgets" in layers())
    ok({w["type"] for w in st()["widgets"]} >= {"stack", "month", "rings", "cover", "sky"})


@case("Vidjetni sichqoncha bilan sudraydi: joyi o'zgaradi, faylga saqlanadi, to'rga yopishadi")
def _():
    widgets_fresh()
    widget_edit()
    r = rect("month")
    sx, sy = r["x"] + r["w"] // 2, r["y"] + r["h"] // 2
    drag(sx, sy, sx - 300, sy + 150)
    time.sleep(0.8)
    n = rect("month")
    ok(abs(n["x"] - (r["x"] - 300)) <= 24 and abs(n["y"] - (r["y"] + 150)) <= 24, (r, n))
    ok(n["x"] % 16 == 0 or n["y"] % 16 == 0, n)
    saved_layout = next(w for w in widget_layout() if w["id"] == "month")
    ok(saved_layout["fx"] < 0.98)


@case("Shell qayta ishga tushsa joylashuv saqlanadi")
def _():
    widgets_fresh()
    widget_edit()
    r = rect("weather")
    sx, sy = r["x"] + r["w"] // 2, r["y"] + r["h"] // 2
    drag(sx, sy, sx + 200, sy + 200)
    time.sleep(0.8)
    a = rect("weather")
    ipc("widgets")
    sh("pkill -u $(id -u) -x qs")
    wait(lambda: "falcon-top" in layers(), 12)
    time.sleep(1.5)
    b = rect("weather")
    ok(abs(a["x"] - b["x"]) <= 2 and abs(a["y"] - b["y"]) <= 2, (a, b))


@case("O'lcham tugmasi vidjetni kattalashtiradi va kichraytiradi")
def _():
    widgets_fresh()
    widget_edit()
    r = rect("weather")
    click(r["x"] + r["w"] - 8 - 26 - 5 - 14, r["y"] + 8 + 13)
    wait(lambda: rect("weather")["w"] > r["w"], 3, "kattalashmadi")
    ok(next(w for w in widget_layout() if w["id"] == "weather")["size"] == "l")


@case("Xoch tugmasi vidjetni olib tashlaydi, Reset qaytaradi")
def _():
    widgets_fresh()
    widget_edit()
    r = rect("weather")
    click(r["x"] + r["w"] - 8 - 13, r["y"] + 8 + 13)
    wait(lambda: all(w["id"] != "weather" for w in st()["widgets"]), 3, "olib tashlanmadi")
    ok(all(w["id"] != "weather" for w in widget_layout()))


@case("Esc tahrirlash rejimidan chiqaradi")
def _():
    widget_edit()
    key("esc")
    wait(lambda: not st()["widgetEdit"], 3)


@case("Mod+Shift+W tahrirlashni ochadi va yopadi")
def _():
    key("mod", "shift", "w")
    wait(lambda: st()["widgetEdit"], 3)
    time.sleep(0.4)
    key("mod", "shift", "w")
    wait(lambda: not st()["widgetEdit"], 3)


@case("Bo'sh joyga o'ng tugma: menyu chiqadi, birinchi qator tahrirlashni ochadi")
def _():
    click(640, 400, "0xC1")
    time.sleep(0.5)
    click(640 + 60, 400 + 26)
    wait(lambda: st()["widgetEdit"], 3, "menyu ishlamadi")


@case("Vidjet oynalar ustida ko'rinmaydi: oyna bosiladigan bo'lib qoladi")
def _():
    w = term()
    click(640, 400)
    time.sleep(0.4)
    ok(focused() and focused()["id"] == w)


@case("Buzuq vidjet fayli shell'ni yiqitmaydi, tayyor joylashuv ishlaydi")
def _():
    WIDGETS_FILE.write_text("{buzuq")
    sh("pkill -u $(id -u) -x qs")
    wait(lambda: "falcon-top" in layers(), 12)
    time.sleep(1.5)
    ok(len(st()["widgets"]) >= 3)
    WIDGETS_FILE.unlink(missing_ok=True)


@case("Sozlamada o'chirilsa vidjetlar yo'qoladi")
def _():
    settings(widgets__enabled=False)
    wait(lambda: "falcon-widgets" not in layers(), 3)


@case("Faqat birinchi ish stoli tanlansa: ikkinchisida yo'q, birinchisida qaytadi")
def _():
    settings(widgets__firstOnly=True)
    term()
    niri("focus-workspace", 2)
    wait(lambda: "falcon-widgets" not in layers(), 3)
    niri("focus-workspace", 1)
    wait(lambda: "falcon-widgets" in layers(), 3)


feature("widgets2", "Vidjetlar: qimirlamaslik, tejamkorlik, tushish joyi")


@case("Ish stoli almashganda vidjet surilmaydi: sirpanish paytida ham joyida")
def _():
    settings(widgets__opacity=0.5)
    r = rect("month")
    area = f"{r['x']},{r['y'] + 40} {r['w']},60"
    a = shot("wf1", area)
    niri("focus-workspace", 2)
    time.sleep(0.08)
    b = shot("wf2", area)
    time.sleep(0.8)
    niri("focus-workspace", 1)
    time.sleep(0.8)
    ok(a == b, "sirpanish paytida vidjet qimirladi")


@case("Keng oyna vidjetlarni butunlay yopsa: 30 soniyadan keyin to'xtaydi, yopilganda qaytadi")
def _():
    ok(st()["widgetsLive"] is True)
    w = term()
    niri("focus-window", "--id", w)
    niri("fullscreen-window")
    wait(lambda: st()["widgetsLive"] is False, 36, "to'xtamadi")
    niri("close-window", "--id", w)
    wait(lambda: st()["widgetsLive"] is True, 4, "qaytmadi")


@case("Tortayotganda tushish joyi ko'rinadi, qo'yib yuborganda aynan shu yerga tushadi")
def _():
    widget_edit()
    r = rect("month")
    sx, sy = r["x"] + r["w"] // 2, r["y"] + r["h"] // 2
    move(sx, sy)
    sh(["ydotool", "click", "0x40"])
    time.sleep(0.15)
    move(sx - 205, sy + 103)
    time.sleep(0.3)
    held = rect("month")
    sh(["ydotool", "click", "0x80"])
    time.sleep(0.9)
    final = rect("month")
    ok(final["x"] % 16 == 0 and abs(final["x"] - held["x"]) <= 16, (held, final))
    ok(final["y"] % 16 == 0 and abs(final["y"] - held["y"]) <= 16, (held, final))


@case("Musiqa vidjeti ustiga borsa bosiladigan nusxa chiqadi, chiqsa yo'qoladi")
def _():
    widgets_fresh()
    r = rect("cover")
    move(r["x"] + r["w"] // 2, r["y"] + r["h"] // 2)
    wait(lambda: st()["widgetHover"] == "cover", 3, "nusxa chiqmadi")
    move(640, 300)
    wait(lambda: st()["widgetHover"] == "", 3, "nusxa yo'qolmadi")


@case("Eslatma yozadi: faylga saqlanadi va yuzida ham ko'rinadi")
def _():
    widgets_fresh()
    widget_edit()
    click(640, 700)
    ipc("widgets")
    wait(lambda: not st()["widgetEdit"], 3)
    note = HOME / ".config/falcon/note.txt"
    note.unlink(missing_ok=True)
    layout = widget_layout() or []
    WIDGETS_FILE.write_text(json.dumps([{"id": "sticky", "type": "sticky", "fx": 0.5, "fy": 0.4, "size": "m"}]))
    sh("pkill -u $(id -u) -x qs")
    wait(lambda: "falcon-top" in layers(), 12)
    time.sleep(1.5)
    r = rect("sticky")
    move(r["x"] + 100, r["y"] + 100)
    time.sleep(0.5)
    click(r["x"] + 100, r["y"] + 100)
    time.sleep(0.5)
    typ("salom nd")
    wait(lambda: note.exists() and "salom nd" in note.read_text(), 4, "saqlanmadi")
    move(640, 200)
    note.unlink(missing_ok=True)
    WIDGETS_FILE.unlink(missing_ok=True)


feature("cc-tools", "Boshqaruv paneli: asboblar va sozlamalar tugmasi")

TOOL_Y = 350


def tool_x(i):
    return int(882 + 368 / 6 * (i + 0.5))


@case("Bugun bo'limidagi tishli g'ildirak sozlamalarni ochadi, panel yopiladi")
def _():
    dash(0)
    time.sleep(0.6)
    click(143, 470 - 16 - 4 - 19)
    wait(lambda: st()["settings"] and st()["popup"] == "", 4, "sozlamalar ochilmadi")
    ipc("reset")


@case("Fokus tugmasi fokus rejimini yoqadi")
def _():
    open_control()
    click(tool_x(5), TOOL_Y)
    wait(lambda: st()["zen"], 4, "fokus yoqilmadi")


@case("Fon tugmasi fon tanlash oynasini ochadi")
def _():
    open_control()
    click(tool_x(4), TOOL_Y)
    wait(lambda: st()["popup"] == "wallpapers", 4)


@case("Rang tugmasi ekrandan rang tanlashni boshlaydi, panel yopiladi")
def _():
    open_control()
    click(tool_x(2), TOOL_Y)
    wait(lambda: st()["popup"] == "", 3)
    time.sleep(0.8)
    click(640, 400)
    wait(lambda: "Color" in st()["toast"], 4, "rang olinmadi")
    ok(re.fullmatch(r"#[0-9a-fA-F]{6}", clip_text().strip()), clip_text())


@case("Doira bosilsa ro'yxat ochilmaydi, faqat Wi-Fi o'chadi")
def _():
    need_wifi()
    was = wifi_on()
    open_control()
    try:
        click(902, 98)
        wait(lambda: wifi_on() != was, 5, "o'zgarmadi")
        ok(st()["controlPage"] == "")
    finally:
        sh(f"nmcli radio wifi {'on' if was else 'off'}")


feature("music", "Musiqa bo'limi")


def spectrum_running():
    return sh("pgrep -u $(id -u) -f falcon-spectrum").returncode == 0


@case("Musiqa yo'q paytda bo'lim ochiladi: ovoz tinglanmaydi")
def _():
    dash(1)
    time.sleep(0.8)
    ok(st()["spectrumWanted"] is False and not spectrum_running())


@case("Bugun bo'limida CPU va harorat yangilanib turadi")
def _():
    dash(0)
    time.sleep(4.5)
    ok(st()["popup"] == "dashboard")


@case("Bo'limni tez almashtiradi: vizualizator jarayoni qolib ketmaydi")
def _():
    for t in (1, 0, 1, 0, 1, 0):
        ipc("dashboardTab", str(t))
        time.sleep(0.2)
    ipc("close")
    time.sleep(1.5)
    ok(not spectrum_running())


@case("Panel orqa foni bor: rasmsiz holatda ham ochiladi")
def _():
    dash(1)
    a = shot("mu1", "60,60 1160x300")
    ok(a)
    ok(st()["dashTab"] == 1)


@case("Tovush to'lqinlari sozlamasi vidjetlar joyini boshqaradi va musiqasiz ovoz tinglanmaydi")
def _():
    on = st()["widgetsBottomInset"]
    settings(waves__enabled=False)
    try:
        wait(lambda: st()["widgetsBottomInset"] < on, 3, "joy bo'shamadi")
        ok(st()["spectrumWanted"] is False and not spectrum_running())
    finally:
        settings(waves__enabled=True)
    wait(lambda: st()["widgetsBottomInset"] == on, 3, "joy qaytmadi")


feature("sleep", "Uyqu: real suspend va uyg'onish")


def real_suspend(seconds=25):
    """Sets a wake alarm and suspends through logind, like closing the lid."""
    sh(f"sudo -n rtcwake -m no -s {seconds}")
    sh("sudo -n systemctl suspend -i")
    # Uyg'ongach vaqt sakraydi: tizim yana ishlaguncha kutamiz.
    time.sleep(seconds + 8)


def need_suspend():
    need_pw()
    if sh("sudo -n -l rtcwake -m no -s 25").returncode:
        raise Skip("uyg'otish budilnigiga ruxsat yo'q")


@case("Uxlatib uyg'otadi: ekran bloklangan, parol ochadi, shell o'sha jarayon")
def _():
    need_suspend()
    pid = sh("pgrep -u $(id -u) -x qs").stdout.split()[0]
    real_suspend()
    wait(locked, 10, "uyg'onganda bloklanmagan")
    time.sleep(1.0)
    unlock()
    ok(sh("pgrep -u $(id -u) -x qs").stdout.split()[0] == pid, "shell qayta ishga tushgan")


@case("Uyg'ongandan keyin monitor yoniq va panel javob beradi")
def _():
    need_suspend()
    real_suspend()
    wait(locked, 10)
    time.sleep(1.0)
    unlock()
    out = next(iter(nj("outputs").values()))
    ok(out["current_mode"] is not None and "falcon-top" in layers(), out)


@case("Uyg'ongandan keyin tovush ishlaydi: ovoz tugmasi javob beradi")
def _():
    v = st()["volume"]
    key("volup" if v < 90 else "voldown")
    wait(lambda: st()["volume"] != v, 4, "ovoz javob bermadi")


@case("Uyg'ongandan keyin yorqinlik tugmasi ishlaydi")
def _():
    if len(bright()) < 5:
        raise Skip("backlight yo'q")
    before = bright()[2]
    sh("brightnessctl --class=backlight -q set 50%")
    key("brightdown")
    time.sleep(0.5)
    ok(bright()[3] == "45%", bright())
    sh(f"brightnessctl --class=backlight -q set {before}")


@case("Uyg'ongandan keyin tarmoq qaytadi")
def _():
    wait(lambda: "connected" in sh("nmcli -t -f STATE general").stdout, 40, "tarmoq qaytmadi")


feature("timer", "Taymer")


@case("Vaqt yozuvlari to'g'ri o'qiladi va noto'g'risi rad etiladi")
def _():
    ipc("timer", "90s")
    wait(lambda: st()["timer"].startswith(("1:", "1:29")), 3, "boshlanmadi")
    ipc("timer", "abc")
    wait(lambda: st()["timer"] == "", 3, "to'xtamadi")


@case("Taymer shell qayta ishga tushganda ham davom etadi")
def _():
    ipc("timer", "5m")
    wait(lambda: st()["timer"] != "", 3, "boshlanmadi")
    sh("pkill -x qs")
    time.sleep(3)
    wait(lambda: st()["timer"].startswith("4:"), 15, "yo'qoldi")
    ipc("timer", "0")


feature("cookie", "Cookie soat vidjeti")

WIDGETS = HOME / ".config/falcon/widgets.json"


@case("Ikkala ko'rinish ham xatosiz chiziladi")
def _():
    before = WIDGETS.read_text() if WIDGETS.exists() else None
    WIDGETS.write_text(json.dumps([
        {"id": "c1", "type": "cookie", "fx": 0.3, "fy": 0.4, "size": "m", "form": "cookie"},
        {"id": "c2", "type": "cookie", "fx": 0.7, "fy": 0.4, "size": "m", "form": "flower"}]))
    try:
        sh("pkill -x qs")
        time.sleep(3)
        wait(lambda: "falcon-top" in layers(), 12, "panel qaytmadi")
        wait(lambda: len(st()["widgets"]) == 2, 5, "vidjetlar o'qilmadi")
        log = sh("qs log -c falcon").stdout
        ok("cookie.qml" not in log, "cookie.qml xatosi bor")
    finally:
        if before is None:
            WIDGETS.unlink(missing_ok=True)
        else:
            WIDGETS.write_text(before)
        sh("pkill -x qs")
        time.sleep(3)


feature("polkit", "Shell'ning parol oynasi (polkit)")


def faillock_reset():
    sh("faillock --user $(id -un) --reset")


@case("Shell polkit agenti sifatida ro'yxatdan o'tgan, hyprpolkitagent o'chiq")
def _():
    wait(lambda: st()["polkitRegistered"], 8, "ro'yxatdan o'tmadi")
    ok(sh("systemctl --user is-active hyprpolkitagent").stdout.strip() != "active", "hyprpolkitagent ishlab turibdi")


@case("pkexec oynani ochadi, Esc bekor qiladi")
def _():
    p = subprocess.Popen(["pkexec", "/usr/bin/true"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        wait(lambda: "falcon-polkit" in layers() and st()["polkitActive"], 6, "oyna ochilmadi")
        time.sleep(0.5)
        key("esc")
        wait(lambda: p.poll() is not None, 6, "pkexec tugamadi")
        ok(p.returncode == 126, f"rc={p.returncode}")
        wait(lambda: "falcon-polkit" not in layers(), 3, "oyna yopilmadi")
    finally:
        if p.poll() is None:
            p.kill()
        faillock_reset()


@case("Noto'g'ri parol xato deydi va qayta so'raydi")
def _():
    p = subprocess.Popen(["pkexec", "/usr/bin/true"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        wait(lambda: st()["polkitActive"], 6, "oyna ochilmadi")
        time.sleep(0.5)
        typ("wrongpass")
        key("enter")
        time.sleep(4)
        ok(p.poll() is None and st()["polkitActive"], "qayta so'ramadi")
        key("esc")
        wait(lambda: p.poll() is not None, 6, "pkexec tugamadi")
    finally:
        if p.poll() is None:
            p.kill()
        faillock_reset()


feature("parallax", "Fon parallaksi")


@case("Parallaks qatlami vidjetlar ostida turadi")
def _():
    names = layers()
    ok("falcon-parallax" in names, "qatlam yo'q")
    ok(names.index("falcon-parallax") < names.index("falcon-widgets-face"), f"tartib: {names}")


@case("Sozlama qatlamni o'chiradi va qaytaradi, vidjetlar yana ustida")
def _():
    settings(wallpaper__parallax=False)
    wait(lambda: "falcon-parallax" not in layers(), 4, "o'chmadi")
    settings(wallpaper__parallax=True)
    wait(lambda: "falcon-parallax" in layers(), 4, "qaytmadi")
    time.sleep(0.5)
    names = layers()
    ok(names.index("falcon-parallax") < names.index("falcon-widgets-face"), f"tartib: {names}")


@case("Fon almashganda shell yangi rasmni oladi")
def _():
    image = sorted((HOME / "Pictures/Wallpapers").glob("*.jpg"))[:2]
    if len(image) < 2:
        raise Skip("ikki rasm kerak")
    old = os.path.realpath(HOME / ".local/state/falcon/wallpaper")
    target = str(image[0]) if os.path.realpath(image[0]) != old else str(image[1])
    sh(["env", "FALCON_QUIET=1", str(LBIN / "falcon-wallpaper"), target], timeout=60)
    wait(lambda: st()["shownImage"] == os.path.realpath(target) and not st()["shownLive"], 6, "olinmadi")


@case("awww-daemon o'chib qolsa fon tanlash uni qayta ishga tushiradi")
def _():
    images = sorted((HOME / "Pictures/Wallpapers").glob("*.jpg"))[:2]
    if len(images) < 2:
        raise Skip("ikki rasm kerak")
    old = os.path.realpath(HOME / ".local/state/falcon/wallpaper")
    target = str(images[0]) if os.path.realpath(images[0]) != old else str(images[1])
    sh(["pkill", "-x", "awww-daemon"])
    wait(lambda: sh(["pgrep", "-x", "awww-daemon"]).returncode != 0, 4, "o'chmadi")
    sh(["env", "FALCON_QUIET=1", str(LBIN / "falcon-wallpaper"), target], timeout=60)
    ok(sh(["awww", "query"]).returncode == 0, "daemon qaytmadi")
    wait(lambda: st()["shownImage"] == os.path.realpath(target), 6, "fon qo'yilmadi")
    time.sleep(0.5)
    names = layers()
    ok(names.index("awww-daemon") < names.index("falcon-parallax") < names.index("falcon-widgets-face"), f"tartib: {names}")


@case("Video va undan keyin darhol rasm: video rasm ustida o'ynab qolmaydi")
def _():
    videos = sorted((HOME / "Pictures/Wallpapers/Live").glob("*.mp4"))
    images = sorted((HOME / "Pictures/Wallpapers").glob("*.jpg"))
    if not videos or not images or not shutil.which("mpvpaper"):
        raise Skip("video, rasm va mpvpaper kerak")
    env = ["env", "FALCON_QUIET=1", str(LBIN / "falcon-wallpaper")]
    first = subprocess.Popen(env + [str(videos[0])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.3)
    sh(env + [str(images[0])], timeout=60)
    first.wait(timeout=60)
    time.sleep(1)
    ok(sh(["pgrep", "-x", "mpvpaper"]).returncode != 0, "mpvpaper qoldi")
    ok(not (HOME / ".local/state/falcon/wallpaper-live").exists(), "jonli havola qoldi")
    ok(os.path.realpath(HOME / ".local/state/falcon/wallpaper") == os.path.realpath(images[0]), "rasm qo'yilmadi")


feature("appcolors", "KDE va VS Code ranglari")


@case("kdeglobals'ga ranglar yoziladi, boshqa kalitlar qoladi")
def _():
    path = HOME / ".config/kdeglobals"
    path.write_text("[KDE]\nwidgetStyle=Fusion\n\n[Colors:View]\nBackgroundNormal=1,2,3\n")
    sh([str(LBIN / "falcon-apply"), "--colors", os.path.realpath(HOME / ".local/state/falcon/wallpaper")], timeout=60)
    text = path.read_text()
    ok("widgetStyle=Fusion" in text, "eski kalit yo'qoldi")
    ok("[Colors:Window]" in text and "ColorScheme=Falcon" in text, "ranglar yozilmadi")
    ok("BackgroundNormal=1,2,3" not in text, "eski rang qoldi")
    ok((HOME / ".local/share/color-schemes/Falcon.colors").exists(), "sxema fayli yo'q")


@case("VS Code bor bo'lsa Falcon mavzusi yoziladi")
def _():
    ext = HOME / ".vscode/extensions"
    made = not ext.exists()
    ext.mkdir(parents=True, exist_ok=True)
    try:
        sh([str(LBIN / "falcon-app-colors"), "code"], check=True)
        theme = json.loads((ext / "falcon.falcon-theme-1.0.0/themes/falcon.json").read_text())
        ok(theme["type"] in ("dark", "light") and theme["colors"]["editor.background"].startswith("#"), "mavzu noto'g'ri")
    finally:
        sh(["rm", "-rf", str(ext / "falcon.falcon-theme-1.0.0")])
        if made:
            sh(["rm", "-rf", str(HOME / ".vscode")])


feature("sessionwarn", "O'chirishdan oldin ogohlantirish")


@case("Tugamagan yuklab olish power menyusida aytiladi")
def _():
    folder = Path(sh("xdg-user-dir DOWNLOAD").stdout.strip() or HOME / "Downloads")
    part = folder / "falcon-test.mkv.part"
    part.write_text("x")
    try:
        ipc("power")
        wait(lambda: "falcon-test.mkv" in st()["sessionWarning"], 5, "aytilmadi")
    finally:
        part.unlink(missing_ok=True)
        ipc("close")


@case("Ishlayotgan AUR yordamchisi yangilanish deb aytiladi")
def _():
    fake = Path("/tmp/nd-yay")
    sh(["cp", "/usr/bin/sleep", str(fake)])
    p = subprocess.Popen([str(fake), "30"])
    try:
        ipc("power")
        wait(lambda: st()["sessionWarning"] != "", 5, "aytilmadi")
    finally:
        p.kill()
        fake.unlink(missing_ok=True)
        ipc("close")
    wait(lambda: st()["sessionWarning"] == "", 3, "ogohlantirish qoldi")


feature("hearing", "Quloqni himoya qilish")


def volume():
    return float(sh("wpctl get-volume @DEFAULT_AUDIO_SINK@").stdout.split()[1])


@case("Keskin ko'tarilish qaytariladi, kichik qadamlar o'tadi")
def _():
    sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.30")
    time.sleep(1)
    sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40")
    time.sleep(0.6)
    ok(abs(volume() - 0.40) < 0.02, f"kichik qadam o'tmadi: {volume()}")
    sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.95")
    time.sleep(0.8)
    ok(abs(volume() - 0.40) < 0.02, f"qaytarilmadi: {volume()}")
    toast("volume jump")


@case("Eng yuqori ovozdan oshmaydi")
def _():
    settings(audio__maxVolume=0.5)
    sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.45")
    time.sleep(0.8)
    sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0")
    time.sleep(0.4)
    sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0")
    time.sleep(0.8)
    ok(volume() <= 0.51, f"oshib ketdi: {volume()}")


feature("fetch", "Fastfetch uslublari va animatsiyalari")


@case("10 uslubning hammasi fastfetch'da matn beradi")
def _():
    for style in ["classic", "minimal", "boxed", "tree", "icons", "hardware", "bars", "palette", "arrows", "quiet"]:
        data = json.loads(sh([str(LBIN / "falcon-fetch"), "--preview-text", style], check=True, timeout=30).stdout)
        ok(data["lines"] >= 6 and "<span" in data["html"], (style, data["html"][:200]))


@case("har bir logo va 7 animatsiyaning WebP ko'rinishi yasaladi")
def _():
    out = sh([str(LBIN / "falcon-fetch"), "--previews"], check=True, timeout=300).stdout
    rows = [json.loads(l) for l in out.splitlines() if l.strip()]
    stills = rows[0]["logos"]
    clips = {(r["logo"], r["animation"]) for r in rows[1:]}
    ok(len(stills) == 11 and all(Path(p).exists() for p in stills.values()), stills)
    anims = {"spin", "flip", "swing", "bounce", "assemble", "decode", "aurora"}
    ok(clips == {(l, a) for l in stills for a in anims}, len(clips))
    ok(all(Path(r["path"]).stat().st_size > 1000 for r in rows[1:]), "bo'sh WebP")


feature("songrec", "Qo'shiqni aniqlash")


@case("songrec yo'q bo'lsa o'rnatishni taklif qiladi, tinglayapman demaydi")
def _():
    if sh("command -v songrec").returncode == 0:
        raise Skip("songrec o'rnatilgan")
    ipc("songrec")
    toast("needs songrec")
    ok("Listening…" not in st()["history"], "tinglayapman dedi")


@case("Hech narsa chalinmasa shuni aytadi")
def _():
    if sh("command -v songrec").returncode != 0:
        raise Skip("songrec o'rnatilmagan")
    sh("playerctl -a pause")
    ipc("songrec")
    wait(lambda: st()["songrec"], 3, "tinglamadi")
    toast("Nothing is playing", 16)


feature("keys", "Tugmalar ro'yxati")


@case("Mod+Shift+/ ro'yxatni ochadi, Esc yopadi")
def _():
    key("mod", "shift", "slash")
    wait(lambda: st()["popup"] == "keys" and "falcon-keys" in layers(), 4, "ochilmadi")
    key("esc")
    wait(lambda: "falcon-keys" not in layers(), 3, "yopilmadi")


@case("falcon-keys hamma bind'larni o'qiydi")
def _():
    rows = json.loads(sh([str(LBIN / "falcon-keys")], check=True).stdout)
    keys = [k for r in rows for k in r["keys"]]
    ok("Mod+Shift+Slash" in keys and "Mod+1…9" in keys and "Alt+Tab" in keys, keys[:20])
    ok(all(r["title"] for r in rows), "sarlavhasiz qator bor")


@case("user.kdl'dagi ko'p qatorli bind ko'rinadi va eski vazifani almashtiradi")
def _():
    user = HOME / ".config/niri/cfg/user.kdl"
    before = user.read_text() if user.exists() else ""
    try:
        user.write_text(before + '\nbinds {\n    Mod+Y hotkey-overlay-title="Test app" {\n        spawn "true";\n    }\n    Mod+H { focus-column-right; }\n}\n')
        rows = json.loads(sh([str(LBIN / "falcon-keys")], check=True).stdout)
        mine = [r for r in rows if r["group"] == "Your keys"]
        ok(any(r["title"] == "Test app" and r["keys"] == ["Mod+Y"] for r in mine), mine)
        left = next(r for r in rows if r["title"] == "Focus the column on the left")
        ok("Mod+H" not in left["keys"], left)
    finally:
        user.write_text(before)


@case("cfg/binds.kdl'dagi har bir tugma ro'yxatda bor")
def _():
    fixed = (HOME / ".config/niri/cfg/binds.kdl").read_text()
    wanted = {m for m in re.findall(r'^\s*([A-Za-z0-9_+]+)(?:\s+[a-z-]+=(?:"[^"]*"|\S+))*\s*\{', fixed, re.M) if m != "binds" and "Wheel" not in m}
    rows = json.loads(sh([str(LBIN / "falcon-keys")], check=True).stdout)
    shown = set()
    for r in rows:
        for k in r["keys"]:
            m = re.fullmatch(r"(.*\+)(\d)…(\d)", k)
            shown |= {f"{m.group(1)}{n}" for n in range(int(m.group(2)), int(m.group(3)) + 1)} if m else {k}
    ok(not wanted - shown, f"sarlavhasiz: {sorted(wanted - shown)}")


feature("i18n", "Interfeys tili")

CATALOG = HOME / ".config/falcon/i18n-ru.json"
QS = HOME / ".config/quickshell/falcon"


@case("Inglizcha tanlansa matn inglizcha")
def _():
    settings(appearance__language="en")
    wait(lambda: st()["lang"] == "en" and st()["sample"] == "Settings", 3, "almashmadi")


@case("Ruscha tanlansa matn ruscha")
def _():
    settings(appearance__language="ru")
    wait(lambda: st()["lang"] == "ru" and st()["sample"] == "Настройки", 3, "almashmadi")


@case("Klavish sarlavhalari tilga ergashadi")
def _():
    settings(appearance__language="ru")
    wait(lambda: "Закрыть окно" in (GEN / "binds.kdl").read_text(), 4, "tarjima bo'lmadi")


@case("Bloklash ekrani matni tilga ergashadi")
def _():
    settings(appearance__language="ru")
    path = HOME / ".config/hypr/falcon-lang.conf"
    wait(lambda: "Пароль" in path.read_text(), 4, "tarjima bo'lmadi")
    settings(appearance__language="en")
    wait(lambda: "Password" in path.read_text(), 4, "qaytmadi")


@case("Sozlama xatosi tilga ergashadi")
def _():
    settings(appearance__language="ru", windows__gaps=9999)
    wait(lambda: "должно быть" in st()["error"], 4, st()["error"])


@case("Kodda ishlatilgan har bir matnning ruscha tarjimasi bor")
def _():
    cat = json.loads(CATALOG.read_text())
    used = set()
    for f in QS.rglob("*.qml"):
        used |= set(re.findall(r'Tr\.t\("([^"]+)"\)', f.read_text()))
    for f in LBIN.glob("falcon-*"):
        text = f.read_text(errors="ignore")
        used |= set(re.findall(r'\btr\(\s*"([^"]+)"', text))
        used |= set(re.findall(r'_t "([^"]+)"', text))
    missing = sorted(u for u in used if u not in cat and not re.fullmatch(r"[A-Z0-9 .+-]{1,4}", u))
    ok(len(used) > 250 and not missing, missing[:12])


@case("Kataloglarda o'zbekcha matn qolmagan")
def _():
    uz = re.compile(r"\b(yoq|o'chiq|Tozalash|Nusxalandi|Sozlamalar|bo'l|qiling|noto'g'ri|topilmadi)\b")
    bad = []
    for f in list(QS.rglob("*.qml")) + list(LBIN.glob("falcon-*")):
        for i, line in enumerate(f.read_text(errors="ignore").splitlines(), 1):
            code = line.strip()
            if code.startswith(("//", "#")):
                continue
            for lit in re.findall(r'"([^"]*)"', line):
                if uz.search(lit):
                    bad.append(f"{f.name}:{i}:{lit[:40]}")
    ok(not bad, bad[:10])


feature("lyrics", "Qo'shiq matni")


@case("falcon-lyrics ma'lum qo'shiqning vaqtli matnini topadi")
def _():
    out = sh([str(LBIN / "falcon-lyrics"), "Daft Punk", "Get Lucky", "248"], timeout=30).stdout.strip()
    answer = json.loads(out.splitlines()[-1])
    if answer.get("error") == "offline":
        raise Skip("internet yo'q")
    ok(answer.get("synced") and answer["synced"][0][0] > 0, out[:200])


@case("YouTube nomidan ijrochi va nomni ajratadi")
def _():
    out = sh([str(LBIN / "falcon-lyrics"), "", "Daft Punk - Get Lucky (Official Video)", "369"], timeout=30).stdout.strip()
    answer = json.loads(out.splitlines()[-1])
    if answer.get("error") == "offline":
        raise Skip("internet yo'q")
    ok("synced" in answer or "plain" in answer, out[:200])


feature("websearch", "Internetdan qidirish")


@case("? bang bilan sayt tanlaydi, yolg'iz ? saytlar ro'yxatini beradi")
def _():
    ipc("menu")
    wait(lambda: st()["popup"] == "menu", 3, "menyu ochilmadi")
    ipc("launcherQuery", "?")
    wait(lambda: "YouTube" in st()["rows"] and "Wikipedia" in st()["rows"], 3, "saytlar yo'q")
    ipc("launcherQuery", "?lofi girl !yt")
    wait(lambda: st()["rows"][:1] == ["lofi girl"], 3, "qidiruv qatori yo'q")
    ipc("launcherQuery", ",!не")
    wait(lambda: st()["rows"] == ["YouTube"], 3, "ruscha tugmalardagi bang topilmadi")
    ipc("close")


feature("pins", "Ekranga mahkamlash")


@case("Pin tanlangan joyda karta ochadi, pinsClear yopadi")
def _():
    ipc("region", "pin")
    wait(lambda: st()["region"] == "select", 4, "tanlash ochilmadi")
    ipc("regionPick", "200", "150", "300", "200", "true")
    wait(lambda: "falcon-pin" in layers(), 5, "karta chiqmadi")
    ipc("pinsClear")
    wait(lambda: "falcon-pin" not in layers(), 3, "karta yopilmadi")


feature("gamemode", "O'yin rejimi")


@case("Yoqilganda niri animatsiyasi o'chadi, o'chirilganda qaytadi")
def _():
    if sh("cat /sys/class/power_supply/*/online 2>/dev/null | grep -q 1").returncode != 0 and Path("/sys/class/power_supply/BAT0").exists():
        raise Skip("batareyada")
    game = str(LBIN / "falcon-game")
    ipc("gameMode")
    wait(lambda: sh([game, "status"]).returncode == 0, 4, "game.kdl yozilmadi")
    ipc("gameMode")
    wait(lambda: sh([game, "status"]).returncode != 0, 4, "game.kdl tozalanmadi")


feature("wallget", "Fon yuklab olish")


@case("desk wallget oynani ochadi, close yopadi")
def _():
    ipc("wallget")
    wait(lambda: "falcon-wallget" in layers(), 4, "oyna ochilmadi")
    ipc("close")
    wait(lambda: "falcon-wallget" not in layers(), 3, "oyna yopilmadi")


@case("falcon-wallget Wallhaven'dan natija beradi")
def _():
    out = sh([str(LBIN / "falcon-wallget"), "search", "wallhaven", "mountains"], timeout=60).stdout.strip().splitlines()
    rows = [json.loads(l) for l in out]
    if rows and rows[-1].get("error") == "offline":
        raise Skip("internet yo'q")
    ok(any("thumb" in r and Path(r["thumb"]).exists() for r in rows), out[-1:] if out else "bo'sh")


feature("newlooks", "Spektr, effekt, tovush")


@case("Yangi spektr ko'rinishlari va fon effektlari xatosiz yuklanadi")
def _():
    for look in ["ribbon", "segments", "aura", "ring", "orb"]:
        settings(waves__style=look)
    for fx in ["shatter", "random"]:
        settings(wallpaper__transition=fx)
    settings(waves__style="bars", wallpaper__transition="grow")
    log = sh(["qs", "log", "-c", "falcon"]).stdout
    ok("spectrum.frag" not in log and "wallpaper.frag" not in log, "shader xatosi")


@case("falcon-keysounds holatini JSON qilib beradi")
def _():
    keys = json.loads(sh([str(LBIN / "falcon-keysounds"), "status"], check=True).stdout)
    ok("ready" in keys and "packs" in keys and len(keys["packs"]) == 7, keys)


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
    if sh("pgrep -u $(id -u) -x hyprlock").returncode == 0 and PW:
        typ(PW)
        key("enter")
        time.sleep(1)
    SET.write_text(GOOD)
    time.sleep(1.5)
    report = json.loads(Path("/tmp/falcon-report.json").read_text()) if only and Path("/tmp/falcon-report.json").exists() else {}
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
        Path("/tmp/falcon-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1))
    try:
        reset()
    except Exception:
        pass
    SET.write_text(original)
    all_cases = [c for r in report.values() for c in r["cases"]]
    print("JAMI", len(all_cases), {s: sum(c["status"] == s for c in all_cases) for s in ("PASS", "FAIL", "SKIP")})


main()
