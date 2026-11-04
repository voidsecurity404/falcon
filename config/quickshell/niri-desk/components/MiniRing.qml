import QtQuick
import QtQuick.Shapes
import qs.services

// Small ring that fills up with value, 0 to 100.
Item {
    id: root

    property real value: 0

    readonly property color tone: value >= 90 ? Theme.error : Theme.accent

    width: 18
    height: 18

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(Theme.text, 0.16)
            strokeWidth: 2.5
            fillColor: "transparent"

            PathAngleArc {
                centerX: 9
                centerY: 9
                radiusX: 7.5
                radiusY: 7.5
                startAngle: -90
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: root.tone
            strokeWidth: 2.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: 9
                centerY: 9
                radiusX: 7.5
                radiusY: 7.5
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, root.value / 100))

                Behavior on sweepAngle {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
