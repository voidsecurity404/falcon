import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// The menu of "Add widget": every widget live on a piece of the current wallpaper. A click adds it.
Item {
    id: root

    property int bottomSpace: 80
    readonly property alias panel: panel
    readonly property bool open: Widgets.galleryOpen
    readonly property var shown: {
        const list = Widgets.catalog.filter(c => c.group === Widgets.galleryGroup);
        return list.length > 0 ? list : Widgets.catalog;
    }
    // Stays on until the closing fade has ended, then the previews are destroyed.
    readonly property bool alive: open || panel.opacity > 0

    visible: alive

    function count(type) {
        return Widgets.items.filter(w => w.type === type).length;
    }

    // A click beside the menu closes it.
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.pill, 0.35)
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: Widgets.galleryOpen = false
        }
    }

    Rectangle {
        id: panel

        readonly property real rest: Math.max(30, (root.height - root.bottomSpace - height) / 2)

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.open ? rest : rest + 26
        width: Math.min(root.width - 60, 1200)
        height: Math.min(root.height - root.bottomSpace - 60, 800)
        radius: 26
        color: Qt.alpha(Theme.glassBase, 0.86)
        border.width: 1
        border.color: Theme.panelEdge
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 170
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onWheel: wheel => wheel.accepted = true
        }

        Label {
            id: heading

            x: 28
            y: 22
            text: Tr.t("Add widget")
            size: 22
            font.weight: Font.DemiBold
        }
        Label {
            anchors.left: heading.right
            anchors.leftMargin: 12
            anchors.baseline: heading.baseline
            text: Tr.t("Press a widget to put it on the desktop")
            color: Theme.muted
            size: 13
        }

        Row {
            id: chips

            x: 26
            y: 64
            spacing: 6

            Repeater {
                model: Widgets.groups

                delegate: Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool current: Widgets.galleryGroup === modelData.id

                    width: chipLabel.implicitWidth + 26
                    height: 32
                    radius: 16
                    color: current ? Theme.accent : Qt.alpha(Theme.text, chipArea.containsMouse ? 0.14 : 0.07)

                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }

                    Label {
                        id: chipLabel

                        anchors.centerIn: parent
                        text: chip.modelData.title
                        color: chip.current ? Theme.accentText : Theme.text
                        size: 13
                        font.weight: chip.current ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Widgets.galleryGroup = chip.modelData.id;
                            grid.contentY = grid.originY;
                        }
                    }
                }
            }
        }

        GridView {
            id: grid

            x: 22
            y: 108
            width: parent.width - 44 + 4
            height: parent.height - y - 14
            clip: true
            cellWidth: Math.floor(width / 3)
            cellHeight: Math.round((cellWidth - 10) * 0.62) + 56
            cacheBuffer: 500
            boundsBehavior: Flickable.StopAtBounds
            model: root.alive ? root.shown : []

            delegate: Item {
                id: cell

                required property var modelData

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    id: card

                    anchors.fill: parent
                    anchors.margins: 5
                    radius: 18
                    color: Qt.alpha(Theme.text, cardArea.containsMouse ? 0.1 : 0.05)
                    border.width: cardArea.containsMouse ? 2 : 1
                    border.color: cardArea.containsMouse ? Theme.accent : Theme.panelEdge
                    scale: cardArea.pressed ? 0.98 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 110
                        }
                    }

                    // A piece of the wallpaper, so a widget is judged where it will stand.
                    ClippingRectangle {
                        id: stage

                        x: 7
                        y: 7
                        width: parent.width - 14
                        height: parent.height - 56
                        radius: 13
                        color: Theme.surface

                        Image {
                            anchors.fill: parent
                            source: Widgets.currentImage !== "" ? "file://" + Widgets.currentImage : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 760
                            asynchronous: true
                            cache: true
                        }
                        // Stands in for the blur a widget gets on the desktop.
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.alpha(Theme.pill, 0.38)
                        }
                        WidgetPreview {
                            anchors.fill: parent
                            anchors.margins: 12
                            info: cell.modelData
                        }
                    }
                    Label {
                        x: 16
                        y: stage.y + stage.height + 6
                        width: parent.width - 62
                        text: cell.modelData.title
                        size: 14
                        font.weight: Font.Medium
                    }
                    Label {
                        x: 16
                        y: stage.y + stage.height + 25
                        width: parent.width - 62
                        text: cell.modelData.blurb
                        color: Theme.muted
                        size: 11
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        y: stage.y + stage.height + 8
                        width: 28
                        height: 28
                        radius: 14
                        color: cardArea.containsMouse ? Theme.accent : Qt.alpha(Theme.text, 0.08)

                        Label {
                            anchors.centerIn: parent
                            visible: root.count(cell.modelData.type) > 0 && !cardArea.containsMouse
                            text: root.count(cell.modelData.type)
                            color: Theme.accent
                            size: 13
                            font.weight: Font.DemiBold
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: root.count(cell.modelData.type) === 0 || cardArea.containsMouse
                            name: "plus"
                            size: 14
                            color: cardArea.containsMouse ? Theme.accentText : Theme.muted
                        }
                    }
                    MouseArea {
                        id: cardArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Widgets.add(cell.modelData.type);
                            Widgets.galleryOpen = false;
                        }
                    }
                }
            }
        }
    }
}
