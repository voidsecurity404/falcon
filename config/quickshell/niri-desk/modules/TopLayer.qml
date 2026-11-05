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
    // In a frame the side panels hang from it, clear of its round corners. Otherwise they float.
    readonly property real edgeGap: Settings.framed ? Ui.frameSize : 10
    readonly property real sideGap: Settings.framed ? Ui.frameSize + 56 : 14
    readonly property real popupGap: 52 + Ui.frameSize
    property real ribbonOut: barShown ? 0 : 1
    property real statusOut: barShown ? 0 : 1
    property real islandOut: islandShown ? 0 : 1

    Behavior on ribbonOut {
        NumberAnimation {
            duration: root.barShown ? 460 : 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.barShown ? root.arriveCurve : root.leaveCurve
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
    WlrLayershell.namespace: "niri-desk-top"
    WlrLayershell.keyboardFocus: panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Faqat panellar orqasi xiralashadi, qolgan ekran toza qoladi.
    BackgroundEffect.blurRegion: Region {
        Region {
            item: Ui.frameSize > 0 ? frameArea : null

            Region {
                item: frameHole
                radius: frameHole.radius
                intersection: Intersection.Subtract
            }
        }
        Region {
            item: root.ribbonOut < 1 ? ribbon : null
            topLeftRadius: ribbon.topLeftRadius
            topRightRadius: ribbon.topRightRadius
            bottomLeftRadius: ribbon.bottomLeftRadius
            bottomRightRadius: ribbon.bottomRightRadius
        }
        CurveRegion {
            size: Settings.framed && root.ribbonOut < 1 ? 14 : 0
            x: ribbon.x - 14
            y: ribbon.y + (Settings.bottom ? ribbon.height - 14 : 0)
            flipX: true
            flipY: Settings.bottom
        }
        CurveRegion {
            size: Settings.framed && root.ribbonOut < 1 ? 14 : 0
            x: ribbon.x + ribbon.width
            y: ribbon.y + (Settings.bottom ? ribbon.height - 14 : 0)
            flipY: Settings.bottom
        }
        Region {
            item: root.statusOut < 1 ? status : null
            topLeftRadius: status.topLeftRadius
            topRightRadius: status.topRightRadius
            bottomLeftRadius: status.bottomLeftRadius
            bottomRightRadius: status.bottomRightRadius
        }
        CurveRegion {
            size: Settings.framed && root.statusOut < 1 ? 14 : 0
            x: status.x - 14
            y: status.y + (Settings.bottom ? status.height - 14 : 0)
            flipX: true
            flipY: Settings.bottom
        }
        CurveRegion {
            size: Settings.framed && root.statusOut < 1 ? 14 : 0
            x: status.x + status.width
            y: status.y + (Settings.bottom ? status.height - 14 : 0)
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
            size: root.islandOut === 0 ? 18 : 0
            x: island.x - 18
            y: island.y + (Settings.bottom ? island.height - 18 : 0)
            flipX: true
            flipY: Settings.bottom
        }
        CurveRegion {
            size: root.islandOut === 0 ? 18 : 0
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

    // The frame: one rectangle whose border is the strip. Its outer round corners lie off the screen.
    Rectangle {
        readonly property int beyond: 40

        x: -beyond
        y: -beyond
        width: parent.width + beyond * 2
        height: parent.height + beyond * 2
        visible: Ui.frameSize > 0
        opacity: Math.min(1, Ui.frameSize / 4)
        color: "transparent"
        border.width: Ui.frameSize + beyond
        border.color: Theme.glassTop
        radius: frameHole.radius + border.width
    }
    Item {
        id: frameArea

        anchors.fill: parent
    }
    Item {
        id: frameHole

        readonly property int radius: 20

        x: Ui.frameSize
        y: Ui.frameSize
        width: parent.width - Ui.frameSize * 2
        height: parent.height - Ui.frameSize * 2
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
        y: Settings.bottom ? parent.height - height - Ui.frameSize : Ui.frameSize
        slide: root.islandOut
        visible: root.islandOut < 1
        showDashboard: root.panelHere && Ui.popup === "dashboard"
    }

    TrayMenu {
        anchors.right: parent.right
        anchors.rightMargin: 14 + Ui.frameSize
        y: Settings.bottom ? parent.height - height - root.popupGap : root.popupGap
        shown: root.panelHere && Ui.popup === "tray"
    }

    ClaudePanel {
        anchors.right: parent.right
        anchors.rightMargin: 14 + Ui.frameSize
        y: Settings.bottom ? parent.height - height - root.popupGap : root.popupGap
        shown: root.panelHere && Ui.popup === "claude"
    }

    ControlCenter {
        id: control

        anchors.right: parent.right
        anchors.rightMargin: 14 + Ui.frameSize
        y: Settings.bottom ? parent.height - height - root.popupGap : root.popupGap
        shown: root.panelHere && Ui.popup === "control"
        onReleaseFocus: keyScope.forceActiveFocus()
    }
}
