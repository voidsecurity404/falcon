import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Covers the screen after login while the saved windows come back, then fades away and shows
// the desktop with everything already in place. It appears at once, over the same wallpaper
// that is underneath, so only the clock seems to arrive. A click lifts it early.
PanelWindow {
    id: root

    visible: Restore.active || veil.opacity > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "falcon-cover"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: veil

        anchors.fill: parent
        opacity: Restore.active ? 1 : 0

        // Only the way out is animated, so nothing shows through on the way in.
        Behavior on opacity {
            enabled: !Restore.active
            NumberAnimation {
                duration: 520
                easing.type: Easing.InOutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Image {
            anchors.fill: parent
            source: "file://" + Ui.home + "/.local/state/falcon/wallpaper"
            sourceSize: Qt.size(root.width || 1920, root.height || 1080)
            fillMode: Image.PreserveAspectCrop
            cache: false
            smooth: true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.28)
        }

        Column {
            id: middle

            property real intro: 0

            anchors.centerIn: parent
            anchors.verticalCenterOffset: (1 - intro) * 14 + (1 - veil.opacity) * -10
            spacing: 14
            opacity: intro
            scale: 0.96 + 0.04 * intro
            // A soft shadow keeps the text readable over a busy picture.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.6
                shadowBlur: 1
                blurMax: 40
                shadowVerticalOffset: 2
            }

            NumberAnimation on intro {
                from: 0
                to: 1
                duration: 600
                easing.type: Easing.OutCubic
                running: root.visible
            }

            Label {
                id: clock

                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(new Date(), "HH:mm")
                color: "white"
                size: 104
                font.family: Theme.display
                renderType: Text.QtRendering

                Timer {
                    interval: 1000
                    repeat: true
                    running: root.visible
                    onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm")
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Tr.t("Restoring your windows")
                color: Qt.rgba(1, 1, 1, 0.78)
                size: 15
            }

            Row {
                id: dots

                property real phase: 0

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                topPadding: 4

                NumberAnimation on phase {
                    from: 0
                    to: 3
                    duration: 1200
                    loops: Animation.Infinite
                    running: root.visible
                }

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index
                        // Each dot brightens as the wave passes it.
                        readonly property real near: Math.max(0, 1 - Math.abs(((dots.phase - index + 4.5) % 3) - 1.5))

                        width: 6
                        height: 6
                        radius: 3
                        color: "white"
                        opacity: 0.3 + 0.7 * near
                        scale: 0.85 + 0.3 * near
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: Restore.active
        onClicked: Restore.finish()
    }
}
