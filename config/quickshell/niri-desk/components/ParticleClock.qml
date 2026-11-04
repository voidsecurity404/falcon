import QtQuick
import Quickshell
import qs.services

// The time made of dots: they appear on opening, flee from the pointer and tremble with the CPU load.
// Drawn by shaders/particle-clock.frag on the video card, the main thread only passes a few numbers.
Item {
    id: root

    property bool pointerHere: false
    property real pointerX: 0
    property real pointerY: 0
    property real centerY: height / 2

    readonly property string wanted: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
    property string shown: wanted
    property string next: wanted
    readonly property font digitFont: Qt.font({
        family: "Unbounded",
        weight: Font.ExtraBold,
        pixelSize: 240
    })

    onWantedChanged: {
        // Digits switch only after the running change has finished.
        if (!change.running) {
            next = wanted;
            change.restart();
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Item {
        id: digitsA

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Text {
            text: root.shown
            width: root.width
            height: root.centerY * 2
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font: root.digitFont
            color: "#ffffff"
        }
    }
    Item {
        id: digitsB

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Text {
            text: root.next
            width: root.width
            height: root.centerY * 2
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font: root.digitFont
            color: "#ffffff"
        }
    }

    ShaderEffect {
        id: dots

        readonly property size size: Qt.size(width, height)
        readonly property point pointer: Qt.point(smoothX, smoothY)
        readonly property var digitsA: digitsA
        readonly property var digitsB: digitsB
        readonly property real topY: root.centerY - 100
        readonly property real bottomY: root.centerY + 100
        readonly property color colorTop: Theme.accent
        readonly property color colorBottom: Qt.hsla((Math.max(0, Theme.accent.hslHue) + 0.18) % 1, Theme.accent.hslSaturation, Theme.accent.hslLightness, 1)
        property real smoothX: root.pointerX
        property real smoothY: root.pointerY
        property real push: root.pointerHere ? 1 : 0
        property real time: 0
        property real tremble: (0.5 + Sys.cpu / 100 * 5) * 0.4
        property real blend: 0
        property real assemble: 0

        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../shaders/particle-clock.frag.qsb")

        Component.onCompleted: {
            assemble = 1;
        }

        // The dots spring after the pointer, so the hole in the digits wobbles behind it.
        Behavior on smoothX {
            SpringAnimation {
                spring: 3.2
                damping: 0.32
            }
        }
        Behavior on smoothY {
            SpringAnimation {
                spring: 3.2
                damping: 0.32
            }
        }
        Behavior on push {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutCubic
            }
        }
        Behavior on tremble {
            NumberAnimation {
                duration: 1200
            }
        }
        Behavior on assemble {
            NumberAnimation {
                duration: 1100
                easing.type: Easing.OutCubic
            }
        }
        NumberAnimation on time {
            running: root.visible
            from: 0
            to: 3600
            duration: 3600000
            loops: Animation.Infinite
        }
    }

    SequentialAnimation {
        id: change

        NumberAnimation {
            target: dots
            property: "blend"
            from: 0
            to: 1
            duration: 900
            easing.type: Easing.InOutSine
        }
        ScriptAction {
            script: {
                root.shown = root.next;
                dots.blend = 0;
                // The minute may have passed during a long sleep.
                if (root.wanted !== root.next) {
                    root.next = root.wanted;
                    change.restart();
                }
            }
        }
    }
}
