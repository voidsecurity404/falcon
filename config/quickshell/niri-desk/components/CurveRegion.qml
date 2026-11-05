import Quickshell

// The blur area of an EdgeCurve: its square without the circle that shapes it. x and y are the
// curve's place in the window, and a size of 0 leaves the area empty.
Region {
    id: root

    property int size: 18
    property bool flipX: false
    property bool flipY: false

    width: size
    height: size

    Region {
        shape: RegionShape.Ellipse
        intersection: Intersection.Subtract
        x: root.x - (root.flipX ? root.size : 0)
        y: root.y - (root.flipY ? root.size : 0)
        width: root.size * 2
        height: root.size * 2
    }
}
