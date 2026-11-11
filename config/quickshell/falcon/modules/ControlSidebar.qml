import QtQuick
import qs.components
import qs.services

// The studio layout's control center: a tall glass sheet along the right edge, with the quick
// controls at the top and the notifications under them. It slides in from the edge and settles.
Rectangle {
    id: root

    property bool shown: false
    property real t: 0
    // The room above it, taken by the panel.
    property int room: 54
    signal releaseFocus

    onShownChanged: {
        slide.stop();
        slide.to = shown ? 1 : 0;
        slide.duration = shown ? 560 : 260;
        slide.easing.bezierCurve = shown ? [0.2, 1.08, 0.3, 1, 1, 1] : [0.4, 0, 0.9, 0.4, 1, 1];
        slide.start();
    }

    NumberAnimation {
        id: slide

        target: root
        property: "t"
        easing.type: Easing.BezierSpline
    }

    width: 446
    x: (parent ? parent.width : 0) - 10 - width + (1 - t) * (width + 40)
    y: room
    height: (parent ? parent.height : 0) - room - 10
    radius: 28
    visible: t > 0.001
    opacity: Math.min(1, t * 2.5)
    clip: true
    border.width: 1
    border.color: Theme.panelEdge
    // Stays dark enough for its text over a white window, whatever the panel opacity is.
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

    MouseArea {
        anchors.fill: parent
    }

    ControlCenter {
        id: controls

        x: (root.width - width) / 2
        y: 4
        embedded: true
        shown: root.shown
        onReleaseFocus: root.releaseFocus()
    }

    // A thin line between the controls and the notifications.
    Rectangle {
        x: 24
        y: controls.y + controls.height + 2
        width: root.width - 48
        height: 1
        color: Qt.alpha(Theme.text, 0.1)
    }

    NotificationList {
        x: 18
        y: controls.y + controls.height + 14
        width: root.width - 36
        height: root.height - y - 16
        // Cards come in from the right a moment after the sheet.
        opacity: Math.max(0, Math.min(1, (root.t - 0.5) * 2))
    }
}
