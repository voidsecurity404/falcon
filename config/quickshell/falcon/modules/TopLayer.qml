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
    // The panel design, see Settings.layout. Each one places the parts and opens the dashboard and
    // the control center in its own way.
    readonly property string layout: Settings.layout
    readonly property bool sideParts: layout === "falcon" || layout === "studio"
    // Where the rail layout opens its panels: just right of the rail.
    readonly property int railRight: 10 + rail.width + 10
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

    // Small popups (tray menu, Claude limits) open under the panel's right side, under the halo
    // capsule, or beside the rail at its bottom.
    function popupX(w) {
        if (layout === "rail")
            return railRight;
        if (layout === "halo")
            return Math.min(width - w - 14, island.x + island.width - w);
        return width - w - 14;
    }
    function popupY(h) {
        if (layout === "rail")
            return height - h - 10;
        return Settings.bottom ? height - h - 52 : 56;
    }
    property real ribbonOut: barShown ? 0 : 1
    property real statusOut: barShown ? 0 : 1
    property real islandOut: islandShown ? 0 : 1

    // A calm settle with no bounce, and it starts just off the screen, so all of the way is seen.
    Behavior on ribbonOut {
        NumberAnimation {
            duration: root.barShown ? 640 : 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.barShown ? [0.22, 0.61, 0.36, 1, 1, 1] : root.leaveCurve
        }
    }
    Behavior on statusOut {
        SequentialAnimation {
            PauseAnimation {
                duration: 50
            }
            NumberAnimation {
                duration: root.barShown ? 460 : 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.barShown ? root.arriveCurve : root.leaveCurve
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
    WlrLayershell.namespace: "falcon-top"
    WlrLayershell.keyboardFocus: panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Faqat panellar orqasi xiralashadi, qolgan ekran toza qoladi.
    BackgroundEffect.blurRegion: Region {
        Region {
            item: control.visible ? control : null
            radius: control.radius
        }
        Region {
            item: rail.visible ? rail : null
            radius: rail.radius
        }
        Region {
            item: dashModal.card.visible ? dashModal.card : null
            radius: dashModal.card.radius
        }
        Region {
            item: sidebar.visible ? sidebar : null
            radius: sidebar.radius
        }
        Region {
            item: root.ribbonOut < 1 && root.sideParts ? ribbon : null
            topLeftRadius: ribbon.topLeftRadius
            topRightRadius: ribbon.topRightRadius
            bottomLeftRadius: ribbon.bottomLeftRadius
            bottomRightRadius: ribbon.bottomRightRadius
        }
        CurveRegion {
            size: Settings.hug && root.ribbonOut < 1 ? 18 : 0
            x: ribbon.x + ribbon.width
            y: Settings.bottom ? ribbon.y + 44 - 18 : ribbon.y + 1
            flipY: Settings.bottom
        }
        CurveRegion {
            size: Settings.hug && root.ribbonOut < 1 ? 18 : 0
            x: ribbon.x + 1
            y: Settings.bottom ? ribbon.y - 18 : ribbon.y + ribbon.height
            flipY: Settings.bottom
        }
        Region {
            item: root.statusOut < 1 && root.sideParts ? status : null
            topLeftRadius: status.topLeftRadius
            topRightRadius: status.topRightRadius
            bottomLeftRadius: status.bottomLeftRadius
            bottomRightRadius: status.bottomRightRadius
        }
        CurveRegion {
            size: Settings.hug && root.statusOut < 1 ? 18 : 0
            x: status.x - 18
            y: Settings.bottom ? status.y + 44 - 18 : status.y + 1
            flipX: true
            flipY: Settings.bottom
        }
        CurveRegion {
            size: Settings.hug && root.statusOut < 1 ? 18 : 0
            x: status.x + status.width - 1 - 18
            y: Settings.bottom ? status.y - 18 : status.y + status.height
            flipX: true
            flipY: Settings.bottom
        }
        Region {
            item: root.islandOut === 1 || island.body.opacity < 0.05 || dashModal.t > 0.05 ? null : island.body
            bottomLeftRadius: Settings.bottom && island.joined ? 0 : island.body.animatedRadius
            bottomRightRadius: Settings.bottom && island.joined ? 0 : island.body.animatedRadius
            topLeftRadius: Settings.bottom || !island.joined ? island.body.animatedRadius : 0
            topRightRadius: Settings.bottom || !island.joined ? island.body.animatedRadius : 0
        }
        CurveRegion {
            size: root.islandOut === 0 && island.joined ? 18 : 0
            x: island.x - 18
            y: island.y + (Settings.bottom ? island.height - 18 : 0)
            flipX: true
            flipY: Settings.bottom
        }
        CurveRegion {
            size: root.islandOut === 0 && island.joined ? 18 : 0
            x: island.x + island.width
            y: island.y + (Settings.bottom ? island.height - 18 : 0)
            flipY: Settings.bottom
        }
    }

    mask: Region {
        Region {
            item: catcher
        }
        Region {
            item: root.barShown && root.sideParts ? ribbon : null
        }
        Region {
            item: root.barShown && root.sideParts ? status : null
        }
        Region {
            item: root.barShown && root.layout === "rail" ? rail : null
        }
        Region {
            item: root.islandOut < 1 && !island.resting ? island.body : null
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

    Ribbon {
        id: ribbon

        x: root.sideGap
        y: (Settings.bottom ? parent.height - height - root.edgeGap : root.edgeGap) + root.edgeSign * root.ribbonOut * 46
        opacity: 1 - root.ribbonOut
        visible: root.ribbonOut < 1 && root.sideParts
        screenInfo: root.screen
    }

    // The rail layout's column. Focus mode sends it off the left edge.
    Rail {
        id: rail

        x: 10 - root.ribbonOut * 80
        y: 10
        height: parent.height - 20
        opacity: 1 - root.ribbonOut
        visible: root.layout === "rail" && root.ribbonOut < 1
        screenInfo: root.screen
    }

    StatusPill {
        id: status

        anchors.right: parent.right
        anchors.rightMargin: root.sideGap
        y: (Settings.bottom ? parent.height - height - root.edgeGap : root.edgeGap) + root.edgeSign * root.statusOut * 64
        opacity: Math.min(1, (1 - root.statusOut) * 3)
        visible: root.statusOut < 1 && root.sideParts
    }

    Island {
        id: island

        // Joined to the edge in the middle, floating a little below it, or beside the rail.
        x: root.layout === "rail" ? root.railRight : (parent.width - width) / 2
        y: Settings.bottom ? parent.height - height : root.layout === "falcon" ? 0 : root.layout === "halo" ? 8 : 10
        slide: root.islandOut
        visible: root.islandOut < 1
        output: root.screen ? root.screen.name : ""
        showDashboard: root.panelHere && Ui.popup === "dashboard"
        showControl: root.panelHere && Ui.popup === "control"
        onReleaseFocus: keyScope.forceActiveFocus()
    }

    // The studio layout's dashboard, grown out of the clock island into the middle of the screen.
    DashModal {
        id: dashModal

        anchors.fill: parent
        shown: root.layout === "studio" && root.panelHere && Ui.popup === "dashboard"
        from: Qt.rect(island.x, island.y, island.body.width, island.body.height)
    }

    // The studio layout's control center, along the right edge.
    ControlSidebar {
        id: sidebar

        shown: root.layout === "studio" && root.panelHere && Ui.popup === "control"
        onReleaseFocus: keyScope.forceActiveFocus()
    }

    TrayMenu {
        x: root.popupX(width)
        y: root.popupY(height)
        shown: root.panelHere && Ui.popup === "tray"
    }

    ClaudePanel {
        x: root.popupX(width)
        y: root.popupY(height)
        shown: root.panelHere && Ui.popup === "claude"
    }

    // The control center drops from the status pill, or, in the rail layout, comes up beside the
    // rail's status from below. The halo and studio layouts have their own.
    ControlCenter {
        id: control

        x: root.layout === "rail" ? root.railRight - (1 - reveal) * 24 : parent.width - width - 14
        y: root.layout === "rail" ? parent.height - height - 10 : Settings.bottom ? parent.height - height - 52 : 52
        growUp: Settings.bottom || root.layout === "rail"
        shown: (root.layout === "falcon" || root.layout === "rail") && root.panelHere && Ui.popup === "control"
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
