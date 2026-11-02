import QtQuick
import QtQuick.Shapes
import qs.services

Column {
    id: root

    property real value: 0
    property string label: ""

    signal clicked

    spacing: 5

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 54
        height: 54

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.alpha(Theme.text, 0.12)
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap

                PathAngleArc {
                    centerX: 27
                    centerY: 27
                    radiusX: 25
                    radiusY: 25
                    startAngle: -90
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: Theme.accent
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: 27
                    centerY: 27
                    radiusX: 25
                    radiusY: 25
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0, Math.min(1, root.value / 100))

                    Behavior on sweepAngle {
                        NumberAnimation {
                            duration: 450
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }

        Label {
            anchors.centerIn: parent
            text: Math.round(root.value)
            size: 13
            font.weight: Font.Medium
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        color: Theme.muted
        size: 11
    }
}
