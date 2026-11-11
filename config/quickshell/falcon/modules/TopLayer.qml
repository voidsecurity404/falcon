import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Butun ekranni egallaydigan shaffof qatlam. Bosishlar faqat mask ichidagi elementlarga tushadi,
// panel ochiq bo'lganda catcher ekranning qolgan qismidagi bosishni ham ushlab panelni yopadi.
// The bar is three glass islands floating under the top edge: workspaces and the focused window
// on the left, resources, clock and music in the middle (the island that grows into the dashboard
// and shows messages), tools, tray and status on the right (the control center drops under it).
PanelWindow {
    id: root

    readonly property bool isFocusedScreen: !!screen && (Niri.focusedOutput === "" || Niri.focusedOutput === screen.name)
    readonly property bool panelHere: Ui.topPanelOpen && isFocusedScreen
    // Focus mode sends the bar off the screen. The middle island still comes back for the
    // dashboard and for the way-out hint. Each part has its own distance out, 0 is in place.
    readonly property bool barShown: !Ui.zen
    readonly property bool islandShown: !Ui.zen || (panelHere && Ui.popup === "dashboard") || (!!Toasts.current && Toasts.current.inZen === true)
    readonly property var leaveCurve: [0.4, 0, 0.9, 0.3, 1, 1]
    readonly property var arriveCurve: [0.25, 1.25, 0.35, 1, 1, 1]
    readonly property int edgeGap: 8
    readonly property int sideGap: 10
    // Where the popups under the right island start.
    readonly property int popupTop: edgeGap + right.height + 8

    // Small popups (tray menu, Claude limits) open under the right island.
    function popupX(w) {
        return width - w - sideGap;
    }
    function popupY(h) {
        return popupTop;
    }

    // The wheel anywhere on the bar: brightness on the left half of the screen, volume on the
    // right half, as on end-4's bar.
    function scrollAt(x, step) {
        if (x < width / 2) {
            if (Brightness.available)
                Brightness.step(step > 0 ? "5%+" : "5%-");
        } else if (Audio.available) {
            Audio.setVolume(Math.round(Audio.volume * 100 + step * 5) / 100);
        }
    }

    // The dashboard grows out of the middle island. On a screen too narrow for it and a side
    // island together, that side island fades away while the dashboard is open.
    readonly property real dashLeft: (width - 1160) / 2
    readonly property bool leftCovered: island.mode === "dashboard" && dashLeft < sideGap + left.implicitWidth + 8
    readonly property bool rightCovered: island.mode === "dashboard" && dashLeft < sideGap + right.implicitWidth + 8
    property real leftFade: leftCovered ? 1 : 0
    property real rightFade: rightCovered ? 1 : 0

    Behavior on leftFade {
        NumberAnimation {
            duration: 200
        }
    }
    Behavior on rightFade {
        NumberAnimation {
            duration: 200
        }
    }

    // Where the islands are and what they show, for `desk state` and the tests.
    function report() {
        const rect = item => [Math.round(item.x), Math.round(item.y), Math.round(item.width), Math.round(item.height)];
        return {
            left: rect(left),
            center: rect(island.body),
            centerX: Math.round(island.x),
            right: rect(right),
            control: rect(control),
            dots: left.shownDots,
            leftShown: left.visible && left.opacity > 0.5,
            rightShown: right.visible && right.opacity > 0.5,
            title: left.focused ? left.focused.title || left.focused.app_id : "",
            mode: island.mode,
            media: island.showMedia,
            resources: island.showResources,
            screen: [width, height],
            items: named()
        };
    }
    // Window coordinates of every visible named part of the bar.
    function named() {
        const found = {};
        const walk = item => {
            if (!item || !item.visible)
                return;
            if (item.objectName !== "") {
                const p = item.mapToItem(null, 0, 0);
                found[item.objectName] = [Math.round(p.x), Math.round(p.y), Math.round(item.width), Math.round(item.height)];
            }
            for (const child of item.children)
                walk(child);
        };
        walk(left);
        walk(island);
        walk(right);
        return found;
    }
    onIsFocusedScreenChanged: {
        if (isFocusedScreen)
            Ui.barLayer = root;
    }
    Component.onCompleted: {
        if (isFocusedScreen)
            Ui.barLayer = root;
    }

    property real leftOut: barShown ? 0 : 1
    property real rightOut: barShown ? 0 : 1
    property real islandOut: islandShown ? 0 : 1

    // A calm settle with no bounce, and it starts just off the screen, so all of the way is seen.
    Behavior on leftOut {
        NumberAnimation {
            duration: root.barShown ? 640 : 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.barShown ? [0.22, 0.61, 0.36, 1, 1, 1] : root.leaveCurve
        }
    }
    Behavior on rightOut {
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
            item: left.visible && left.opacity > 0.05 ? left : null
            radius: left.radius
        }
        Region {
            item: right.visible && right.opacity > 0.05 ? right : null
            radius: right.radius
        }
        Region {
            item: root.islandOut === 1 || island.body.opacity < 0.05 ? null : island.body
            radius: island.body.animatedRadius
        }
    }

    mask: Region {
        Region {
            item: catcher
        }
        Region {
            item: root.barShown && root.leftFade < 1 ? left : null
        }
        Region {
            item: root.barShown && root.rightFade < 1 ? right : null
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

    GlassLeft {
        id: left

        x: root.sideGap
        y: root.edgeGap - root.leftOut * 60
        opacity: (1 - root.leftOut) * (1 - root.leftFade)
        visible: root.leftOut < 1 && root.leftFade < 1
        screenInfo: root.screen
        onScrolled: (x, step) => root.scrollAt(left.x + x, step)
    }

    GlassRight {
        id: right

        anchors.right: parent.right
        anchors.rightMargin: root.sideGap
        y: root.edgeGap - root.rightOut * 60
        opacity: Math.min(1, (1 - root.rightOut) * 3) * (1 - root.rightFade)
        visible: root.rightOut < 1 && root.rightFade < 1
        onScrolled: (x, step) => root.scrollAt(right.x + x, step)
    }

    Island {
        id: island

        x: Math.round((parent.width - width) / 2)
        y: root.edgeGap
        slide: root.islandOut
        visible: root.islandOut < 1
        showDashboard: root.panelHere && Ui.popup === "dashboard"
        onReleaseFocus: keyScope.forceActiveFocus()
        onScrolled: (x, step) => root.scrollAt(island.x + x, step)
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

    // The control center drops from the right island.
    ControlCenter {
        id: control

        x: parent.width - width - root.sideGap
        y: root.popupTop
        shown: root.panelHere && Ui.popup === "control"
        onReleaseFocus: keyScope.forceActiveFocus()
    }
}
