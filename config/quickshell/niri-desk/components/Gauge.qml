import QtQuick
import qs.services

// Round meter built from ticks, like a watch bezel: the ticks light up along a 270 degree arc.
Item {
    id: root

    property real value: 0
    property string text: ""
    property string unit: ""
    property string label: ""
    property string detail: ""
    property bool hot: false
    property color color: Theme.accent
    property int count: width > 120 ? 45 : 30

    readonly property real radius: width / 2
    readonly property real tickLength: Math.max(5, width * 0.065)
    readonly property color lit: hot ? Theme.error : color
    property real level: Math.max(0, Math.min(1, value))
    property real intro: 0

    implicitHeight: width

    function replay() {
        rise.restart();
    }

    Component.onCompleted: replay()
    onVisibleChanged: {
        if (visible)
            replay();
    }

    Behavior on level {
        NumberAnimation {
            duration: 1200
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: rise

        target: root
        property: "intro"
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.OutCubic
    }

    Repeater {
        model: root.count

        delegate: Rectangle {
            required property int index

            readonly property real on: Math.max(0, Math.min(1, root.level * root.intro * root.count - index))

            x: root.radius - width / 2
            y: 1
            width: root.width > 120 ? 3 : 2.5
            height: root.tickLength
            radius: width / 2
            antialiasing: true
            color: on > 0 ? root.lit : Theme.text
            opacity: 0.13 + on * 0.87
            transform: Rotation {
                origin.x: width / 2
                origin.y: root.radius - 1
                angle: -135 + 270 * index / (root.count - 1)
            }
        }
    }

    Column {
        anchors.centerIn: parent

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1

            Label {
                text: root.text
                size: Math.round(root.width * 0.235)
                font.weight: Font.Light
                font.letterSpacing: -0.5
            }
            Label {
                anchors.baseline: parent.children[0].baseline
                visible: root.unit !== ""
                text: root.unit
                size: Math.round(root.width * 0.105)
                color: Theme.muted
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.detail !== ""
            text: root.detail
            size: 11
            color: Theme.muted
        }
    }

    // Sits in the opening at the bottom of the arc.
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        size: root.width > 120 ? 12 : 11
        color: root.hot ? Theme.error : Theme.muted
    }
}
