import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Alt+Tab: recent windows spread like a hand of cards.
// niri gives no per-window picture to clients, so a card shows the window as it last looked
// on screen. Pictures are kept in memory-backed storage and go when the window closes.
PanelWindow {
    id: root

    // "" hidden, "wait" holds the keyboard while the current window is pictured,
    // "fan" shows the cards, "leave" plays the way out and takes no input.
    property string phase: ""
    property var items: []
    property int selected: 0
    property var pointerStart: null
    property bool pointerLive: false
    property var stamps: ({})
    property int wanted: -1
    property int shooting: -1

    readonly property int maxCards: 9
    readonly property real unit: (screen ? screen.height : 1080) / 720
    readonly property real cardWidth: 384 * unit
    readonly property real cardHeight: 216 * unit
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/niri-desk-switcher"
    readonly property bool capturable: phase === "" && Ui.popup === "" && !Ui.menuAlive && !Ui.pickerAlive && !Lock.active && !Lock.preview && !Niri.overview

    function recentWindows(sameApp) {
        const stamp = w => {
            const t = w.focus_timestamp;
            return t ? t.secs + t.nanos / 1e9 : 0;
        };
        const focused = Niri.windows[Niri.focusedWindowId];
        let list = Object.values(Niri.windows);
        if (sameApp && focused)
            list = list.filter(w => w.app_id === focused.app_id);
        // niri updates the time a moment after a focus change, so the focused window is put first by hand.
        return list.sort((a, b) => (b.id === Niri.focusedWindowId) - (a.id === Niri.focusedWindowId) || stamp(b) - stamp(a)).slice(0, maxCards);
    }

    // niri reports where floating windows are. A tiled one is only known when it fills the width.
    function windowRect(w) {
        const width = screen.width;
        const height = screen.height;
        const edge = Settings.get("windows.gaps", 16) + Settings.get("windows.edgeMargin", 0);
        const zone = Ui.zen ? 0 : 40;
        const top = Settings.bottom ? 0 : zone;
        const bottom = Settings.bottom ? zone : 0;
        const layout = w ? w.layout : null;
        const tile = layout ? layout.tile_size : null;
        if (w && w.is_floating && tile && layout.tile_pos_in_workspace_view) {
            const x = Math.max(0, Math.round(layout.tile_pos_in_workspace_view[0]));
            const y = Math.max(0, Math.round(layout.tile_pos_in_workspace_view[1]));
            return {
                x: x,
                y: y,
                w: Math.min(Math.round(tile[0]), width - x),
                h: Math.min(Math.round(tile[1]), height - y)
            };
        }
        if (tile && tile[0] >= width - 2 * edge - 2)
            return {
                x: Math.round((width - tile[0]) / 2),
                y: tile[1] >= height - 1 ? 0 : top + edge,
                w: Math.round(tile[0]),
                h: Math.round(tile[1])
            };
        return {
            x: 0,
            y: top,
            w: width,
            h: height - top - bottom
        };
    }

    function shotPath(id) {
        return shotDir + "/" + id + ".jpg";
    }

    function capture(id) {
        if (!Niri.windows[id] || !screen)
            return false;
        wanted = id;
        if (!shooter.running)
            startShot();
        return true;
    }

    function startShot() {
        const id = wanted;
        wanted = -1;
        const r = windowRect(Niri.windows[id]);
        shooting = id;
        shooter.command = ["sh", "-c", 'grim -t jpeg -q 82 -s 0.6 -g "$1" "$2.tmp" && mv -f "$2.tmp" "$2"', "sh", `${screen.x + r.x},${screen.y + r.y} ${r.w}x${r.h}`, shotPath(id)];
        shooter.running = true;
    }

    function step(amount, sameApp) {
        if (Lock.active)
            return;
        if (phase === "wait" || phase === "fan") {
            selected = (selected + amount + items.length) % items.length;
            autoConfirm.restart();
            return;
        }
        const list = recentWindows(sameApp);
        if (list.length < 2)
            return;
        leaveEnd.stop();
        Ui.popup = "";
        pointerStart = null;
        pointerLive = false;
        items = list;
        selected = amount > 0 ? 1 : list.length - 1;
        phase = "wait";
        keys.forceActiveFocus();
        autoConfirm.restart();
        showCap.restart();
        if (!capture(list[0].id))
            show();
    }

    function show() {
        showCap.stop();
        if (phase === "wait")
            phase = "fan";
    }

    function finish(confirm) {
        if (phase !== "wait" && phase !== "fan")
            return;
        const wasShown = phase === "fan";
        autoConfirm.stop();
        showCap.stop();
        const target = items[selected];
        if (confirm && target && target.id !== Niri.focusedWindowId)
            Niri.action("focus-window", "--id", String(target.id));
        if (!confirm)
            selected = 0;
        if (!wasShown) {
            hide();
            return;
        }
        phase = "leave";
        leaveEnd.restart();
    }

    function hide() {
        leaveEnd.stop();
        phase = "";
        items = [];
    }

    // A card left under the pointer stays unselected until the pointer has really moved.
    function pointerMoved(index, point) {
        if (!pointerStart)
            pointerStart = point;
        else if (Math.abs(pointerStart.x - point.x) + Math.abs(pointerStart.y - point.y) > 3)
            pointerLive = true;
        if (pointerLive && selected !== index) {
            selected = index;
            autoConfirm.restart();
        }
    }

    function report() {
        Ui.switcherPhase = phase;
        Ui.switcherSelected = selected;
        Ui.switcherRows = items.map(w => w.app_id || "");
    }

    onPhaseChanged: report()
    onSelectedChanged: report()
    onItemsChanged: report()

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'rm -rf "$1"; mkdir -m 700 -p "$1"', "sh", shotDir])

    visible: phase !== ""
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niri-desk-switcher"
    WlrLayershell.keyboardFocus: phase === "wait" || phase === "fan" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: phase === "leave" ? noInput : allInput

    Region {
        id: noInput
    }
    Region {
        id: allInput

        item: keys
    }

    Connections {
        target: Ui
        function onSwitcherStep(amount, sameApp) {
            root.step(amount, sameApp);
        }
        function onSwitcherEnd(confirm) {
            root.finish(confirm);
        }
    }

    Connections {
        target: Niri
        function onFocusedWindowIdChanged() {
            settle.restart();
        }
        function onWindowGone(id) {
            Quickshell.execDetached(["rm", "-f", root.shotPath(id)]);
            const next = Object.assign({}, root.stamps);
            delete next[id];
            root.stamps = next;
        }
    }

    // Waits for niri's movement to end, so a window is pictured where it came to rest.
    Timer {
        id: settle

        interval: 450
        onTriggered: {
            if (root.capturable)
                root.capture(Niri.focusedWindowId);
        }
    }

    // A very quick tap can release Alt before this window has the keyboard, and then no release
    // ever arrives. This keeps the switcher from holding the keyboard forever.
    Timer {
        id: autoConfirm

        interval: 2500
        onTriggered: root.finish(true)
    }

    Timer {
        id: showCap

        interval: 200
        onTriggered: root.show()
    }

    Timer {
        id: leaveEnd

        interval: 210
        onTriggered: root.hide()
    }

    Process {
        id: shooter

        onExited: code => {
            if (code === 0) {
                const next = Object.assign({}, root.stamps);
                next[root.shooting] = Date.now();
                root.stamps = next;
            }
            root.shooting = -1;
            if (root.wanted >= 0)
                root.startShot();
            else if (root.phase === "wait")
                root.show();
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onReleased: event => {
            if ((event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr) && !event.isAutoRepeat)
                root.finish(true);
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                root.finish(false);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.finish(true);
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                root.step(1, false);
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                root.step(-1, false);
            else
                return;
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: "#05080c"
            opacity: root.phase === "fan" ? 0.66 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.phase === "leave" ? 190 : 240
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.finish(false)
            }
        }

        Repeater {
            model: root.items

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                readonly property int count: root.items.length
                readonly property bool on: index === root.selected
                // Cards keep the same curve however many there are.
                readonly property real spacing: Math.min(170, 320 / Math.max(0.5, (count - 1) / 2))
                readonly property real spread: (index - (count - 1) / 2) * spacing / 128
                readonly property real unit: root.unit
                property bool entered: false
                readonly property int stage: root.phase === "leave" ? 2 : (root.phase === "fan" && entered ? 1 : 0)

                // Cards open from a loose stack. On leaving nothing flies: the chosen card lifts
                // slightly and melts away while niri brings the real window in underneath.
                readonly property real goX: stage === 0 ? spread * 46 * unit : spread * 128 * unit
                readonly property real goY: {
                    const fan = (spread * spread * 12 + 105 - (on ? 115 : 0)) * unit;
                    if (stage === 0)
                        return (spread * spread * 4 + 125) * unit;
                    return stage === 2 && !on ? fan + 18 * unit : fan;
                }
                readonly property real goAngle: stage === 0 ? spread * 2.5 : spread * 7
                readonly property real goScale: stage === 0 ? 0.94 : stage === 2 ? (on ? 1.27 : 0.97) : (on ? 1.22 : 1)

                visible: root.phase !== "wait"
                width: root.cardWidth
                height: root.cardHeight
                x: (root.width - width) / 2 + goX
                y: (root.height - height) / 2 + goY
                rotation: goAngle
                scale: goScale
                opacity: stage === 1 ? 1 : 0
                z: on ? 100 : 50 - Math.abs(index - root.selected)
                antialiasing: true

                Behavior on x {
                    SpringAnimation {
                        spring: 3.4
                        damping: 0.42
                        epsilon: 0.2
                    }
                }
                Behavior on y {
                    SpringAnimation {
                        spring: 3.4
                        damping: 0.42
                        epsilon: 0.2
                    }
                }
                Behavior on rotation {
                    SpringAnimation {
                        spring: 3.4
                        damping: 0.42
                        epsilon: 0.05
                    }
                }
                Behavior on scale {
                    SpringAnimation {
                        spring: 3.4
                        damping: 0.42
                        epsilon: 0.002
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: card.stage === 2 ? (card.on ? 185 : 130) : 170
                        easing.type: Easing.OutCubic
                    }
                }

                Timer {
                    interval: 1 + card.index * 28
                    running: root.phase === "fan"
                    onTriggered: card.entered = true
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 8 * card.unit
                    color: Theme.surface
                    antialiasing: true

                    IconImage {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 12 * card.unit
                        implicitSize: 64 * card.unit
                        source: Quickshell.iconPath(card.entry ? card.entry.icon : (card.modelData.app_id || ""), true)
                        visible: shot.status !== Image.Ready
                    }
                    Image {
                        id: shot

                        anchors.fill: parent
                        anchors.topMargin: bar.height
                        source: root.stamps[card.modelData.id] ? "file://" + root.shotPath(card.modelData.id) + "?" + root.stamps[card.modelData.id] : ""
                        asynchronous: true
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        verticalAlignment: Image.AlignTop
                        smooth: true
                    }
                    Rectangle {
                        id: bar

                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 24 * card.unit
                        color: Theme.surface

                        IconImage {
                            id: barIcon

                            anchors.left: parent.left
                            anchors.leftMargin: 8 * card.unit
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 14 * card.unit
                            source: Quickshell.iconPath(card.entry ? card.entry.icon : (card.modelData.app_id || ""), true)
                        }
                        Label {
                            anchors.left: barIcon.right
                            anchors.leftMargin: 6 * card.unit
                            anchors.right: parent.right
                            anchors.rightMargin: 8 * card.unit
                            anchors.verticalCenter: parent.verticalCenter
                            size: 9 * card.unit
                            text: card.modelData.title || card.modelData.app_id || ""
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "#05080c"
                        opacity: card.on ? 0 : 0.24

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 180
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 8 * card.unit
                    color: "transparent"
                    antialiasing: true
                    border.width: card.on ? 2.5 : 1
                    border.color: card.on && card.stage === 1 ? Theme.accent : Qt.alpha(Theme.text, 0.18)
                }
                readonly property var entry: DesktopEntries.heuristicLookup(modelData.app_id || "")

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: mouse => root.pointerMoved(card.index, mapToItem(keys, mouse.x, mouse.y))
                    onClicked: {
                        root.selected = card.index;
                        root.finish(true);
                    }
                }
            }
        }
    }
}
