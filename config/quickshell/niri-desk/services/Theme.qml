pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ranglar matugen yozgan colors.json faylidan olinadi va fon almashganda silliq o'zgaradi.
Singleton {
    id: root

    property color accent: "#8fc7ee"
    property color accentText: "#00344f"
    property color pill: "#05090f"
    property color surface: "#101418"
    property color text: "#e4e7ec"
    property color muted: "#a9b1bb"
    property color outline: "#3a4652"
    property color error: "#ffb4ab"
    readonly property color good: "#8fd6a0"

    readonly property string sans: Settings.get("appearance.font", "Geist")
    readonly property string mono: Settings.get("appearance.monoFont", "Geist Mono")
    readonly property real fontScale: Settings.get("appearance.fontScale", 1)
    readonly property color panel: Qt.alpha(pill, Settings.get("appearance.panelOpacity", 1))

    readonly property int fontSmall: 12
    readonly property int fontBody: 14

    Behavior on accent {
        ColorAnimation {
            duration: 500
        }
    }
    Behavior on pill {
        ColorAnimation {
            duration: 500
        }
    }
    Behavior on text {
        ColorAnimation {
            duration: 500
        }
    }
    Behavior on muted {
        ColorAnimation {
            duration: 500
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/niri-desk/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const c = JSON.parse(text());
                for (const key of ["accent", "accentText", "pill", "surface", "text", "muted", "outline", "error"]) {
                    if (c[key])
                        root[key] = c[key];
                }
            } catch (e) {
                console.warn("Could not read colors.json:", e);
            }
        }
    }
}
