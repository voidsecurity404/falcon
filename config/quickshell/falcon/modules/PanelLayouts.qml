import QtQuick
import qs.components
import qs.services

// Top of the Panel page: the four panel designs as cards. Each card plays, on a small copy of the
// desktop, how its panel looks and how its dashboard and control center open, so the difference is
// seen before choosing. A click switches the whole panel at once.
Column {
    id: root

    readonly property string chosen: Settings.layout
    readonly property var layouts: [
        {
            id: "falcon",
            name: Tr.t("Falcon"),
            sub: Tr.t("Three parts at the edge. The dashboard drops out of the clock island")
        },
        {
            id: "halo",
            name: Tr.t("Halo"),
            sub: Tr.t("One floating capsule that turns into the dashboard and the control center")
        },
        {
            id: "rail",
            name: Tr.t("Rail"),
            sub: Tr.t("A column on the left. Panels slide out of it like drawers")
        },
        {
            id: "studio",
            name: Tr.t("Studio"),
            sub: Tr.t("The focused window's title. A dashboard in the middle, controls along the right edge")
        }
    ]

    // One clock for all cards, only while the page is seen.
    property real clock: 0
    readonly property bool live: visible && Ui.settingsOpen

    spacing: 12

    // Glass in the small: translucent with a light edge.
    component Glass: Rectangle {
        color: Qt.alpha(Theme.glassBase, 0.72)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.16)
    }
    component Line: Rectangle {
        height: 3
        radius: 1.5
        color: Qt.alpha(Theme.text, 0.75)
    }
    component Dot: Rectangle {
        width: 5
        height: 5
        radius: 2.5
        color: Qt.alpha(Theme.text, 0.6)
    }

    FrameAnimation {
        running: root.live
        onTriggered: root.clock += frameTime
    }

    // 0 closed, 1 open: rests, opens with a little overshoot, holds, closes.
    function phase(offset, length) {
        const t = ((root.clock + offset) % length) / length;
        if (t < 0.18)
            return 0;
        if (t < 0.4) {
            const u = (t - 0.18) / 0.22;
            const back = 1.5;
            const v = u - 1;
            return 1 + (back + 1) * v * v * v + back * v * v;
        }
        if (t < 0.78)
            return 1;
        const u = Math.min(1, (t - 0.78) / 0.14);
        return 1 - u * u * (3 - 2 * u);
    }

    Grid {
        id: grid

        width: root.width
        columns: 2
        spacing: 12

        Repeater {
            model: root.layouts

            delegate: Rectangle {
                id: card

                required property var modelData
                required property int index
                readonly property bool on: root.chosen === modelData.id
                // Two panels take turns in each loop: the dashboard, then the control center.
                readonly property real dash: root.phase(index * 0.7, 6.4)
                readonly property real ctrl: root.phase(index * 0.7 + 3.2, 6.4)

                width: (grid.width - grid.spacing) / 2
                height: 236
                radius: 20
                color: on ? Qt.alpha(Theme.accent, 0.16) : Qt.alpha(Theme.text, cardArea.containsMouse ? 0.07 : 0.04)
                border.width: on ? 2 : 1
                border.color: on ? Theme.accent : Qt.alpha(Theme.text, 0.08)
                scale: cardArea.pressed ? 0.98 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }

                // ------------------------------------------------ the small desktop
                Rectangle {
                    id: screen

                    x: 10
                    y: 10
                    width: parent.width - 20
                    height: 156
                    radius: 12
                    clip: true
                    color: Theme.glassBase

                    Image {
                        anchors.fill: parent
                        source: Wallpapers.shownImage === "" ? "" : "file://" + Wallpapers.shownImage
                        sourceSize.width: 480
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: 0.85
                    }

                    // ---------------- falcon
                    Item {
                        anchors.fill: parent
                        visible: card.modelData.id === "falcon"

                        Glass {
                            x: 6
                            y: 6
                            width: 40
                            height: 14
                            radius: 5

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                Rectangle {
                                    width: 9
                                    height: 7
                                    radius: 3
                                    color: Theme.accent
                                }
                                Dot {}
                                Dot {}
                            }
                        }
                        Glass {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            y: 6
                            width: 52
                            height: 14
                            radius: 5

                            Line {
                                anchors.centerIn: parent
                                width: 30
                            }
                        }
                        // The island joined to the edge grows into the dashboard.
                        Glass {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: -1
                            width: 56 + 200 * card.dash
                            height: 17 + 100 * card.dash
                            bottomLeftRadius: 6 + 6 * card.dash
                            bottomRightRadius: 6 + 6 * card.dash

                            Line {
                                anchors.centerIn: parent
                                width: 24
                                opacity: 1 - card.dash * 2
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                opacity: Math.max(0, card.dash * 2 - 1)

                                Repeater {
                                    model: 4

                                    Rectangle {
                                        width: 36
                                        height: 50
                                        radius: 5
                                        color: Qt.alpha(Theme.accent, 0.35)
                                    }
                                }
                            }
                        }
                        // The control center drops from the right part.
                        Glass {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            y: 24
                            width: 84
                            height: 100 * card.ctrl
                            radius: 8
                            visible: height > 1
                        }
                    }

                    // ---------------- halo
                    Item {
                        anchors.fill: parent
                        visible: card.modelData.id === "halo"

                        // One capsule: it becomes the dashboard, then the control center.
                        Glass {
                            readonly property real d: card.dash
                            readonly property real c: card.ctrl

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            width: 130 + 140 * d - 40 * c
                            height: 15 + 110 * d + 104 * c
                            radius: 7.5 + 5 * Math.max(d, c)

                            Row {
                                anchors.centerIn: parent
                                spacing: 7
                                opacity: 1 - Math.max(card.dash, card.ctrl) * 3

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Rectangle {
                                        width: 11
                                        height: 7
                                        radius: 3.5
                                        color: Theme.accent
                                    }
                                    Dot {}
                                    Dot {}
                                }
                                Rectangle {
                                    width: 1
                                    height: 8
                                    color: Qt.alpha(Theme.text, 0.3)
                                }
                                Line {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26
                                }
                                Rectangle {
                                    width: 1
                                    height: 8
                                    color: Qt.alpha(Theme.text, 0.3)
                                }
                                Line {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22
                                    opacity: 0.6
                                }
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                opacity: Math.max(0, card.dash * 2 - 1)

                                Repeater {
                                    model: 4

                                    Rectangle {
                                        width: 44
                                        height: 58
                                        radius: 5
                                        color: Qt.alpha(Theme.accent, 0.35)
                                    }
                                }
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                opacity: Math.max(0, card.ctrl * 2 - 1)

                                Repeater {
                                    model: 4

                                    Rectangle {
                                        width: 66
                                        height: 16
                                        radius: 5
                                        color: Qt.alpha(index === 0 ? Theme.accent : Theme.text, index === 0 ? 0.45 : 0.16)
                                    }
                                }
                            }
                        }
                    }

                    // ---------------- rail
                    Item {
                        anchors.fill: parent
                        visible: card.modelData.id === "rail"

                        Glass {
                            id: miniRail

                            x: 5
                            y: 5
                            width: 16
                            height: parent.height - 10
                            radius: 6

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 5
                                spacing: 4

                                Rectangle {
                                    width: 8
                                    height: 9
                                    radius: 3
                                    color: Theme.accent
                                }
                                Dot {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Dot {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Line {
                                    width: 8
                                    color: Theme.accent
                                }
                                Line {
                                    width: 8
                                }
                            }
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 5
                                spacing: 3

                                Dot {}
                                Dot {}
                                Dot {}
                            }
                        }
                        // The dashboard slides out of the rail as a drawer.
                        Glass {
                            x: miniRail.x + miniRail.width + 4 - (1 - card.dash) * 24
                            y: 5
                            width: 230 * card.dash
                            height: 112
                            radius: 8
                            opacity: Math.min(1, card.dash * 3)
                            visible: width > 1
                        }
                        // The control center comes up beside the rail's status.
                        Glass {
                            x: miniRail.x + miniRail.width + 4 - (1 - card.ctrl) * 16
                            y: parent.height - 5 - height
                            width: 84
                            height: 104 * card.ctrl
                            radius: 8
                            visible: height > 1
                        }
                    }

                    // ---------------- studio
                    Item {
                        anchors.fill: parent
                        visible: card.modelData.id === "studio"

                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: 0.35 * Math.max(0, Math.min(1, card.dash))
                        }
                        Glass {
                            x: 6
                            y: 6
                            width: 74
                            height: 14
                            radius: 5

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 5
                                spacing: 4

                                Rectangle {
                                    width: 9
                                    height: 7
                                    radius: 3
                                    color: Theme.accent
                                }
                                Dot {}
                                Rectangle {
                                    width: 1
                                    height: 7
                                    color: Qt.alpha(Theme.text, 0.3)
                                }
                                Line {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32
                                    opacity: 0.6
                                }
                            }
                        }
                        Glass {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            y: 6
                            width: 44
                            height: 14
                            radius: 5

                            Line {
                                anchors.centerIn: parent
                                width: 26
                            }
                        }
                        // The clock capsule flies into the middle and grows into the dashboard.
                        Glass {
                            readonly property real d: card.dash

                            x: (parent.width - 50) / 2 * (1 - d) + (parent.width - 230) / 2 * d
                            y: 6 * (1 - d) + (parent.height - 110) / 2 * d
                            width: 50 + 180 * d
                            height: 14 + 96 * d
                            radius: 7 + 3 * d

                            Line {
                                anchors.centerIn: parent
                                width: 24
                                opacity: 1 - card.dash * 3
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                opacity: Math.max(0, card.dash * 2 - 1)

                                Repeater {
                                    model: 4

                                    Rectangle {
                                        width: 38
                                        height: 52
                                        radius: 5
                                        color: Qt.alpha(Theme.accent, 0.35)
                                    }
                                }
                            }
                        }
                        // The control sidebar slides in along the right edge.
                        Glass {
                            x: parent.width - 6 - width + (1 - card.ctrl) * (width + 10)
                            y: 24
                            width: 70
                            height: parent.height - 30
                            radius: 8
                            visible: card.ctrl > 0.001

                            Column {
                                x: 6
                                y: 6
                                spacing: 4

                                Repeater {
                                    model: 7

                                    Rectangle {
                                        width: 58
                                        height: index < 3 ? 12 : 9
                                        radius: 3
                                        color: Qt.alpha(index === 0 ? Theme.accent : Theme.text, index === 0 ? 0.45 : 0.14)
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    x: 16
                    y: screen.y + screen.height + 10
                    width: parent.width - 32
                    spacing: 3

                    Row {
                        spacing: 7

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: card.on
                            name: "check"
                            size: 15
                            color: Theme.accent
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.name
                            size: 15
                            font.weight: Font.DemiBold
                        }
                    }
                    Label {
                        width: parent.width
                        text: card.modelData.sub
                        color: Theme.muted
                        size: 12
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: cardArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.set("panel.layout", card.modelData.id)
                }
            }
        }
    }
}
