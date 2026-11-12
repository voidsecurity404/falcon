import QtQuick
import qs.services

// One glass island of the bar: a rounded plate holding a row. The compositor blurs what is
// behind it through TopLayer's blur region. The wheel over it reports whole steps, as end-4 does:
// TopLayer turns them into brightness on the left half of the screen and volume on the right.
Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    property real wheelRest: 0
    // The preview in Settings: no wheel, and some room even when empty.
    property bool wheelEnabled: true
    property real minWidth: 0
    // In the joined bar one long plate lies under all islands, so they draw none of their own.
    property bool plain: false
    signal scrolled(real x, int step)

    implicitWidth: Math.max(minWidth, row.implicitWidth + 24)
    implicitHeight: BarLayout.height
    radius: BarLayout.radius
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        visible: !root.plain
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.glassTop
            }
            GradientStop {
                position: 1
                color: Theme.panel
            }
        }
        border.width: BarLayout.border ? 1 : 0
        border.color: Theme.panelEdge
    }

    Row {
        id: row

        x: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: BarLayout.spacing
    }

    // Above the row so it sees the wheel first. A plain Item takes no presses, so clicks pass.
    Item {
        anchors.fill: parent
        z: 10

        WheelHandler {
            enabled: root.wheelEnabled
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                root.wheelRest += event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 4;
                while (Math.abs(root.wheelRest) >= 120) {
                    const step = root.wheelRest > 0 ? 1 : -1;
                    root.wheelRest -= step * 120;
                    root.scrolled(point.position.x, step);
                }
            }
        }
    }
}
