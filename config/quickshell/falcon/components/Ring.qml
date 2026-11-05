import QtQuick
import QtQuick.Shapes
import qs.services

// A round meter: a faint track and a rounded arc from the top, clockwise.
Item {
    id: root

    property real value: 0
    property real thickness: 10
    property color color: Theme.accent
    property color trackColor: Qt.alpha(color, 0.18)
    property bool animated: true
    property real shown: Math.max(0, Math.min(1, value))

    readonly property real radius: Math.min(width, height) / 2 - thickness / 2

    Behavior on shown {
        enabled: root.animated

        NumberAnimation {
            duration: 600
            easing.type: Easing.OutCubic
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.thickness

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.shown > 0.003 ? root.color : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: root.shown * 359.9
            }
        }
    }
}
