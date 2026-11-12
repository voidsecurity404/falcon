import QtQuick
import Quickshell.Widgets
import qs.services

// A thick pill slider with its icon inside, filled up to the value. A press anywhere jumps there.
Item {
    id: slide

    property real value: 0
    property string icon: "volume"
    property string label: ""
    property bool dimmed: false
    property color color: Theme.accent
    signal moved(real value)
    signal iconClicked

    implicitHeight: 44

    ClippingRectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Theme.text, hot.hovered ? 0.12 : 0.08)

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Rectangle {
            id: fill

            readonly property real shown: Math.max(0, Math.min(1, slide.value))

            width: Math.max(track.height, track.width * shown)
            height: parent.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha(slide.color, slide.dimmed ? 0.35 : 0.75)
                }
                GradientStop {
                    position: 1
                    color: slide.dimmed ? Qt.alpha(slide.color, 0.45) : slide.color
                }
            }

            Behavior on width {
                enabled: !hot.down

                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
        }
        Rectangle {
            x: fill.width - 12
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: parent.height * (hot.hovered || hot.down ? 0.5 : 0.36)
            radius: 2
            color: Qt.alpha(Theme.accentText, 0.6)

            Behavior on height {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }
    WidgetHot {
        id: hot

        anchors.fill: parent
        slider: true
        onSlid: share => slide.moved(share)
    }
    Item {
        id: iconSpot

        width: track.height
        height: track.height

        Icon {
            anchors.centerIn: parent
            name: slide.icon
            size: 17
            color: fill.width > track.height * 0.9 ? Theme.accentText : Theme.text
        }
        WidgetHot {
            anchors.fill: parent
            onClicked: slide.iconClicked()
        }
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: slide.label !== "" ? slide.label : Math.round(slide.value * 100) + "%"
        size: 13
        font.weight: Font.DemiBold
        color: fill.width > track.width - 54 ? Theme.accentText : Theme.text
    }
}
