import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Butun ekranni egallaydigan shaffof qatlam. Bosishlar faqat mask ichidagi elementlarga tushadi,
// panel ochiq bo'lganda catcher ekranning qolgan qismidagi bosishni ham ushlab panelni yopadi.
// The bar is three glass islands floating under the top edge: workspaces and the focused window
// on the left, resources, clock and music in the middle, tools, tray and status on the right. Each
// part opens its own small menu under it. Notifications come as cards under the right island and
// fly into the bell; volume and brightness levels show in a pill under the middle island.
PanelWindow {
    id: root

    readonly property bool isFocusedScreen: !!screen && (Niri.focusedOutput === "" || Niri.focusedOutput === screen.name)
    readonly property bool panelHere: Ui.topPanelOpen && isFocusedScreen
    // Focus mode sends the bar off the screen.
    readonly property bool barShown: !Ui.zen
    readonly property var leaveCurve: [0.4, 0, 0.9, 0.3, 1, 1]
    readonly property var arriveCurve: [0.25, 1.25, 0.35, 1, 1, 1]
    readonly property int edgeGap: 8
    readonly property int sideGap: 10
    // Where the menus under the bar start.
    readonly property int popupTop: edgeGap + 42 + 8

    // Small popups (tray menu, Claude limits) open under the right island.
    function popupX(w) {
        return width - w - sideGap;
    }
    function popupY(h) {
        return popupTop;
    }
    // A menu centered under a part of the bar, kept on the screen. The middle island's place and
    // size are read so the binding follows them.
    function under(part, w, follow) {
        const middle = part.mapToItem(null, part.width / 2, 0).x;
        return Math.max(sideGap, Math.min(width - w - sideGap, Math.round(middle - w / 2)));
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

    // Where the islands are and what they show, for `desk state` and the tests.
    function report() {
        const rect = item => [Math.round(item.x), Math.round(item.y), Math.round(item.width), Math.round(item.height)];
        const menus = {
            calendar: calendar,
            player: player,
            system: system,
            notifications: notifications,
            control: control
        };
        return {
            left: rect(left),
            center: rect(center),
            centerX: Math.round(center.x),
            right: rect(right),
            control: rect(control),
            menu: menus[Ui.popup] ? rect(menus[Ui.popup]) : null,
            card: card.visible ? rect(card) : null,
            cardFlying: card.flying,
            level: levelPill.visible,
            dots: left.shownDots,
            leftShown: left.visible && left.opacity > 0.5,
            centerShown: center.visible && center.opacity > 0.5,
            rightShown: right.visible && right.opacity > 0.5,
            title: left.focused ? left.focused.title || left.focused.app_id : "",
            media: center.showMedia,
            resources: center.showResources,
            screen: [width, height],
            items: named()
        };
    }
    // Window coordinates of every visible named part of the bar and its menus.
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
        for (const part of [left, center, right, calendar, player, system, notifications])
            walk(part);
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
    property real centerOut: barShown ? 0 : 1
    property real rightOut: barShown ? 0 : 1

    // A calm settle with no bounce, and it starts just off the screen, so all of the way is seen.
    Behavior on leftOut {
        NumberAnimation {
            duration: root.barShown ? 640 : 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.barShown ? [0.22, 0.61, 0.36, 1, 1, 1] : root.leaveCurve
        }
    }
    Behavior on centerOut {
        NumberAnimation {
            duration: root.barShown ? 460 : 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.barShown ? [0.2, 0, 0, 1, 1, 1] : root.leaveCurve
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
            item: left.visible && left.opacity > 0.05 ? left : null
            radius: left.radius
        }
        Region {
            item: center.visible && center.opacity > 0.05 ? center : null
            radius: center.radius
        }
        Region {
            item: right.visible && right.opacity > 0.05 ? right : null
            radius: right.radius
        }
        Region {
            item: control.visible ? control : null
            radius: control.radius
        }
        Region {
            item: calendar.visible ? calendar : null
            radius: calendar.radius
        }
        Region {
            item: player.visible ? player : null
            radius: player.radius
        }
        Region {
            item: system.visible ? system : null
            radius: system.radius
        }
        Region {
            item: notifications.visible ? notifications : null
            radius: notifications.radius
        }
        Region {
            item: card.visible && card.opacity > 0.05 ? card : null
            radius: card.radius
        }
        Region {
            item: levelPill.visible ? levelPill : null
            radius: levelPill.radius
        }
    }

    mask: Region {
        Region {
            item: catcher
        }
        Region {
            item: root.barShown ? left : null
        }
        Region {
            item: root.barShown ? center : null
        }
        Region {
            item: root.barShown ? right : null
        }
        Region {
            item: card.visible && !card.flying ? card : null
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
        opacity: 1 - root.leftOut
        visible: root.leftOut < 1
        screenInfo: root.screen
        onScrolled: (x, step) => root.scrollAt(left.x + x, step)
    }

    GlassCenter {
        id: center

        x: Math.round((parent.width - width) / 2)
        y: root.edgeGap - root.centerOut * 60
        opacity: 1 - root.centerOut
        visible: root.centerOut < 1
        onScrolled: (x, step) => root.scrollAt(center.x + x, step)
    }

    GlassRight {
        id: right

        anchors.right: parent.right
        anchors.rightMargin: root.sideGap
        y: root.edgeGap - root.rightOut * 60
        opacity: Math.min(1, (1 - root.rightOut) * 3)
        visible: root.rightOut < 1
        onScrolled: (x, step) => root.scrollAt(right.x + x, step)
    }

    LevelPill {
        id: levelPill

        x: Math.round((parent.width - width) / 2)
        restY: root.popupTop
    }

    // Notifications, under the right island. They fly into the bell when their time is up.
    NotifyCard {
        id: card

        restX: parent.width - cardWidth - root.sideGap
        restY: root.popupTop
        bell: {
            const b = right.bellItem;
            const follow = right.x + right.width;
            return b.mapToItem(null, b.width / 2, b.height / 2);
        }
        bellSeen: right.visible && right.opacity > 0.5 && root.isFocusedScreen
        allowed: root.isFocusedScreen && !(root.panelHere && Ui.popup === "notifications") && (!Ui.zen || (!!Toasts.current && Toasts.current.inZen === true))
    }

    CalendarMenu {
        id: calendar

        x: root.under(center.clockItem, width, center.x + center.width)
        y: root.popupTop
        shown: root.panelHere && Ui.popup === "calendar"
    }

    PlayerMenu {
        id: player

        x: root.under(center.showMedia ? center.mediaItem : center.clockItem, width, center.x + center.width)
        y: root.popupTop
        shown: root.panelHere && Ui.popup === "player"
    }

    SystemMenu {
        id: system

        x: root.under(center.ringsItem, width, center.x + center.width)
        y: root.popupTop
        shown: root.panelHere && Ui.popup === "system"
    }

    NotificationsMenu {
        id: notifications

        x: parent.width - width - root.sideGap
        y: root.popupTop
        shown: root.panelHere && Ui.popup === "notifications"
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
