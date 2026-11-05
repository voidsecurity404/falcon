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
    readonly property int pageMonitors: 6
    readonly property int pagePower: 11
    readonly property int pageSnippets: 15
    readonly property int pageDevices: 16
    readonly property int pageBackups: 17
    property int dashTab: 0
    // "", wifi, bluetooth
    property string controlPage: ""
    property var trayItem: null
    property var launcherRows: []
    property int launcherSelected: 0
    // The picker stays on screen after the popup changes, until its closing animation ends.
    property bool pickerAlive: false
    // The app menu does the same.
    property bool menuAlive: false
    // And the power menu.
    property bool powerAlive: false
    // Quick Look and the quick note too.
    property bool quickAlive: false
    property bool noteAlive: false
    property var quickFiles: []
    property int quickIndex: 0
    property bool backupsOpen: false
    property bool dictating: false
    property bool transcribing: false
    property bool stagesOn: false
    onStagesOnChanged: Saved.set("stages", stagesOn)
    Component.onCompleted: stagesOn = Saved.get("stages", false)
    onPopupChanged: {
        if (popup === "quicklook")
            quickAlive = true;
        if (popup === "note")
            noteAlive = true;
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
    property real controlHeight: 0
    property bool recording: false
    property int recordSeconds: 0

    readonly property bool topPanelOpen: popup === "dashboard" || popup === "control" || popup === "tray" || popup === "claude"

    // Choosing a part of the screen: "" closed, "wait" lets panels close first, "grab" pictures
    // the screens, "select" shows them.
    property string regionPhase: ""
    property string regionAction: "copy"
    property bool regionLasso: false
    property int regionReady: 0
    readonly property string regionDir: Quickshell.env("XDG_RUNTIME_DIR") + "/niri-desk-region"

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

    function quickLook(files, index) {
        if (files.length === 0)
            return;
        quickFiles = files;
        quickIndex = Math.max(0, Math.min(files.length - 1, index || 0));
        popup = "quicklook";
    }

    // The empty workspace niri keeps last becomes the new stage.
    function stageNew() {
        const list = Niri.workspacesOn(Niri.focusedOutput);
        if (list.length > 0)
            Niri.action("move-column-to-workspace", String(list[list.length - 1].idx));
    }

    // Opens the selector, or changes its action or closes it when it is already open.
    function region(action) {
        if (action === "record" && recording) {
            run("niri-desk-record");
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
        const panel = popup !== "" || menuAlive || powerAlive || pickerAlive || quickAlive || noteAlive;
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
        Quickshell.execDetached(["rm", "-f", path, path + ".translated.png"]);
    }

    function setRecording(on) {
        recording = on;
        recordSeconds = 0;
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

    // Focus mode writes "// zen" first in zen.kdl. The file also holds steps of its corner animation.
    FileView {
        path: root.home + "/.config/niri/generated/zen.kdl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.zen = text().startsWith("// zen")
    }
}
