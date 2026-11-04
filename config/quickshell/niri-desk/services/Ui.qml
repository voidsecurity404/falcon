pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ochiq panellar, fokus rejimi va ekran yozish holati.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string binDir: home + "/.local/bin/"

    // "", launcher, clipboard, wallpapers, dashboard, control, claude
    property string popup: ""
    property bool zen: false
    property bool settingsOpen: false
    property int settingsPage: 0
    property int dashTab: 0
    // "", wifi, bluetooth, sound
    property string controlPage: ""
    property var trayItem: null
    property var launcherRows: []
    property int launcherSelected: 0
    // The picker stays on screen after the popup changes, until its closing animation ends.
    property bool pickerAlive: false
    onPopupChanged: {
        if (popup === "wallpapers")
            pickerAlive = true;
    }
    property int pickerSelected: 0
    property int pickerFiles: 0
    property int pickerTab: 1
    property real controlHeight: 0
    property bool recording: false
    property int recordSeconds: 0

    readonly property bool topPanelOpen: popup === "dashboard" || popup === "control" || popup === "tray" || popup === "claude"

    signal launcherInject(string text)

    function nextDashTab(step) {
        dashTab = (dashTab + step + 3) % 3;
    }

    function togglePopup(name) {
        popup = popup === name ? "" : name;
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
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.recordSeconds += 1
    }

    // Fokus rejimi yoqilganda zen.kdl bo'sh bo'lmaydi.
    FileView {
        path: root.home + "/.config/niri/generated/zen.kdl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.zen = text().trim().length > 0
    }
}
