import QtQuick
import QtQuick.Shapes

// A filled Material You style shape, drawn from a radius that changes around the middle.
// kind: circle, cookie4, cookie6, cookie9, clover, burst, flower, triangle, square,
// pentagon, diamond, oval.
Shape {
    id: root

    property string kind: "circle"
    property color color: "white"

    readonly property var kinds: ["cookie6", "clover", "triangle", "circle", "flower", "square", "cookie4", "burst", "pentagon", "diamond", "cookie9", "oval"]

    // A rounded regular polygon: the polygon's radius mixed with a circle's.
    function polygon(a, sides, round) {
        const step = Math.PI * 2 / sides;
        const local = ((a % step) + step) % step - step / 2;
        const flat = Math.cos(Math.PI / sides) / Math.cos(local);
        return flat * (1 - round) + round;
    }

    function radius(a) {
        switch (kind) {
        case "cookie4":
            return 1 + 0.1 * Math.cos(4 * a);
        case "cookie6":
            return 1 + 0.08 * Math.cos(6 * a);
        case "cookie9":
            return 1 + 0.06 * Math.cos(9 * a);
        case "clover":
            return 1 + 0.22 * Math.cos(4 * a);
        case "burst":
            return 1 + 0.12 * Math.cos(12 * a);
        case "flower":
            return 1 + 0.18 * Math.cos(8 * a);
        case "triangle":
            return polygon(a + Math.PI / 3, 3, 0.32);
        case "square":
            return polygon(a + Math.PI / 4, 4, 0.22);
        case "pentagon":
            return polygon(a + Math.PI / 5, 5, 0.22);
        case "diamond":
            return polygon(a, 4, 0.18);
        case "oval":
            return 1 / Math.sqrt(Math.pow(Math.sin(a) / 1, 2) + Math.pow(Math.cos(a) / 0.72, 2));
        default:
            return 1;
        }
    }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"

        PathPolyline {
            path: {
                const points = [];
                const steps = 96;
                const cx = root.width / 2;
                const cy = root.height / 2;
                let most = 0;
                const rs = [];
                for (let i = 0; i <= steps; i++) {
                    const r = root.radius(i / steps * Math.PI * 2);
                    rs.push(r);
                    most = Math.max(most, r);
                }
                // The shape fills the item at its widest point.
                const scale = Math.min(cx, cy) / most;
                for (let i = 0; i <= steps; i++) {
                    const a = i / steps * Math.PI * 2;
                    points.push(Qt.point(cx + Math.sin(a) * rs[i] * scale, cy - Math.cos(a) * rs[i] * scale));
                }
                return points;
            }
        }
    }
}
