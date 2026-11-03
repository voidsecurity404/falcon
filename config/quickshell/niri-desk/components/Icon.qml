import QtQuick
import QtQuick.Shapes
import qs.services

// Ingichka chiziqli ikonkalar, 24x24 koordinatada chizilgan.
Item {
    id: root

    property string name: "check"
    property color color: Theme.text
    property real size: 15
    property bool filled: false

    readonly property var paths: ({
            wifi: "M2 8.8 A15 15 0 0 1 22 8.8 M5.3 12.6 A10 10 0 0 1 18.7 12.6 M8.7 16.3 A5 5 0 0 1 15.3 16.3 M12 19.6 L12 20",
            wifiOff: "M2 8.8 A15 15 0 0 1 22 8.8 M5.3 12.6 A10 10 0 0 1 18.7 12.6 M8.7 16.3 A5 5 0 0 1 15.3 16.3 M12 19.6 L12 20 M4 3 L20 21",
            ethernet: "M9 3 H15 V8 H9 Z M3 16 H9 V21 H3 Z M15 16 H21 V21 H15 Z M12 8 V12 M6 16 V12 H18 V16",
            volume: "M4 9.5 V14.5 H7.6 L12 18.5 V5.5 L7.6 9.5 H4 Z M15.5 9 A4.5 4.5 0 0 1 15.5 15 M18.5 6.5 A8.5 8.5 0 0 1 18.5 17.5",
            mute: "M4 9.5 V14.5 H7.6 L12 18.5 V5.5 L7.6 9.5 H4 Z M16 9.5 L21 14.5 M21 9.5 L16 14.5",
            sun: "M8.4 12 A3.6 3.6 0 1 0 15.6 12 A3.6 3.6 0 1 0 8.4 12 Z M12 3 V5 M12 19 V21 M3 12 H5 M19 12 H21 M5.6 5.6 L7 7 M17 17 L18.4 18.4 M5.6 18.4 L7 17 M17 7 L18.4 5.6",
            bluetooth: "M7 7 L17 17 L12 22 V2 L17 7 L7 17",
            shield: "M12 3 L5 6 V11 C5 16 8 19.5 12 21 C16 19.5 19 16 19 11 V6 L12 3 Z",
            moon: "M20 14.5 A8.5 8.5 0 0 1 9.5 4 A8.5 8.5 0 1 0 20 14.5 Z",
            bell: "M6 16 V11 A6 6 0 0 1 18 11 V16 L19.5 18 H4.5 L6 16 Z M10 21 H14",
            battery: "M4.7 7.5 H17.3 A2.2 2.2 0 0 1 19.5 9.7 V14.3 A2.2 2.2 0 0 1 17.3 16.5 H4.7 A2.2 2.2 0 0 1 2.5 14.3 V9.7 A2.2 2.2 0 0 1 4.7 7.5 Z M22 11 V13 M5.5 10.5 V13.5 M9 10.5 V13.5 M12.5 10.5 V13.5",
            charging: "M4.7 7.5 H17.3 A2.2 2.2 0 0 1 19.5 9.7 V14.3 A2.2 2.2 0 0 1 17.3 16.5 H4.7 A2.2 2.2 0 0 1 2.5 14.3 V9.7 A2.2 2.2 0 0 1 4.7 7.5 Z M22 11 V13 M12 9.5 L9 12.3 H13 L10 14.8",
            play: "M7 4.5 V19.5 L19 12 L7 4.5 Z",
            pause: "M8 5 V19 M16 5 V19",
            previous: "M18 5 V19 L8 12 L18 5 Z M6 5 V19",
            next: "M6 5 V19 L16 12 L6 5 Z M18 5 V19",
            check: "M5 12.5 L9.5 17 L19 7.5",
            alert: "M12 4 L21.5 20 H2.5 L12 4 Z M12 10 V14.5 M12 17.3 V17.6",
            coffee: "M5 9 H17 V15 A4 4 0 0 1 13 19 H9 A4 4 0 0 1 5 15 Z M17 10.5 H19 A2.5 2.5 0 0 1 19 15.5 H17 M8.5 3 V6 M12.5 3 V6",
            lock: "M6 11 H18 V20 H6 Z M8.5 11 V7.5 A3.5 3.5 0 0 1 15.5 7.5 V11",
            logout: "M10 4 H5 V20 H10 M15 8 L19.5 12 L15 16 M9.5 12 H19.5",
            reboot: "M19.5 12 A7.5 7.5 0 1 1 17 6.4 M17.5 3 V7 H13.5",
            power: "M12 3 V12 M6.3 7 A8 8 0 1 0 17.7 7",
            record: "M6 12 A6 6 0 1 0 18 12 A6 6 0 1 0 6 12 Z"
        })

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.8
            fillColor: root.filled ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.paths[root.name] || ""
            }
        }
    }
}
