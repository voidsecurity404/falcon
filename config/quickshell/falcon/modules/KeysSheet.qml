import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// Every key of the desktop on one glass sheet (Mod+Shift+/), read from niri's own files by
// bin/falcon-keys, so it always matches them. Groups flow into three columns; typing filters.
PanelWindow {
    id: root

    readonly property bool closing: Ui.popup !== "keys"
    property real reveal: 0
    property var rows: []
    property string filter: ""
    readonly property int columns: 3
    readonly property real cardWidth: Math.min(1280, (root.width || 1920) - 80)
    readonly property real cardHeight: Math.min(900, (root.height || 1080) - 80)
    readonly property real columnWidth: (cardWidth - 64 - 28 * (columns - 1)) / columns
    readonly property var groupOrder: ["Falcon", "Windows", "Workspaces", "Monitors", "Screen", "Media keys", "System", "Your keys"]

    // The shown groups, each with its rows, laid into the shortest column in turn.
    readonly property var laidOut: {
        const q = filter.trim().toLowerCase();
        const groups = [];
        for (const name of groupOrder) {
            const items = rows.filter(r => r.group === name).filter(r => {
                if (q === "")
                    return true;
                return (title(r) + " " + r.keys.join(" ") + " " + r.keys.map(pretty).join(" ")).toLowerCase().indexOf(q) >= 0;
            });
            if (items.length > 0)
                groups.push({ name: name, items: items });
        }
        const cols = [];
        const heights = [];
        for (let i = 0; i < columns; i++) {
            cols.push([]);
            heights.push(0);
        }
        for (const g of groups) {
            let shortest = 0;
            for (let i = 1; i < columns; i++)
                if (heights[i] < heights[shortest] - 1)
                    shortest = i;
            cols[shortest].push(g);
            heights[shortest] += 52 + g.items.length * 34;
        }
        return cols;
    }

    function title(row) {
        return row.translated ? row.title : Tr.t(row.title);
    }

    // niri's key names, as printed on the keycaps.
    function pretty(key) {
        return key.split("+").map(part => names[part] || part).join("+");
    }
    readonly property var names: ({
            Mod: "Super",
            Return: "Enter",
            Grave: "`",
            Comma: ",",
            Slash: "/",
            Minus: "−",
            Equal: "=",
            BracketLeft: "[",
            BracketRight: "]",
            Print: "PrtSc",
            Escape: "Esc",
            Delete: "Del",
            Left: "←",
            Right: "→",
            Up: "↑",
            Down: "↓"
        })
    // Media keys show their picture instead of a name.
    readonly property var icons: ({
            XF86AudioRaiseVolume: "volume",
            XF86AudioLowerVolume: "volume",
            XF86AudioMute: "mute",
            XF86AudioMicMute: "micOff",
            XF86AudioPlay: "play",
            XF86AudioPrev: "previous",
            XF86AudioNext: "next",
            XF86MonBrightnessUp: "sun",
            XF86MonBrightnessDown: "sun"
        })

    readonly property var iconSigns: ({
            XF86AudioRaiseVolume: "+",
            XF86AudioLowerVolume: "−",
            XF86MonBrightnessUp: "+",
            XF86MonBrightnessDown: "−"
        })

    onClosingChanged: {
        revealAnimation.stop();
        if (closing) {
            revealAnimation.to = 0;
            revealAnimation.duration = 200;
            revealAnimation.easing.type = Easing.InCubic;
        } else {
            alive = true;
            filter = "";
            search.text = "";
            load.running = true;
            search.forceActiveFocus();
            revealAnimation.to = 1;
            revealAnimation.duration = 380;
            revealAnimation.easing.type = Easing.OutCubic;
        }
        revealAnimation.start();
    }

    property bool alive: false

    NumberAnimation {
        id: revealAnimation

        target: root
        property: "reveal"
        onFinished: {
            if (root.closing)
                root.alive = false;
        }
    }

    Process {
        id: load

        command: [Ui.binDir + "falcon-keys"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.rows = JSON.parse(text);
                } catch (e) {
                    root.rows = [];
                }
            }
        }
    }

    visible: alive
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "falcon-keys"
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    mask: Region {
        item: catcher
    }
    BackgroundEffect.blurRegion: Region {
        item: card
        radius: card.radius
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45 * root.reveal
    }
    MouseArea {
        id: catcher

        width: root.closing ? 0 : parent.width
        height: root.closing ? 0 : parent.height
        onClicked: Ui.popup = ""
    }

    Rectangle {
        id: card

        width: root.cardWidth
        height: root.cardHeight
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2 + (1 - root.reveal) * 28)
        opacity: root.reveal
        radius: 32
        border.width: 1
        border.color: Theme.panelEdge
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.glassBase, Math.max(0.74, Theme.glassOpacity))
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Theme.glassBase, Math.max(0.64, Theme.glassOpacity - 0.1))
            }
        }

        // Keeps clicks on the card from closing it.
        MouseArea {
            anchors.fill: parent
        }

        Row {
            x: 32
            y: 26
            spacing: 14

            MaterialShape {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                kind: "cookie6"
                color: Theme.accent

                Icon {
                    anchors.centerIn: parent
                    name: "keyboard"
                    size: 20
                    color: Theme.accentText
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Label {
                    text: Tr.t("Keyboard shortcuts")
                    size: 22
                    font.weight: Font.DemiBold
                }
                Label {
                    text: Tr.t("Change the main ones in Settings → Shortcuts")
                    color: Theme.muted
                    size: 13
                }
            }
        }

        Rectangle {
            x: parent.width - width - 32
            y: 30
            width: 300
            height: 40
            radius: 20
            color: Qt.alpha(Theme.surface, 0.7)
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : Theme.panelEdge

            Icon {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 15
                color: Theme.muted
            }
            TextInput {
                id: search

                x: 40
                width: parent.width - 54
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: 14
                clip: true
                onTextChanged: root.filter = text
                Keys.onEscapePressed: {
                    if (text !== "")
                        text = "";
                    else
                        Ui.popup = "";
                }
            }
            Label {
                x: 40
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: Tr.t("Find a key or an action")
                color: Theme.muted
                size: 14
            }
        }

        Flickable {
            id: scroller

            x: 32
            y: 100
            width: parent.width - 64
            height: parent.height - 124
            contentHeight: columnsRow.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: columnsRow

                spacing: 28

                Repeater {
                    model: root.laidOut

                    delegate: Column {
                        id: column

                        required property var modelData
                        required property int index

                        width: root.columnWidth
                        spacing: 18

                        Repeater {
                            model: column.modelData

                            delegate: Column {
                                id: group

                                required property var modelData
                                required property int index

                                width: root.columnWidth
                                spacing: 4
                                opacity: root.reveal
                                transform: Translate {
                                    y: (1 - root.reveal) * (14 + column.index * 10 + group.index * 6)
                                }

                                Label {
                                    text: Tr.t(group.modelData.name).toUpperCase()
                                    size: 11
                                    font.letterSpacing: 2
                                    font.weight: Font.DemiBold
                                    color: Theme.accent
                                    bottomPadding: 6
                                }

                                Repeater {
                                    model: group.modelData.items

                                    delegate: Item {
                                        id: line

                                        required property var modelData

                                        width: root.columnWidth
                                        height: 30

                                        Label {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - keysRow.width - 12
                                            text: root.title(line.modelData)
                                            size: 13
                                            elide: Text.ElideRight
                                        }
                                        Row {
                                            id: keysRow

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6

                                            Repeater {
                                                // Two ways to the same action: only the first is shown, the
                                                // second is usually the arrow twin.
                                                model: line.modelData.keys.slice(0, 1)

                                                delegate: Row {
                                                    id: combo

                                                    required property string modelData

                                                    spacing: 3

                                                    Repeater {
                                                        model: combo.modelData.split("+")

                                                        delegate: Rectangle {
                                                            id: cap

                                                            required property string modelData
                                                            readonly property string icon: root.icons[modelData] || ""
                                                            readonly property string word: root.names[modelData] || modelData

                                                            readonly property string sign: root.iconSigns[modelData] || ""

                                                            width: Math.max(24, (icon !== "" ? iconRow.implicitWidth : capLabel.implicitWidth) + 14)
                                                            height: 24
                                                            radius: 7
                                                            color: Qt.alpha(Theme.text, 0.08)
                                                            border.width: 1
                                                            border.color: Qt.alpha(Theme.text, 0.14)

                                                            // The lower edge of a keycap.
                                                            Rectangle {
                                                                anchors.bottom: parent.bottom
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                                width: parent.width - 6
                                                                height: 2
                                                                radius: 1
                                                                color: Qt.alpha(Theme.text, 0.12)
                                                            }
                                                            Label {
                                                                id: capLabel

                                                                anchors.centerIn: parent
                                                                visible: cap.icon === ""
                                                                text: cap.word
                                                                size: 12
                                                                font.family: Theme.mono
                                                                font.weight: Font.Medium
                                                            }
                                                            Row {
                                                                id: iconRow

                                                                anchors.centerIn: parent
                                                                visible: cap.icon !== ""
                                                                spacing: 2

                                                                Icon {
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    name: cap.icon
                                                                    size: 14
                                                                    color: Theme.text
                                                                }
                                                                Label {
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    visible: cap.sign !== ""
                                                                    text: cap.sign
                                                                    size: 12
                                                                    font.weight: Font.DemiBold
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // The list scrolls, which nothing showed: rows were simply cut at the bottom edge.
        Rectangle {
            readonly property real track: scroller.height - 8

            x: scroller.x + scroller.width + 12
            y: scroller.y + 4 + scroller.visibleArea.yPosition * track
            width: 4
            height: Math.max(24, scroller.visibleArea.heightRatio * track)
            radius: 2
            color: Qt.alpha(Theme.text, scroller.moving ? 0.45 : 0.22)
            visible: scroller.contentHeight > scroller.height + 1

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }

        Label {
            anchors.centerIn: scroller
            visible: root.filter !== "" && root.laidOut.every(c => c.length === 0)
            text: Tr.t("Nothing found")
            color: Theme.muted
        }
    }
}
