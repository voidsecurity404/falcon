import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services

// Blurred picture behind the panel: the wallpaper, or the album art when one is given.
Item {
    id: root

    property string art: ""
    property real bottomRadius: 18

    readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.local/state/niri-desk/wallpaper"

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
        visible: false
        layer.enabled: true
    }

    Image {
        id: wall

        anchors.fill: parent
        source: root.wallpaper
        cache: false
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 140
        visible: false
    }
    Image {
        id: cover

        anchors.fill: parent
        source: root.art
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 48
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 1
        blurMax: 64
        saturation: 0.25
        opacity: root.art === "" || cover.status !== Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 480
            }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: cover
        blurEnabled: true
        blur: 1
        blurMax: 64
        saturation: 0.35
        opacity: root.art !== "" && cover.status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 480
            }
        }
    }
    // Pastga qarab quyuqlashadi: yozuvlar har qanday rasmda o'qiladi.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.pill, 0.62)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Theme.pill, 0.86)
            }
        }
    }

    Connections {
        target: Theme
        function onAccentChanged() {
            wall.source = "";
            wall.source = root.wallpaper;
        }
    }
}
