import QtQuick
import Quickshell
import Quickshell.Wayland
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
    // Bar parts in the corners have their border just off the screen.
    readonly property int edgeGap: Settings.hug ? -1 : 10
    readonly property int sideGap: Settings.hug ? -1 : 14
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
            item: root.ribbonOut < 1 ? ribbon : null
            topLeftRadius: ribbon.topLeftRadius
            topRightRadius: ribbon.topRightRadius
            bottomLeftRadius: ribbon.bottomLeftRadius
            bottomRightRadius: ribbon.bottomRightRadius
        }
        Region {
            item: root.statusOut < 1 ? status : null
            topLeftRadius: status.topLeftRadius
            topRightRadius: status.topRightRadius
            bottomLeftRadius: status.bottomLeftRadius
            bottomRightRadius: status.bottomRightRadius
        }
        Region {
            item: root.islandOut === 1 ? null : island.body
            bottomLeftRadius: island.bottomRadius
            bottomRightRadius: island.bottomRadius
            topLeftRadius: island.topRadius
            topRightRadius: island.topRadius
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
        y: Settings.hug ? (Settings.bottom ? parent.height - height : 0) : (Settings.bottom ? parent.height - height - 10 : 10)
        slide: root.islandOut
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
}
