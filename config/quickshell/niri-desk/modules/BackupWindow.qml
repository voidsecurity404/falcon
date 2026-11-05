import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Time Machine: snapshots on the left, the folders of the chosen one on the right. Restoring puts
// a copy in a folder of its own, so nothing that exists now is overwritten.
LazyLoader {
    active: Ui.backupsOpen

    FloatingWindow {
        id: win

        property var snapshots: []
        property string snapshot: ""
        property string folder: Quickshell.env("HOME")
        property var entries: []
        property string chosen: ""
        property bool busy: false
        property bool loadingFolder: false

        function open(path) {
            folder = path;
            chosen = "";
            entries = [];
            loadingFolder = true;
            lister.running = false;
            lister.exec([Ui.binDir + "niri-desk-timemachine", "ls", snapshot, path]);
        }

        function chooseSnapshot(id) {
            snapshot = id;
            open(folder);
        }

        title: "niri-desk backups"
        implicitWidth: 920
        implicitHeight: 620
        color: Qt.alpha(Theme.surface, Math.max(0.8, Theme.panel.a))
        onClosed: Ui.backupsOpen = false

        Process {
            running: true
            command: [Ui.binDir + "niri-desk-timemachine", "list"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        win.snapshots = JSON.parse(text);
                    } catch (e) {
                        win.snapshots = [];
                    }
                    if (win.snapshots.length > 0)
                        win.chooseSnapshot(win.snapshots[0].id);
                }
            }
        }
        Process {
            id: lister

            stdout: StdioCollector {
                onStreamFinished: {
                    win.loadingFolder = false;
                    try {
                        win.entries = JSON.parse(text);
                    } catch (e) {
                        win.entries = [];
                    }
                }
            }
        }
        Process {
            id: restorer

            stdout: StdioCollector {
                onStreamFinished: {
                    win.busy = false;
                    const target = text.trim();
                    if (target !== "")
                        Toasts.show(Tr.t("Restored"), target, "check", () => Quickshell.execDetached(["xdg-open", target]));
                    else
                        Toasts.show(Tr.t("Could not restore it"), "", "alert");
                }
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Ui.backupsOpen = false

            // Snapshots
            Column {
                x: 16
                y: 16
                width: 230
                height: parent.height - 32
                spacing: 8

                Label {
                    text: Tr.t("Backups")
                    size: 13
                    color: Theme.muted
                }
                ListView {
                    width: parent.width
                    height: parent.height - 28
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.snapshots
                    delegate: Rectangle {
                        required property var modelData

                        width: ListView.view.width
                        height: 38
                        radius: 10
                        color: win.snapshot === modelData.id ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.text, snapArea.containsMouse ? 0.08 : 0)

                        Label {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.time
                            size: 13
                        }
                        MouseArea {
                            id: snapArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.chooseSnapshot(parent.modelData.id)
                        }
                    }
                }
            }

            // Files
            Item {
                x: 262
                y: 16
                width: parent.width - x - 16
                height: parent.height - 32

                Row {
                    id: pathRow

                    width: parent.width
                    height: 34
                    spacing: 8

                    PillButton {
                        icon: "back"
                        implicitWidth: 38
                        enabledLook: win.folder !== "/"
                        onClicked: {
                            if (win.folder !== "/")
                                win.open(win.folder.slice(0, win.folder.lastIndexOf("/")) || "/");
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 46
                        text: win.folder
                        size: 13
                        color: Theme.muted
                        elide: Text.ElideMiddle
                    }
                }
                ListView {
                    y: 42
                    width: parent.width
                    height: parent.height - 42 - 46
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.entries
                    delegate: Rectangle {
                        required property var modelData

                        width: ListView.view.width
                        height: 34
                        radius: 9
                        color: win.chosen === modelData.path ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.text, rowArea.containsMouse ? 0.07 : 0)

                        Icon {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            name: parent.modelData.dir ? "folder" : "note"
                            size: 15
                            color: parent.modelData.dir ? Theme.accent : Theme.muted
                        }
                        Label {
                            x: 34
                            width: parent.width - 44
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.name
                            size: 13
                            elide: Text.ElideMiddle
                        }
                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.chosen = parent.modelData.path
                            onDoubleClicked: {
                                if (parent.modelData.dir)
                                    win.open(parent.modelData.path);
                            }
                        }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    visible: win.entries.length === 0
                    text: win.loadingFolder ? Tr.t("Loading…") : win.snapshots.length === 0 ? Tr.t("No backups yet") : Tr.t("This folder is not in this backup")
                    color: Theme.muted
                }
                PillButton {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: win.busy ? Tr.t("Restoring…") : Tr.t("Restore a copy")
                    icon: "history"
                    accent: win.chosen !== ""
                    enabledLook: win.chosen !== "" && !win.busy
                    onClicked: {
                        if (!enabledLook)
                            return;
                        win.busy = true;
                        restorer.exec([Ui.binDir + "niri-desk-timemachine", "restore", win.snapshot, win.chosen]);
                    }
                }
            }
        }
    }
}
