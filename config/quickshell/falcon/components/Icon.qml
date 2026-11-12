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
            mic: "M12 3 A3 3 0 0 0 9 6 V12 A3 3 0 0 0 15 12 V6 A3 3 0 0 0 12 3 Z M5.5 11.5 A6.5 6.5 0 0 0 18.5 11.5 M12 18 V21",
            micOff: "M12 3 A3 3 0 0 0 9 6 V12 A3 3 0 0 0 15 12 V6 A3 3 0 0 0 12 3 Z M5.5 11.5 A6.5 6.5 0 0 0 18.5 11.5 M12 18 V21 M4 4 L20 20",
            sun: "M8.4 12 A3.6 3.6 0 1 0 15.6 12 A3.6 3.6 0 1 0 8.4 12 Z M12 3 V5 M12 19 V21 M3 12 H5 M19 12 H21 M5.6 5.6 L7 7 M17 17 L18.4 18.4 M5.6 18.4 L7 17 M17 7 L18.4 5.6",
            back: "M15 5 L8 12 L15 19",
            claude: "M12 12L12.0 2.5 M12 12L16.3 5.3 M12 12L20.6 8.1 M12 12L19.4 13.1 M12 12L18.8 17.9 M12 12L14.4 20.2 M12 12L9.3 21.1 M12 12L6.3 16.9 M12 12L3.1 13.3 M12 12L4.7 8.7 M12 12L6.9 4.0",
            timer: "M12 8 V13 L15 15 M9.5 2.5 H14.5 M12 2.5 V5 M4.5 13 A7.5 7.5 0 1 0 19.5 13 A7.5 7.5 0 1 0 4.5 13 Z",
            update: "M12 3 V14 M7.5 9.5 L12 14 L16.5 9.5 M4 16 V20 H20 V16",
            camera: "M3 7 H15 V17 H3 Z M15 11 L21 7.5 V16.5 L15 13",
            pin: "M9 3 H15 M10 3 V10 L6.5 14 H17.5 L14 10 V3 M12 14 V21",
            sparkle: "M12 3 L13.8 9.2 L20 11 L13.8 12.8 L12 19 L10.2 12.8 L4 11 L10.2 9.2 Z",
            forward: "M9 5 L16 12 L9 19",
            settings: "M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2Z M15 12a3 3 0 1 1-6 0a3 3 0 0 1 6 0Z",
            screenshot: "M4 8h3.5L9.5 5h5l2 3H20v11H4Z M8.8 13a3.2 3.2 0 1 0 6.4 0a3.2 3.2 0 1 0-6.4 0Z",
            google: "M20 12h-8 M20 12a8 8 0 1 1-2.3-5.6",
            selectRect: "M4 8V4h4 M16 4h4v4 M20 16v4h-4 M8 20H4v-4",
            lasso: "M12 4c5 0 9 2.4 9 6s-4 6-9 6s-9-2.4-9-6s4-6 9-6Z M7.5 15.5c-1.2 2.2-.2 4.5 2.5 4.5",
            copy: "M9 9h11v11H9Z M5 15H4V4h11v1",
            save: "M12 4v11 M7.5 11L12 15.5L16.5 11 M5 20h14",
            ocr: "M4 8V4h4 M16 4h4v4 M20 16v4h-4 M8 20H4v-4 M8 9h8 M12 9v7",
            color: "M12 3c3 4 6 7 6 11a6 6 0 0 1-12 0c0-4 3-7 6-11Z",
            lyrics: "M4 6h10 M4 10h10 M4 14h6 M17 17.5a2 2 0 1 1 -2 -2a2 2 0 0 1 2 2V6l3.5 -1",
            globe: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0Z M3.5 9h17 M3.5 15h17 M12 3c2.4 2.6 3.6 5.6 3.6 9s-1.2 6.4 -3.6 9 M12 3c-2.4 2.6 -3.6 5.6 -3.6 9s1.2 6.4 3.6 9",
            link: "M10 14a4 4 0 0 0 5.7 0l3 -3a4 4 0 0 0 -5.7 -5.7l-1 1 M14 10a4 4 0 0 0 -5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1 -1",
            game: "M7.5 7h9a4.5 4.5 0 0 1 4.4 3.6l1 5.1a2.4 2.4 0 0 1 -4.2 2l-2.2 -2.7h-7l-2.2 2.7a2.4 2.4 0 0 1 -4.2 -2l1 -5.1A4.5 4.5 0 0 1 7.5 7Z M7.5 10v3 M6 11.5h3 M15.5 11h.01 M17.5 13h.01",
            translate: "M4 6h9 M8.5 4v2 M6 6c1 4 3 6 6 7 M11 6c-1 4-3 6-6 7 M13 20l4-9 4 9 M14.5 17h5",
            wallpaper: "M4 5h16v14H4Z M4 16l5-5 4 4 3-3 4 4 M15.5 8.5h.01",
            focus: "M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18Z M12 8a4 4 0 1 0 0 8a4 4 0 0 0 0-8Z",
            palette: "M12 3a9 9 0 1 0 0 18c1.5 0 2-1 2-2s-.5-1.5-.5-2.5S14.5 15 16 15h2a3 3 0 0 0 3-3c0-5-4-9-9-9Z M7.5 11h.01 M10 7.5h.01 M14.5 7.5h.01",
            windows: "M4 5h7v14H4Z M14 5h6v6h-6Z M14 14h6v5h-6Z",
            rules: "M5 6h14 M5 12h14 M5 18h9",
            panel: "M3 5h18v14H3Z M3 9h18",
            keyboard: "M3 6h18v12H3Z M7 10h.01 M11 10h.01 M15 10h.01 M8 14h8",
            shortcut: "M8 5a3 3 0 1 0 0 6h8a3 3 0 1 1 0 6 M8 5v14 M16 5v14",
            monitor: "M3 5h18v12H3Z M9 21h6 M12 17v4",
            system: "M5 6h14 M5 12h14 M5 18h14 M9 4v4 M15 10v4 M9 16v4",
            widgets: "M4 4h7v7H4Z M13 4h7v7h-7Z M4 13h7v7H4Z M13 13h7v7h-7Z",
            mouse: "M12 3a6 6 0 0 0-6 6v6a6 6 0 0 0 12 0V9a6 6 0 0 0-6-6Z M12 7v4",
            terminal: "M3 5h18v14H3Z M7 9l3 3l-3 3 M12.5 15H17",
            thermo: "M14 14.8 V5 A2 2 0 0 0 10 5 V14.8 A4 4 0 1 0 14 14.8 Z M12 9 V16",
            memory: "M3 7 H21 V17 H3 Z M7 10 V14 M11 10 V14 M15 10 V14 M6 17 V19.5 M18 17 V19.5",
            bolt: "M13.5 2.5 L5.5 13.5 H11.5 L10.5 21.5 L18.5 10.5 H12.5 Z",
            chip: "M7 7h10v10H7Z M10 3v4 M14 3v4 M10 17v4 M14 17v4 M3 10h4 M3 14h4 M17 10h4 M17 14h4",
            search: "M11 4a7 7 0 1 0 0 14a7 7 0 0 0 0-14Z M16 16l5 5",
            music: "M9 18V6l10-2v12 M9 18a3 3 0 1 1-6 0a3 3 0 0 1 6 0Z M19 16a3 3 0 1 1-6 0a3 3 0 0 1 6 0Z",
            clock: "M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18Z M12 7v5l3 2",
            calendar: "M4 6h16v14H4Z M4 10h16 M8 3v4 M16 3v4",
            note: "M6 3h9l4 4v14H6Z M9 10h7 M9 14h7 M9 18h4",
            close: "M6 6 L18 18 M18 6 L6 18",
            trash: "M4 7h16 M9.5 7V4h5v3 M6 7l1 13h10l1-13 M10 11v5.5 M14 11v5.5",
            send: "M21 3 L3 10.5 L10 13 L13 20 Z M10 13 L21 3",
            plus: "M12 5 V19 M5 12 H19",
            arrowDown: "M12 4 V20 M6 14 L12 20 L18 14",
            arrowUp: "M12 20 V4 M6 10 L12 4 L18 10",
            cloud: "M7 19 H17 A4.2 4.2 0 0 0 17.5 10.6 A6 6 0 0 0 6 10.2 A4.5 4.5 0 0 0 7 19 Z",
            cloudSun: "M8 20 H16.5 A3.4 3.4 0 0 0 17 13.2 A5 5 0 0 0 7.6 12.9 A3.6 3.6 0 0 0 8 20 Z M6.5 9 A3.5 3.5 0 0 1 12.8 7.5 M9 2.5 V3.8 M3 9 H4.3 M4.7 4.7 L5.6 5.6 M13.3 4.7 L12.4 5.6",
            rain: "M7 14.5 H17 A3.8 3.8 0 0 0 17.5 7 A5.6 5.6 0 0 0 6.2 6.6 A4 4 0 0 0 7 14.5 Z M8.5 18 L7.5 21 M12.5 18 L11.5 21 M16.5 18 L15.5 21",
            snow: "M7 14.5 H17 A3.8 3.8 0 0 0 17.5 7 A5.6 5.6 0 0 0 6.2 6.6 A4 4 0 0 0 7 14.5 Z M8 18.5 V18.6 M12 18 V18.1 M16 18.5 V18.6 M10 21 V21.1 M14 21 V21.1",
            storm: "M7 14.5 H17 A3.8 3.8 0 0 0 17.5 7 A5.6 5.6 0 0 0 6.2 6.6 A4 4 0 0 0 7 14.5 Z M13 13 L10 18 H14 L11 22.5",
            fog: "M7 12 H17 A3.6 3.6 0 0 0 17.5 5 A5.4 5.4 0 0 0 6.3 4.7 A3.7 3.7 0 0 0 7 12 Z M4 16 H20 M6 20 H18",
            bluetooth: "M7 7 L17 17 L12 22 V2 L17 7 L7 17",
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
            record: "M6 12 A6 6 0 1 0 18 12 A6 6 0 1 0 6 12 Z",
            phone: "M8 2.5 H16 A2 2 0 0 1 18 4.5 V19.5 A2 2 0 0 1 16 21.5 H8 A2 2 0 0 1 6 19.5 V4.5 A2 2 0 0 1 8 2.5 Z M11 18.5 H13",
            folder: "M3.5 6.5 A1.5 1.5 0 0 1 5 5 H9.5 L11.5 7 H19 A1.5 1.5 0 0 1 20.5 8.5 V17.5 A1.5 1.5 0 0 1 19 19 H5 A1.5 1.5 0 0 1 3.5 17.5 Z",
            message: "M4 5.5 H20 V16 H10 L5.5 19.5 V16 H4 Z M8 9.5 H16 M8 12.5 H13",
            signal: "M5 19 V16 M9.5 19 V12.5 M14 19 V9 M18.5 19 V5.5",
            refresh: "M19.5 12 A7.5 7.5 0 1 1 17 6.4 M17.5 3 V7 H13.5",
            upload: "M12 15 V4 M7.5 8.5 L12 4 L16.5 8.5 M5 20 H19",
            touchpad: "M4 5 H20 V19 H4 Z M4 15 H20 M12 15 V19",
            user: "M12 4 A4 4 0 1 0 12 12 A4 4 0 1 0 12 4 Z M4.5 20.5 A7.5 7.5 0 0 1 19.5 20.5",
            wave: "M3 12 H5 L7.5 6 L11 18 L14 9 L16.5 14 L18 12 H21"
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
