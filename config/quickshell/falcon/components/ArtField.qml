import QtQuick
import QtQuick.Effects

// One heavily blurred copy of the cover. It is blurred once into a small texture and then only turned,
// so the slow motion of the background costs almost nothing.
Item {
    id: root

    property alias source: picture.source
    property real turnSeconds: 90
    property bool turning: true
    property bool reverse: false
    readonly property bool ready: picture.status === Image.Ready

    layer.enabled: true
    layer.textureSize: Qt.size(320, 320)
    layer.smooth: true
    layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1
        blurMax: 64
        blurMultiplier: 1.5
        saturation: 0.45
    }

    Image {
        id: picture

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 48
        sourceSize.height: 48
        asynchronous: true
    }

    RotationAnimator on rotation {
        running: root.turning && root.visible
        from: root.reverse ? 360 : 0
        to: root.reverse ? 0 : 360
        duration: root.turnSeconds * 1000
        loops: Animation.Infinite
    }
}
