#!/usr/bin/env python3
"""Lays Falcon's way out of the login screen (FalconLeave.qml) over the sddm-astronaut theme.

Usage: falcon-theme-patch.py THEME_DIR [--undo]

Run by falcon-login with sudo. Safe to repeat: each edit checks for its own mark first. The Input
keeps calling sddm.login itself until FalconLeave says it is there (`falconHooked`), so a theme
where FalconLeave failed to load still logs in.
"""
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LOGIN = "        sddm.login(targetUser, password.text, sessionSelect.selectedSession)\n"
HOOKED = ("        if (falconHooked) falconLogin(targetUser, password.text, sessionSelect.selectedSession)\n"
          "        else sddm.login(targetUser, password.text, sessionSelect.selectedSession)\n")
SIGNAL = ("    property bool failed\n"
          "    property bool falconHooked: false  // falcon\n"
          "    signal falconLogin(string user, string secret, int session)  // falcon\n")
ALIAS = "    property alias falconInput: input  // falcon\n"
LEAVE = ("    FalconLeave {  // falcon\n"
         "        scene: sizeHelper\n"
         "        form: form\n"
         "        input: form.falconInput\n"
         "    }  // falcon\n")


def edit(path, change):
    text = path.read_text()
    new = change(text)
    if new != text:
        path.write_text(new)


def patch(theme):
    shutil.copy(HERE / "FalconLeave.qml", theme / "Components/FalconLeave.qml")

    def input_qml(text):
        if "falconHooked" in text:
            return text
        if LOGIN not in text or "    property bool failed\n" not in text:
            raise SystemExit("Input.qml is not the expected version, left alone")
        return text.replace("    property bool failed\n", SIGNAL, 1).replace(LOGIN, HOOKED, 1)

    def form_qml(text):
        if "falconInput" in text:
            return text
        mark = "    id: formContainer\n"
        if mark not in text:
            raise SystemExit("LoginForm.qml is not the expected version, left alone")
        return text.replace(mark, mark + ALIAS, 1)

    def main_qml(text):
        if "FalconLeave" in text:
            return text
        end = text.rstrip().rfind("}")
        return text[:end] + "\n" + LEAVE + "}\n"

    edit(theme / "Components/LoginForm.qml", form_qml)
    edit(theme / "Components/Input.qml", input_qml)
    edit(theme / "Main.qml", main_qml)


def undo(theme):
    def strip(text):
        text = text.replace(HOOKED, LOGIN).replace(SIGNAL, "    property bool failed\n")
        text = text.replace(ALIAS, "").replace("\n" + LEAVE, "")
        return text

    for name in ("Components/Input.qml", "Components/LoginForm.qml", "Main.qml"):
        edit(theme / name, strip)
    (theme / "Components/FalconLeave.qml").unlink(missing_ok=True)


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    theme = Path(sys.argv[1])
    if not (theme / "Main.qml").exists():
        print(f"No theme in {theme}", file=sys.stderr)
        return 1
    if "--undo" in sys.argv:
        undo(theme)
    else:
        patch(theme)
    return 0


sys.exit(main())
