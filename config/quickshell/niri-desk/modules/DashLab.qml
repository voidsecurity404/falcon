import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Lab: pentest nishoni, portlar, VPN, tez amallar va shu nishon qaydlari.
Item {
    id: root

    // Papka nomiga aylanadi: yo'ldan chiqib ketadigan qiymat qabul qilinmaydi.
    readonly property string target: /^[A-Za-z0-9][A-Za-z0-9.:_-]*$/.test(Settings.labTarget) ? Settings.labTarget : ""
    readonly property string base: String(Settings.get("lab.dir", "~/Pentest")).replace(/^~/, Settings.home)
    readonly property string folder: base + "/" + target.replace(/:/g, "_")
    readonly property string notesPath: folder + "/notes.md"

    function copy(text) {
        Quickshell.clipboardText = text;
        Toasts.show(Tr.t("Copied"), text, "check");
    }

    function saveNotes() {
        if (target === "" || !notes.dirty)
            return;
        Library.saveText(folder, notesPath, notes.text);
        notes.dirty = false;
    }

    FileView {
        id: notesFile

        path: root.target === "" ? "" : root.notesPath
        printErrors: false
        onLoaded: {
            notes.text = text();
            notes.dirty = false;
        }
        onLoadFailed: {
            notes.text = "";
            notes.dirty = false;
        }
    }

    Column {
        width: 370
        spacing: 7

        Row {
            spacing: 8

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("Target")
                color: Theme.muted
                size: 13
            }
            Rectangle {
                width: 220
                height: 30
                radius: 8
                color: Qt.alpha(Theme.text, 0.07)
                border.width: targetInput.activeFocus ? 1 : 0
                border.color: Theme.accent

                TextInput {
                    id: targetInput

                    anchors.fill: parent
                    leftPadding: 9
                    rightPadding: 9
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 13
                    text: root.target
                    onEditingFinished: {
                        if (/^([A-Za-z0-9][A-Za-z0-9.:_-]*)?$/.test(text) && text !== root.target) {
                            root.saveNotes();
                            Settings.set("lab.target", text);
                        }
                    }
                    Keys.onEscapePressed: Ui.popup = ""
                }
            }
            Rectangle {
                width: 70
                height: 30
                radius: 8
                color: Qt.alpha(Theme.text, copyArea.containsMouse ? 0.14 : 0.08)

                Label {
                    anchors.centerIn: parent
                    text: Tr.t("Copy")
                    size: 13
                }
                MouseArea {
                    id: copyArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.target !== "")
                            root.copy(root.target);
                    }
                }
            }
        }

        Repeater {
            model: Lab.configured ? Lab.ports : []

            delegate: Item {
                id: portRow

                required property var modelData

                width: 370
                height: 20

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ":" + portRow.modelData.port + " " + portRow.modelData.name
                    color: Theme.muted
                    font.family: Theme.mono
                    size: 13
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: portRow.modelData.open ? Tr.t("open") : Tr.t("closed")
                    color: portRow.modelData.open ? Theme.good : Theme.muted
                    font.family: Theme.mono
                    size: 13
                }
            }
        }

        Item {
            width: 370
            height: 20

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "vpn " + Settings.vpnInterface
                color: Theme.muted
                font.family: Theme.mono
                size: 13
            }
            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Lab.vpnAddress || Tr.t("off")
                color: Lab.vpnAddress ? Theme.good : Theme.text
                font.family: Theme.mono
                size: 13
            }
            MouseArea {
                anchors.fill: parent
                enabled: Lab.vpnAddress !== ""
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copy(Lab.vpnAddress)
            }
        }

        Item {
            width: 1
            height: 4
        }

        Flow {
            width: 370
            spacing: 5

            Repeater {
                model: [
                    {
                        text: Tr.t("Quick scan"),
                        run: () => {
                            Ui.popup = "";
                            Quickshell.execDetached(["kitty", "sh", "-c", 'nmap -sC -sV "$1"\necho; printf "' + Tr.t("Press Enter to close") + '"; read _', "sh", root.target]);
                        }
                    },
                    {
                        text: Tr.t("Folder"),
                        run: () => {
                            Ui.popup = "";
                            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", root.folder]);
                        }
                    },
                    {
                        text: Settings.get("lab.evidence", false) ? Tr.t("Evidence: on") : Tr.t("Evidence: off"),
                        run: () => Settings.set("lab.evidence", !Settings.get("lab.evidence", false))
                    }
                ]

                delegate: Rectangle {
                    id: labButton

                    required property var modelData

                    width: labLabel.implicitWidth + 20
                    height: 28
                    radius: 8
                    color: Qt.alpha(Theme.text, labArea.containsMouse ? 0.14 : 0.08)

                    Label {
                        id: labLabel

                        anchors.centerIn: parent
                        text: labButton.modelData.text
                        size: 13
                    }
                    MouseArea {
                        id: labArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.target !== "")
                                labButton.modelData.run();
                        }
                    }
                }
            }
        }
    }

    // Qaydlar: nishon papkasida saqlanadi
    Rectangle {
        anchors.right: parent.right
        width: 400
        height: parent.height
        radius: 13
        color: Qt.alpha(Theme.text, 0.05)

        Label {
            x: 14
            y: 10
            text: Tr.t("Notes, found credentials")
            color: Theme.muted
            size: 13
        }

        Flickable {
            id: notesView

            x: 14
            y: 34
            width: parent.width - 28
            height: parent.height - 44
            contentHeight: notes.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: notes

                property bool dirty: false

                width: parent.width
                // Bo'sh joyni bosganda ham yozish boshlanadi.
                height: Math.max(implicitHeight, notesView.height)
                wrapMode: TextEdit.Wrap
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.family: Theme.mono
                font.pixelSize: 13
                selectByMouse: true
                readOnly: root.target === ""
                onTextChanged: {
                    if (activeFocus) {
                        dirty = true;
                        saveTimer.restart();
                    }
                }
                Keys.onTabPressed: Ui.nextDashTab(1)
                Keys.onBacktabPressed: Ui.nextDashTab(-1)
                Keys.onEscapePressed: {
                    root.saveNotes();
                    Ui.popup = "";
                }
            }
        }

        Timer {
            id: saveTimer

            interval: 800
            onTriggered: root.saveNotes()
        }

        Label {
            anchors.centerIn: parent
            visible: root.target === ""
            text: Tr.t("Enter a target first")
            color: Theme.muted
        }
    }

    Component.onDestruction: saveNotes()
}
