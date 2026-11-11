import QtQuick
import Quickshell
import qs.components
import qs.services

// The macos layout's apple menu: about, settings, the app store, then sleep, restart, shut
// down, lock and log out. Restart, shut down and log out ask first through the power menu, as
// macOS asks before them. It drops from under the apple with a quick fade.
Rectangle {
    id: root

    property bool shown: false
    property real t: 0
    readonly property var items: [
        {
            name: Tr.t("About this computer"),
            run: () => {
                Ui.settingsPage = 16;
                Ui.settingsOpen = true;
            }
        },
        null,
        {
            name: Tr.t("System Settings…"),
            run: () => Ui.settingsOpen = true
        },
        {
            name: Tr.t("App Store…"),
            run: () => Quickshell.execDetached([Ui.binDir + "archmarket"])
        },
        {
            name: Tr.t("Wallpapers…"),
            run: () => Ui.popup = "wallpapers",
            keepOpen: true
        },
        null,
        {
            name: Tr.t("Sleep"),
            run: () => Quickshell.execDetached(["systemctl", "suspend"])
        },
        {
            name: Tr.t("Restart…"),
            run: () => Ui.popup = "power",
            keepOpen: true
        },
        {
            name: Tr.t("Shut Down…"),
            run: () => Ui.popup = "power",
            keepOpen: true
        },
        null,
        {
            name: Tr.t("Lock Screen"),
            run: () => Quickshell.execDetached(["loginctl", "lock-session"])
        },
        {
            name: Tr.t("Log Out…"),
            run: () => Ui.popup = "power",
            keepOpen: true
        }
    ]

    onShownChanged: {
        fade.stop();
        fade.to = shown ? 1 : 0;
        fade.duration = shown ? 160 : 200;
        fade.start();
    }

    NumberAnimation {
        id: fade

        target: root
        property: "t"
        easing.type: Easing.OutCubic
    }

    width: 250
    height: list.implicitHeight + 12
    radius: 10
    visible: t > 0.001
    opacity: t
    color: Qt.alpha(Theme.glassBase, Math.max(0.7, Theme.glassOpacity))
    border.width: 1
    border.color: Qt.alpha(Theme.text, 0.18)

    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: list

        x: 6
        y: 6
        width: parent.width - 12

        Repeater {
            model: root.items

            delegate: Item {
                id: entry

                required property var modelData

                width: list.width
                height: modelData ? 26 : 11

                Rectangle {
                    visible: !entry.modelData
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    color: Qt.alpha(Theme.text, 0.14)
                }
                Rectangle {
                    visible: !!entry.modelData
                    anchors.fill: parent
                    radius: 5
                    color: entryArea.containsMouse ? Theme.accent : "transparent"

                    Label {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData ? entry.modelData.name : ""
                        size: 13
                        color: entryArea.containsMouse ? Theme.accentText : Theme.text
                    }
                    MouseArea {
                        id: entryArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const item = entry.modelData;
                            if (!item.keepOpen)
                                Ui.popup = "";
                            item.run();
                        }
                    }
                }
            }
        }
    }
}
