pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ochiq panellar, fokus rejimi va ekran yozish holati.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string binDir: home + "/.local/bin/"

    // "", menu, power, clipboard, wallpapers, dashboard, control, claude
    property string popup: ""
    property bool zen: false
    property bool settingsOpen: false
    property int settingsPage: 0
    // Places in the pages list of SettingsWindow, for panels that open a page directly.
    readonly property int pageMonitors: 8
    readonly property int pagePower: 13
    // Grows each time a notification card flies into the bell, so the bell can ring.
    property int bellRings: 0
    // "", wifi, bluetooth
    property string controlPage: ""
    // The bell's menu: 0 this computer's notifications, 1 the phone's.
    property int notificationsTab: 0
    // The page open in the phone window, "" for its home screen.
    property string phonePage: ""
    property var trayItem: null
    // The bar of the focused screen, for `desk state`.
    property var barLayer: null
    property var launcherRows: []
    property int launcherSelected: 0
    // The picker stays on screen after the popup changes, until its closing animation ends.
    property bool pickerAlive: false
    // The app menu does the same.
    property bool menuAlive: false
    // And the power menu.
    property bool powerAlive: false
    onPopupChanged: {
        if (popup === "wallpapers")
            pickerAlive = true;
        if (popup === "menu")
            menuAlive = true;
        if (popup === "power")
            powerAlive = true;
    }
    property int pickerSelected: 0
    property int pickerFiles: 0
    property int pickerTab: 1
    // The tab a closed picker opens on, from `desk wallpapersTab`. -1 opens on the current wallpaper.
    property int pickerOpenTab: -1
    property real controlHeight: 0
    property bool recording: false
    property int recordSeconds: 0
    // Seconds left before a delayed recording starts, 0 when none waits.
    property int recordCountdown: 0
    readonly property bool recordBusy: recording || recordCountdown > 0

    // The menus that drop from the bar.
    readonly property bool topPanelOpen: ["calendar", "player", "system", "notifications", "control", "tray", "claude", "phone", "net"].includes(popup)

    // Choosing a part of the screen: "" closed, "wait" lets panels close first, "grab" pictures
    // the screens, "select" shows them.
    property string regionPhase: ""
    property string regionAction: "copy"
    property bool regionLasso: false
    property int regionReady: 0
    readonly property string regionDir: Quickshell.env("XDG_RUNTIME_DIR") + "/falcon-region"

    // The picture being translated in its own window, "" when that window is closed.
    property string translateSource: ""
    property int translateWidth: 1
    property int translateHeight: 1

    property string switcherPhase: ""
    property var switcherRows: []
    property int switcherSelected: 0

    signal launcherInject(string text)
    signal switcherStep(int step, bool sameApp)
    signal switcherEnd(bool confirm)
    signal regionPicked(real x, real y, real w, real h, bool done)

    function togglePopup(name) {
        popup = popup === name ? "" : name;
    }

    // Opens the selector, or changes its action or closes it when it is already open.
    function region(action) {
        if (action === "record" && recordBusy) {
            run("falcon-record", "--stop");
            return;
        }
        if (regionPhase !== "") {
            if (regionAction === action)
                regionCancel();
            else
                regionAction = action;
            return;
        }
        regionAction = action;
        regionLasso = false;
        regionReady = 0;
        // A panel that is closing must not get into the picture.
        const panel = popup !== "" || menuAlive || powerAlive || pickerAlive;
        popup = "";
        regionPhase = "wait";
        regionDelay.interval = panel ? 300 : 1;
        regionDelay.restart();
    }

    function regionGrabbed(ok) {
        if (regionPhase !== "grab")
            return;
        if (!ok) {
            regionCancel();
            return;
        }
        regionReady += 1;
        if (regionReady >= Quickshell.screens.length)
            regionPhase = "select";
    }

    function regionCancel() {
        regionDelay.stop();
        regionPhase = "";
        Quickshell.execDetached(["rm", "-rf", regionDir]);
    }

    // The chosen action works from the picture, so it is not removed here.
    function regionFinished() {
        regionPhase = "";
    }

    function translateImage(path, width, height) {
        const before = translateSource;
        translateSource = "";
        if (before !== "")
            removeTranslateFiles(before);
        translateWidth = Math.max(1, width);
        translateHeight = Math.max(1, height);
        translateSource = path;
    }

    function translateClose() {
        if (translateSource === "")
            return;
        removeTranslateFiles(translateSource);
        translateSource = "";
    }

    function removeTranslateFiles(path) {
        Quickshell.execDetached(["rm", "-f", path, path + ".translated.png", path + ".keep"]);
    }

    function setRecording(on) {
        recording = on;
        recordSeconds = 0;
        if (on)
            recordCountdown = 0;
    }

    // The options on the record page, read by falcon-record from the saved toggles.
    function recordOption(key, fallback) {
        const value = (Saved.get("record", {}) || {})[key];
        return value === undefined ? fallback : value;
    }

    function setRecordOption(key, value) {
        const next = Object.assign({}, Saved.get("record", {}) || {});
        next[key] = value;
        Saved.set("record", next);
    }

    // Starts with the saved options, or stops what runs.
    function toggleRecording() {
        if (recordBusy) {
            run("falcon-record", "--stop");
            return;
        }
        if (recordOption("area", "region") === "screen") {
            popup = "";
            // The control center must be gone from the picture first.
            recordStart.restart();
        } else {
            region("record");
        }
    }

    function run(script, ...args) {
        Quickshell.execDetached([binDir + script, ...args]);
    }

    function pad(n) {
        return String(n).padStart(2, "0");
    }

    Timer {
        id: regionDelay

        onTriggered: root.regionPhase = "grab"
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.recordSeconds += 1
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recordCountdown > 0
        onTriggered: root.recordCountdown = Math.max(0, root.recordCountdown - 1)
    }

    Timer {
        id: recordStart

        interval: 300
        onTriggered: root.run("falcon-record", "--screen")
    }

    // Focus mode writes "// zen" first in zen.kdl. The file also holds steps of its corner animation.
    FileView {
        path: root.home + "/.config/niri/generated/zen.kdl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.zen = text().startsWith("// zen")
    }
}
