import QtQuick
import QtQuick.Shapes

// The concave corner that joins a panel to the edge of the screen. Unflipped, it fills the
// space under a top-left corner.
Shape {
    id: root

    property int size: 18
    property color color
    property bool flipX: false
    property bool flipY: false

    width: size
    height: size
    transform: Scale {
        origin.x: root.size / 2
        origin.y: root.size / 2
        xScale: root.flipX ? -1 : 1
        yScale: root.flipY ? -1 : 1
    }
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.color

        PathSvg {
            path: "M" + root.size + " 0 L0 0 L0 " + root.size + " A" + root.size + " " + root.size + " 0 0 1 " + root.size + " 0 Z"
        }
    }
}
