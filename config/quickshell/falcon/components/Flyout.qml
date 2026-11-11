import QtQuick
import qs.services

// A small glass menu that drops from a part of the bar. It grows its own height, because the blur
// region follows the item's size and not a scale, and its content keeps a fixed size inside, so
// nothing reflows while it opens. The parent places it under the part that opened it.
Rectangle {
    id: root

    property bool shown: false
    property real reveal: 0
    property int panelWidth: 320
    property int padding: 16
    default property alias content: holder.data
    readonly property real contentHeight: holder.childrenRect.height + padding * 2

    width: panelWidth - 24 * (1 - reveal)
    height: contentHeight * reveal
    clip: true
    radius: 22
    border.width: 1
    border.color: Theme.panelEdge
    color: "transparent"
    // Dark enough for its text over a white window, whatever the panel opacity is.
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.alpha(Theme.glassBase, Math.max(0.72, Theme.glassOpacity))
        }
        GradientStop {
            position: 1
            color: Qt.alpha(Theme.glassBase, Math.max(0.6, Theme.glassOpacity))
        }
    }
    opacity: Math.min(1, reveal * 2.5)
    visible: reveal > 0

    onShownChanged: {
        revealAnimation.stop();
        revealAnimation.to = shown ? 1 : 0;
        revealAnimation.duration = shown ? 380 : 200;
        revealAnimation.easing.bezierCurve = shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1];
        revealAnimation.start();
    }

    NumberAnimation {
        id: revealAnimation

        target: root
        property: "reveal"
        easing.type: Easing.BezierSpline
    }

    // A click inside must not reach the catcher behind it, which closes the menu.
    MouseArea {
        anchors.fill: parent
    }

    Item {
        x: (root.width - root.panelWidth) / 2
        width: root.panelWidth
        height: root.contentHeight

        Item {
            id: holder

            x: root.padding
            y: root.padding
            width: root.panelWidth - root.padding * 2
            height: childrenRect.height
        }
    }
}
