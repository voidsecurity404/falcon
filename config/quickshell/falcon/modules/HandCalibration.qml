import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Hand control calibration: a circle in each corner in turn. Pointing at it and holding still for
// a second stores where the hand was. The engine turns the four places into a mapping.
PanelWindow {
    id: root

    readonly property bool on: HandMouse.calStep >= 0
    readonly property int step: Math.max(0, Math.min(3, HandMouse.calStep))
    readonly property var target: HandMouse.targets[step]
    property real shown: on ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    visible: on || shown > 0.01
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
    WlrLayershell.namespace: "falcon-handcal"
    WlrLayershell.keyboardFocus: on ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.86 * root.shown
    }

    Item {
        anchors.fill: parent
        opacity: root.shown
        focus: true
        Keys.onEscapePressed: HandMouse.cancelCalibration()

        Column {
            anchors.centerIn: parent
            spacing: 10

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "hand"
                size: 40
                color: "white"
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: HandMouse.started ? Tr.t("Point at the circle and hold still") : Tr.t("Starting the camera…")
                color: "white"
                size: 22
                font.weight: Font.DemiBold
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !HandMouse.started ? "" : HandMouse.calHand ? Tr.t("Corner {n} of 4").replace("{n}", root.step + 1) : Tr.t("Raise your hand so the camera can see it")
                color: Qt.alpha("white", 0.75)
                size: 14
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 14
                text: Tr.t("Esc to cancel")
                color: Qt.alpha("white", 0.5)
                size: 12
            }
        }

        // The target slides from corner to corner.
        Item {
            id: dot

            width: 96
            height: 96
            x: root.width * root.target[0] - width / 2
            y: root.height * root.target[1] - height / 2
            visible: HandMouse.started

            Behavior on x {
                NumberAnimation {
                    duration: 520
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 520
                    easing.type: Easing.InOutCubic
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 96
                height: 96
                radius: 48
                color: "transparent"
                border.width: 2
                border.color: Qt.alpha(Theme.accent, 0.5)
                scale: pulse.value
                opacity: HandMouse.calHand ? 0 : 2 - pulse.value * 1.4

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }
            QtObject {
                id: pulse

                property real value: 0.8

                property var anim: SequentialAnimation {
                    running: root.on
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: pulse
                        property: "value"
                        from: 0.8
                        to: 1.35
                        duration: 1100
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Ring {
                anchors.centerIn: parent
                width: 64
                height: 64
                thickness: 5
                value: HandMouse.calHold
                animated: false
                color: Theme.accent
                trackColor: Qt.alpha("white", 0.18)
            }
            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: HandMouse.calHold > 0 ? Theme.accent : "white"
            }
        }
    }
}
