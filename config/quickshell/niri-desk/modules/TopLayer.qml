import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Butun ekranni egallaydigan shaffof qatlam. Bosishlar faqat mask ichidagi elementlarga tushadi,
// panel ochiq bo'lganda catcher ekranning qolgan qismidagi bosishni ham ushlab panelni yopadi.
PanelWindow {
    id: root

    readonly property bool isFocusedScreen: !!screen && (Niri.focusedOutput === "" || Niri.focusedOutput === screen.name)
    readonly property bool panelHere: Ui.topPanelOpen && isFocusedScreen
    // Focus mode sends the bar off the screen. The island still comes back for the dashboard and
    // for the way-out hint. Each part has its own distance out, 0 is in place and 1 is gone.
    readonly property bool barShown: !Ui.zen
    readonly property bool islandShown: !Ui.zen || (panelHere && Ui.popup === "dashboard") || (!!Toasts.current && Toasts.current.inZen === true)
    readonly property int edgeSign: Settings.bottom ? 1 : -1
    readonly property var leaveCurve: [0.4, 0, 0.9, 0.3, 1, 1]
    readonly property var arriveCurve: [0.25, 1.25, 0.35, 1, 1, 1]
    // Side panels in the corners have their border just off the screen. Otherwise they float.
    readonly property int edgeGap: Settings.hug ? -1 : 10
    readonly property int sideGap: Settings.hug ? -1 : 14
    // The one-piece bar lies against the edge, so it must not overshoot, and it moves as one.
    readonly property var barArriveCurve: Settings.bar ? [0.2, 0, 0, 1, 1, 1] : arriveCurve
    property real ribbonOut: barShown ? 0 : 1
    property real statusOut: barShown ? 0 : 1
    property real islandOut: islandShown ? 0 : 1

    Behavior on ribbonOut {
        NumberAnimation {
            duration: root.barShown ? 460 : 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.barShown ? root.barArriveCurve : root.leaveCurve
        }
    }
    Behavior on statusOut {
        SequentialAnimation {
            PauseAnimation {
                duration: Settings.bar ? 0 : 50
            }
            NumberAnimation {
                duration: root.barShown ? 460 : 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.barShown ? root.barArriveCurve : root.leaveCurve
            }
        }
    }
    // The island is joined to the edge, so it must not overshoot and leave a gap.
    Behavior on islandOut {
        NumberAnimation {
            duration: root.islandShown ? 460 : 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.islandShown ? [0.2, 0, 0, 1, 1, 1] : root.leaveCurve
        }
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "niri-desk-top"
    WlrLayershell.keyboardFocus: panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Faqat panellar orqasi xiralashadi, qolgan ekran toza qoladi.
    BackgroundEffect.blurRegion: Region {
        Region {
            item: Settings.bar && root.ribbonOut < 1 ? barGlass : null
        }
        Region {
            item: !Settings.bar && root.ribbonOut < 1 ? ribbon : null
            topLeftRadius: ribbon.topLeftRadius
            topRightRadius: ribbon.topRightRadius
            bottomLeftRadius: ribbon.bottomLeftRadius
            bottomRightRadius: ribbon.bottomRightRadius
        }
        CurveRegion {
            size: Settings.hug && !Settings.bar && root.ribbonOut < 1 ? 18 : 0
            x: ribbon.x + ribbon.width
            y: Settings.bottom ? ribbon.y + 44 - 18 : ribbon.y + 1
            flipY: Settings.bottom
        }
        CurveRegion {
            size: Settings.hug && !Settings.bar && root.ribbonOut < 1 ? 18 : 0
            x: ribbon.x + 1
            y: Settings.bottom ? ribbon.y - 18 : ribbon.y + ribbon.height
            flipY: Settings.bottom
        }
        Region {
            item: !Settings.bar && root.statusOut < 1 ? status : null
            topLeftRadius: status.topLeftRadius
            topRightRadius: status.topRightRadius
            bottomLeftRadius: status.bottomLeftRadius
            bottomRightRadius: status.bottomRightRadius
        }
        CurveRegion {
            size: Settings.hug && !Settings.bar && root.statusOut < 1 ? 18 : 0
            x: status.x - 18
            y: Settings.bottom ? status.y + 44 - 18 : status.y + 1
            flipX: true
            flipY: Settings.bottom
        }
        CurveRegion {
            size: Settings.hug && !Settings.bar && root.statusOut < 1 ? 18 : 0
            x: status.x + status.width - 1 - 18
            y: Settings.bottom ? status.y - 18 : status.y + status.height
            flipX: true
            flipY: Settings.bottom
        }
        Region {
            item: root.islandOut === 1 ? null : island.body
            bottomLeftRadius: Settings.bottom ? 0 : island.body.animatedRadius
            bottomRightRadius: Settings.bottom ? 0 : island.body.animatedRadius
            topLeftRadius: Settings.bottom ? island.body.animatedRadius : 0
            topRightRadius: Settings.bottom ? island.body.animatedRadius : 0
        }
        CurveRegion {
            size: root.islandOut === 0 ? island.joinSize : 0
            x: island.x - island.joinSize
            y: island.y + island.joinY
            flipX: true
            flipY: Settings.bottom
        }
        CurveRegion {
            size: root.islandOut === 0 ? island.joinSize : 0
            x: island.x + island.width
            y: island.y + island.joinY
            flipY: Settings.bottom
        }
    }

    mask: Region {
        Region {
            item: catcher
        }
        Region {
            item: Settings.bar && root.barShown ? barGlass : null
        }
        Region {
            item: root.barShown ? ribbon : null
        }
        Region {
            item: root.barShown ? status : null
        }
        Region {
            item: root.islandOut < 1 ? island.body : null
        }
    }

    // Kofe rejimi: fokuslangan ekrandagi shu oyna tizimni uyg'oq ushlab turadi.
    IdleInhibitor {
        enabled: Caffeine.enabled && root.isFocusedScreen
        window: root
    }

    MouseArea {
        id: catcher

        width: root.panelHere ? parent.width : 0
        height: root.panelHere ? parent.height : 0
        onClicked: Ui.popup = ""
    }

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: root.panelHere
        // Esc steps back from a Wi-Fi or Bluetooth list before it closes the panel.
        Keys.onEscapePressed: {
            if (Ui.controlPage !== "")
                Ui.controlPage = "";
            else
                Ui.popup = "";
        }
    }

    // The glass of the one-piece bar. Ribbon, Island and StatusPill only put their content on it.
    Rectangle {
        id: barGlass

        // The line along the free edge opens where the island has grown out of the bar.
        readonly property real gapStart: island.height > island.barDepth + 1 ? island.x - island.joinSize : width / 2

        visible: Settings.bar && root.ribbonOut < 1
        width: parent.width
        height: 45
        y: (Settings.bottom ? parent.height - height - root.edgeGap : root.edgeGap) + root.edgeSign * root.ribbonOut * 64
        opacity: Math.min(1, (1 - root.ribbonOut) * 3)
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

        Rectangle {
            y: Settings.bottom ? 0 : parent.height - 1
            width: parent.gapStart
            height: 1
            color: Theme.panelEdge
        }
        Rectangle {
            x: parent.width - parent.gapStart
            y: Settings.bottom ? 0 : parent.height - 1
            width: parent.gapStart
            height: 1
            color: Theme.panelEdge
        }
    }

    Ribbon {
        id: ribbon

        x: root.sideGap
        y: (Settings.bottom ? parent.height - height - root.edgeGap : root.edgeGap) + root.edgeSign * root.ribbonOut * 64
        opacity: Math.min(1, (1 - root.ribbonOut) * 3)
        visible: root.ribbonOut < 1
        screenInfo: root.screen
    }

    StatusPill {
        id: status

        anchors.right: parent.right
        anchors.rightMargin: root.sideGap
        y: (Settings.bottom ? parent.height - height - root.edgeGap : root.edgeGap) + root.edgeSign * root.statusOut * 64
        opacity: Math.min(1, (1 - root.statusOut) * 3)
        visible: root.statusOut < 1
    }

    Island {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        y: Settings.bottom ? parent.height - height : 0
        slide: root.islandOut
        onBar: Settings.bar && root.ribbonOut < 1
        visible: root.islandOut < 1
        showDashboard: root.panelHere && Ui.popup === "dashboard"
    }

    TrayMenu {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: Settings.bottom ? parent.height - height - 52 : 52
        shown: root.panelHere && Ui.popup === "tray"
    }

    ClaudePanel {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: Settings.bottom ? parent.height - height - 52 : 52
        shown: root.panelHere && Ui.popup === "claude"
    }

    ControlCenter {
        id: control

        anchors.right: parent.right
        anchors.rightMargin: 14
        y: Settings.bottom ? parent.height - height - 52 : 52
        shown: root.panelHere && Ui.popup === "control"
        onReleaseFocus: keyScope.forceActiveFocus()
    }

    // The screen's own corners look round, as on end-4's desktop. Fullscreen windows lie above this layer.
    Repeater {
        model: Settings.hug ? [[false, false], [true, false], [false, true], [true, true]] : []

        delegate: EdgeCurve {
            required property var modelData

            size: 23
            x: modelData[0] ? root.width - size : 0
            y: modelData[1] ? root.height - size : 0
            flipX: modelData[0]
            flipY: modelData[1]
            color: "black"
        }
    }
}
