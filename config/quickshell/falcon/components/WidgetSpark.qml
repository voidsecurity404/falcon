import QtQuick
import QtQuick.Shapes
import qs.services

// A smooth line over a soft fill, for a list of values from 0 to max.
Item {
    id: spark

    property var values: []
    property real max: 100
    property real min: 0
    property color color: Theme.accent
    property real lineWidth: 2.2
    property real fillAlpha: 0.32
    property bool dot: true

    readonly property var points: {
        const v = values || [];
        const n = v.length;
        if (n < 2)
            return [];
        const span = Math.max(0.0001, max - min);
        const out = [];
        for (let i = 0; i < n; i++)
            out.push(Qt.point(i / (n - 1) * width, height - 3 - (Math.max(min, Math.min(max, v[i])) - min) / span * (height - 6)));
        return out;
    }

    Shape {
        anchors.fill: parent
        visible: spark.points.length > 1
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: spark.height
                GradientStop {
                    position: 0
                    color: Qt.alpha(spark.color, spark.fillAlpha)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(spark.color, 0)
                }
            }

            PathPolyline {
                path: spark.points.length > 1 ? [Qt.point(0, spark.height)].concat(spark.points).concat([Qt.point(spark.width, spark.height)]) : []
            }
        }
        ShapePath {
            strokeColor: spark.color
            strokeWidth: spark.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: spark.points
            }
        }
    }
    Rectangle {
        visible: spark.dot && spark.points.length > 1
        readonly property point last: spark.points.length ? spark.points[spark.points.length - 1] : Qt.point(0, 0)
        x: last.x - width / 2
        y: last.y - height / 2
        width: 8
        height: 8
        radius: 4
        color: spark.color
        border.width: 2
        border.color: Qt.alpha(Theme.pill, 0.7)
    }
}
