import QtQuick
import qs.services

// Har bir dastur uchun o'z qoidasi: suzib ochilsin, kengligi, shaffofligi va hokazo.
Column {
    id: root

    readonly property var rules: Settings.get("windows.rules", [])

    spacing: 10

    function change(index, key, value) {
        const next = JSON.parse(JSON.stringify(rules));
        next[index][key] = value;
        Settings.set("windows.rules", next);
    }

    function remove(index) {
        const next = JSON.parse(JSON.stringify(rules));
        next.splice(index, 1);
        Settings.set("windows.rules", next);
    }

    function add() {
        // Sozlamalar oynasi fokusda turadi, shuning uchun undan oldingi dastur olinadi.
        const last = Niri.lastAppId;
        const app = last ? "^" + last.replace(/[.+*?^$()[\]{}|\\]/g, "\\$&") + "$" : "";
        Settings.set("windows.rules", rules.concat([
            {
                app: app,
                title: "",
                floating: false,
                maximized: false,
                noFocus: false,
                hideFromCapture: false,
                opacity: 1
            }
        ]));
    }

    Label {
        width: parent.width
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        text: Tr.t("A rule applies when a window opens. The app name is a regex. To list windows: niri msg windows.")
        color: Theme.muted
        size: 13
    }

    Repeater {
        model: root.rules

        delegate: Rectangle {
            id: card

            required property var modelData
            required property int index

            width: root.width
            height: cardColumn.implicitHeight + 24
            radius: 11
            color: Qt.alpha(Theme.text, 0.05)

            Column {
                id: cardColumn

                x: 12
                y: 12
                width: parent.width - 24
                spacing: 8

                Repeater {
                    model: [
                        { key: "app", label: Tr.t("App") },
                        { key: "title", label: Tr.t("Title") }
                    ]

                    delegate: Row {
                        id: field

                        required property var modelData

                        spacing: 8

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 70
                            text: field.modelData.label
                            color: Theme.muted
                            size: 13
                        }
                        Rectangle {
                            width: cardColumn.width - 78
                            height: 30
                            radius: 7
                            color: Qt.alpha(Theme.text, 0.07)

                            TextInput {
                                anchors.fill: parent
                                leftPadding: 9
                                rightPadding: 9
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                color: Theme.text
                                font.family: Theme.mono
                                font.pixelSize: 13
                                text: card.modelData[field.modelData.key] || ""
                                onEditingFinished: {
                                    if (text !== (card.modelData[field.modelData.key] || ""))
                                        root.change(card.index, field.modelData.key, text);
                                }
                            }
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: [
                            { key: "floating", label: Tr.t("Floating") },
                            { key: "maximized", label: Tr.t("Wide") },
                            { key: "fullscreen", label: Tr.t("Fullscreen") },
                            { key: "noFocus", label: Tr.t("No focus") },
                            { key: "hideFromCapture", label: Tr.t("Hide from recordings") }
                        ]

                        delegate: Rectangle {
                            id: flag

                            required property var modelData

                            readonly property bool on: card.modelData[modelData.key] === true

                            width: flagLabel.implicitWidth + 16
                            height: 28
                            radius: 7
                            color: on ? Qt.alpha(Theme.accent, 0.24) : Qt.alpha(Theme.text, 0.07)

                            Label {
                                id: flagLabel

                                anchors.centerIn: parent
                                text: flag.modelData.label
                                color: flag.on ? Theme.accent : Theme.text
                                size: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.change(card.index, flag.modelData.key, !flag.on)
                            }
                        }
                    }

                    Rectangle {
                        width: 74
                        height: 28
                        radius: 7
                        color: Qt.alpha(Theme.error, 0.2)

                        Label {
                            anchors.centerIn: parent
                            text: Tr.t("Delete")
                            color: Theme.error
                            size: 13
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.remove(card.index)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        width: 190
        height: 34
        radius: 9
        color: Theme.accent

        Label {
            anchors.centerIn: parent
            text: Tr.t("Add a rule")
            color: Theme.accentText
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.add()
        }
    }
}
