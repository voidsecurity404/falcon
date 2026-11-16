import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Settings → Notifications: one row per app that sent something (or has a choice), with how its
// notifications arrive: shown, quietly into the history, important (through Silent and focus
// mode), or not at all. Stored in `notifications.apps` by Toasts.setAppMode().
Rectangle {
    id: root

    readonly property var modes: [
        { id: "show", name: Tr.t("Show") },
        { id: "quiet", name: Tr.t("Quietly") },
        { id: "important", name: Tr.t("Important") },
        { id: "off", name: Tr.t("Off") }
    ]

    // Notifications carry a display name ("Telegram Desktop"), not a desktop file id.
    function entryOf(app) {
        const key = (app || "").toLowerCase();
        const list = DesktopEntries.applications.values;
        const squeezed = key.replace(/\s+/g, "");
        return list.find(e => (e.name || "").toLowerCase() === key)
            || DesktopEntries.heuristicLookup(app)
            || list.find(e => (e.id || "").toLowerCase().indexOf(squeezed) >= 0)
            || list.find(e => e.name && key.indexOf(e.name.toLowerCase()) === 0)
            || null;
    }

    implicitHeight: body.implicitHeight + 32
    radius: 18
    color: Qt.alpha(Theme.text, 0.05)
    border.width: 1
    border.color: Qt.alpha(Theme.text, 0.06)

    Column {
        id: body

        x: 18
        y: 16
        width: parent.width - 36
        spacing: 12

        Column {
            width: parent.width
            spacing: 3

            Label {
                text: Tr.t("Apps")
                size: 14
                font.weight: Font.DemiBold
            }
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: Toasts.knownApps.length === 0 ? Tr.t("Apps appear here after their first notification.") : Tr.t("Quietly: only into the history. Important: a card even in Silent and focus mode. Off: not shown and not kept. Urgent ones always show.")
                color: Theme.muted
                size: 12
            }
        }

        Repeater {
            model: Toasts.knownApps

            delegate: Item {
                id: row

                required property string modelData
                readonly property string mode: Toasts.appMode(modelData)
                readonly property var entry: root.entryOf(modelData)

                width: body.width
                height: 44

                Rectangle {
                    id: badge

                    width: 34
                    height: 34
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(Theme.text, 0.07)

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 22
                        visible: !!row.entry && row.entry.icon !== ""
                        source: row.entry ? Quickshell.iconPath(row.entry.icon, true) : ""
                        opacity: row.mode === "off" ? 0.4 : 1
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !row.entry || row.entry.icon === ""
                        name: "bell"
                        size: 16
                        color: Theme.muted
                    }
                }
                Label {
                    anchors.left: badge.right
                    anchors.leftMargin: 12
                    anchors.right: choice.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.entry && row.entry.name ? row.entry.name : row.modelData
                    size: 13
                    elide: Text.ElideRight
                    color: row.mode === "off" ? Theme.muted : Theme.text
                }
                Rectangle {
                    id: choice

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: chips.implicitWidth + 6
                    height: 32
                    radius: 16
                    color: Qt.alpha(Theme.text, 0.07)

                    Row {
                        id: chips

                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: root.modes

                            delegate: Rectangle {
                                id: chip

                                required property var modelData
                                readonly property bool on: row.mode === modelData.id

                                width: chipText.implicitWidth + 22
                                height: 26
                                radius: 13
                                color: on ? (modelData.id === "off" ? Theme.error : Theme.accent) : chipArea.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 160
                                    }
                                }

                                Label {
                                    id: chipText

                                    anchors.centerIn: parent
                                    text: chip.modelData.name
                                    size: 12
                                    font.weight: chip.on ? Font.DemiBold : Font.Normal
                                    color: chip.on ? (chip.modelData.id === "off" ? "white" : Theme.accentText) : Theme.text
                                }
                                MouseArea {
                                    id: chipArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Toasts.setAppMode(row.modelData, chip.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
