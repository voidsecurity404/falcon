import QtQuick
import Quickshell
import qs.services

// Har bir dastur uchun o'z qoidasi: suzib ochilsin, kengligi, shaffofligi va hokazo.
// Each card is one entry of windows.rules; its rows are ordinary SettingRows on keys such as
// windows.rules.2.width, so they look and save like every other setting.
Column {
    id: root

    readonly property var rules: Settings.get("windows.rules", [])

    // App ids of the windows open now, for picking instead of typing a regex.
    readonly property var openApps: {
        const seen = [];
        for (const key in Niri.windows) {
            const app = Niri.windows[key].app_id;
            if (app && app !== "org.quickshell" && seen.indexOf(app) < 0)
                seen.push(app);
        }
        return seen.sort();
    }

    spacing: 10

    function exact(app) {
        return "^" + app.replace(/[.+*?^$()[\]{}|\\]/g, "\\$&") + "$";
    }

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
        Settings.set("windows.rules", rules.concat([
            {
                app: last ? exact(last) : "",
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
        text: Tr.t("A rule applies when a window opens. Pick an open app or type a regex for its name or title. Rules lower in the list win.")
        color: Theme.muted
        size: 13
    }

    Repeater {
        model: root.rules

        delegate: Rectangle {
            id: card

            required property var modelData
            required property int index

            property bool more: false
            readonly property string base: "windows.rules." + index + "."

            width: root.width
            height: cardColumn.implicitHeight + 28
            radius: 18
            color: Qt.alpha(Theme.text, 0.045)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.06)

            Column {
                id: cardColumn

                x: 16
                y: 14
                width: parent.width - 32
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
                            width: 96
                            text: field.modelData.label
                            color: Theme.muted
                            size: 13
                        }
                        Rectangle {
                            width: cardColumn.width - 104
                            height: 30
                            radius: 9
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

                // Open apps: a press puts the exact name in.
                Flow {
                    visible: root.openApps.length > 0
                    x: 104
                    width: parent.width - 104
                    spacing: 5

                    Repeater {
                        model: root.openApps.slice(0, 14)

                        delegate: Rectangle {
                            id: appChip

                            required property string modelData

                            readonly property bool on: card.modelData.app === root.exact(modelData)

                            width: appLabel.implicitWidth + 14
                            height: 24
                            radius: 8
                            color: on ? Qt.alpha(Theme.accent, 0.24) : Qt.alpha(Theme.text, appArea.containsMouse ? 0.1 : 0.05)

                            Label {
                                id: appLabel

                                anchors.centerIn: parent
                                text: appChip.modelData
                                color: appChip.on ? Theme.accent : Theme.muted
                                font.family: Theme.mono
                                size: 11
                            }
                            MouseArea {
                                id: appArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.change(card.index, "app", root.exact(appChip.modelData))
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
                            { key: "tiled", label: Tr.t("Tiled") },
                            { key: "maximized", label: Tr.t("Wide") },
                            { key: "fullscreen", label: Tr.t("Fullscreen") },
                            { key: "noFocus", label: Tr.t("No focus") },
                            { key: "sticky", label: Tr.t("On every workspace"), native: true },
                            { key: "hideFromCapture", label: Tr.t("Hide from recordings") },
                            { key: "hideFromShare", label: Tr.t("Hide from screen sharing") }
                        ].filter(f => !f.native || Sticky.nativeSticky || card.modelData[f.key] === true)

                        delegate: Rectangle {
                            id: flag

                            required property var modelData

                            readonly property bool on: card.modelData[modelData.key] === true

                            width: flagLabel.implicitWidth + 16
                            height: 28
                            radius: 9
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
                                onClicked: {
                                    // Floating and tiled exclude each other.
                                    const key = flag.modelData.key;
                                    const next = JSON.parse(JSON.stringify(root.rules));
                                    next[card.index][key] = !flag.on;
                                    if (!flag.on && key === "floating")
                                        next[card.index].tiled = false;
                                    if (!flag.on && key === "tiled")
                                        next[card.index].floating = false;
                                    Settings.set("windows.rules", next);
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width

                    Repeater {
                        model: [
                            {
                                key: card.base + "width",
                                label: Tr.t("Width"),
                                type: "choice",
                                fallback: 0,
                                options: [0, 0.33333, 0.5, 0.66667, 1],
                                names: [Tr.t("Default"), "1/3", "1/2", "2/3", Tr.t("Full")]
                            },
                            {
                                key: card.base + "height",
                                label: Tr.t("Height"),
                                type: "choice",
                                fallback: 0,
                                options: [0, 0.33333, 0.5, 0.66667, 1],
                                names: [Tr.t("Default"), "1/3", "1/2", "2/3", Tr.t("Full")]
                            },
                            {
                                key: card.base + "position",
                                label: Tr.t("Place when floating"),
                                type: "choice",
                                layout: "chips",
                                fallback: "center",
                                options: ["center", "top-left", "top", "top-right", "bottom-left", "bottom", "bottom-right"],
                                names: [Tr.t("Center"), Tr.t("Top left"), Tr.t("Top"), Tr.t("Top right"), Tr.t("Bottom left"), Tr.t("Bottom"), Tr.t("Bottom right")],
                                show: card.modelData.floating === true
                            },
                            {
                                key: card.base + "opacity",
                                label: Tr.t("Opacity"),
                                type: "slider",
                                fallback: 1,
                                min: 0.2,
                                max: 1,
                                step: 0.02,
                                unit: "percent"
                            },
                            {
                                key: card.base + "radius",
                                label: Tr.t("Corner radius"),
                                type: "slider",
                                fallback: Settings.get("windows.radius", 13),
                                min: 0,
                                max: 32,
                                step: 1,
                                unit: "px",
                                show: card.more
                            },
                            {
                                key: card.base + "output",
                                label: Tr.t("Open on monitor"),
                                type: "choice",
                                fallback: "",
                                options: [""].concat(Quickshell.screens.map(s => s.name)),
                                names: [Tr.t("Any")].concat(Quickshell.screens.map(s => s.name)),
                                show: card.more
                            },
                            {
                                key: card.base + "minWidth",
                                label: Tr.t("Smallest width"),
                                hint: Tr.t("Pixels, empty for no limit"),
                                type: "number",
                                width: 110,
                                show: card.more
                            },
                            {
                                key: card.base + "maxWidth",
                                label: Tr.t("Largest width"),
                                hint: Tr.t("Pixels, empty for no limit"),
                                type: "number",
                                width: 110,
                                show: card.more
                            },
                            {
                                key: card.base + "minHeight",
                                label: Tr.t("Smallest height"),
                                hint: Tr.t("Pixels, empty for no limit"),
                                type: "number",
                                width: 110,
                                show: card.more
                            },
                            {
                                key: card.base + "maxHeight",
                                label: Tr.t("Largest height"),
                                hint: Tr.t("Pixels, empty for no limit"),
                                type: "number",
                                width: 110,
                                show: card.more
                            }
                        ].filter(r => r.show !== false)

                        delegate: SettingRow {
                            required property var modelData

                            width: cardColumn.width
                            item: modelData
                        }
                    }
                }

                Row {
                    spacing: 6

                    Rectangle {
                        width: moreLabel.implicitWidth + 24
                        height: 28
                        radius: 9
                        color: Qt.alpha(Theme.text, moreArea.containsMouse ? 0.1 : 0.07)

                        Label {
                            id: moreLabel

                            anchors.centerIn: parent
                            text: card.more ? Tr.t("Fewer options") : Tr.t("More options")
                            size: 13
                        }
                        MouseArea {
                            id: moreArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.more = !card.more
                        }
                    }

                    Rectangle {
                        width: deleteLabel.implicitWidth + 24
                        height: 28
                        radius: 9
                        color: Qt.alpha(Theme.error, 0.2)

                        Label {
                            id: deleteLabel

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
        width: addLabel.implicitWidth + 36
        height: 36
        radius: 11
        color: Theme.accent

        Label {
            id: addLabel

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
