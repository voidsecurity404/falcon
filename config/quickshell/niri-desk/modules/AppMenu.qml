import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services
import "../services/tools.js" as Tools

// App menu: rises from the bottom center of the screen. Typing searches apps, and ">" lists
// commands, ">wallpaper" among them. The session buttons sit beside the search field.
// The window stays built between openings, so it opens at once with its icons ready.
PanelWindow {
    id: root

    readonly property bool closing: Ui.popup !== "menu"
    // A panel at the bottom takes the edge, so the menu floats above it.
    readonly property int edgeGap: Settings.bottom ? 56 : 0
    // The card reaches this far below the edge, so its overshoot never lifts it off the screen.
    readonly property int overdraw: Settings.bottom ? 0 : 28
    readonly property int rowHeight: 54
    readonly property int maxRows: 7
    readonly property int padding: 12
    readonly property size wallCard: Qt.size(180, 210)
    readonly property var emphasized: [0.2, 0, 0, 1, 1, 1]

    property string query: ""
    property int selected: 0
    property int wallSelected: 0
    property real reveal: 0
    // Drives the rows and buttons that follow the card on opening, 0 to 1.
    property real stagger: 0
    // The pointer counts once it has really moved: a row left under it stays unselected at first.
    property var pointerStart: null
    property bool pointerLive: false
    property real wheelRest: 0
    // The wallpaper as it was when the row of pictures opened, and the one being tried instead.
    property string wallStartImage: ""
    property string wallStartLive: ""
    property string wallTried: ""
    // Runs of the wallpaper script go one at a time, the last wish wins.
    property string wallWanted: ""
    property string wallDone: ""
    // Dangerous actions need a second press, this holds the first one.
    property string armed: ""
    property string hoveredSession: ""

    readonly property bool commandMode: query[0] === ">" || query[0] === "Ю"
    readonly property string commandText: commandMode ? query.slice(1).replace(/^\s+/, "") : ""
    readonly property string commandWord: commandText.split(/\s+/)[0]
    readonly property string commandRest: commandText.slice(commandWord.length).trim()
    readonly property bool wallpaperMode: commandMode && wordIs(["wallpaper", "обои"])
    readonly property bool schemeMode: commandMode && wordIs(["scheme", "стиль"]) && commandText.length > commandWord.length
    readonly property bool calcMode: commandMode && wordIs(["calc", "счёт", "счет"]) && commandText.length > commandWord.length
    readonly property string mode: wallpaperMode ? "wallpaper" : calcMode ? "calc" : schemeMode ? "scheme" : commandMode ? "commands" : "apps"

    // What is on screen follows the text. A change of mode first fades the old content away.
    property string shownMode: "apps"
    property var shownRows: []
    property var shownIds: []
    property var rowsById: ({})
    property real viewFade: 1
    readonly property bool shownWide: shownMode === "wallpaper"

    readonly property var session: [
        {
            id: "lock",
            icon: "lock",
            name: Tr.t("Lock screen"),
            keywords: "lock блокировка",
            confirm: false,
            run: () => Quickshell.execDetached(["loginctl", "lock-session"])
        },
        {
            id: "sleep",
            icon: "moon",
            name: Tr.t("Sleep"),
            keywords: "sleep suspend сон",
            confirm: false,
            run: () => Quickshell.execDetached(["systemctl", "suspend"])
        },
        {
            id: "logout",
            icon: "logout",
            name: Tr.t("Log out"),
            keywords: "logout quit выход",
            confirm: true,
            run: () => Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"])
        },
        {
            id: "reboot",
            icon: "reboot",
            name: Tr.t("Reboot"),
            keywords: "reboot restart перезагрузка",
            confirm: true,
            run: () => Quickshell.execDetached(["systemctl", "reboot"])
        },
        {
            id: "power",
            icon: "power",
            name: Tr.t("Shut down"),
            keywords: "shutdown poweroff выключение",
            confirm: true,
            run: () => Quickshell.execDetached(["systemctl", "poweroff"])
        }
    ]

    readonly property var commands: [
        {
            id: "wallpaper",
            icon: "wallpaper",
            name: Tr.t("Change wallpaper"),
            detail: Tr.t("Choose from your pictures"),
            keywords: "wallpaper обои",
            complete: "wallpaper "
        },
        {
            id: "random",
            icon: "sparkle",
            name: Tr.t("Random wallpaper"),
            detail: Tr.t("Pick one for me"),
            keywords: "random случайные обои",
            run: () => root.randomWallpaper()
        },
        {
            id: "scheme",
            icon: "palette",
            name: Tr.t("Color style"),
            detail: Tr.t("How colors come from the wallpaper"),
            keywords: "scheme стиль цвет",
            complete: "scheme "
        },
        {
            id: "light",
            icon: "sun",
            name: Tr.t("Light"),
            detail: Tr.t("Mode"),
            keywords: "light светлый",
            run: () => Settings.set("appearance.mode", "light")
        },
        {
            id: "dark",
            icon: "moon",
            name: Tr.t("Dark"),
            detail: Tr.t("Mode"),
            keywords: "dark тёмный темный",
            run: () => Settings.set("appearance.mode", "dark")
        },
        {
            id: "calc",
            icon: "chip",
            name: Tr.t("Calculator"),
            detail: Tr.t("Enter: copy"),
            keywords: "calc счёт счет",
            complete: "calc "
        },
        {
            id: "settings",
            icon: "settings",
            name: Tr.t("Settings"),
            detail: "Mod+,",
            keywords: "settings настройки",
            run: () => Ui.settingsOpen = true
        }
    ].concat(session.map(s => Object.assign({
            detail: Tr.t("System")
        }, s)))

    readonly property var schemes: [["scheme-tonal-spot", "Tonal"], ["scheme-vibrant", "Vibrant"], ["scheme-expressive", "Expressive"], ["scheme-fidelity", "Faithful"], ["scheme-content", "Content"], ["scheme-neutral", "Neutral"], ["scheme-monochrome", "Monochrome"], ["scheme-rainbow", "Rainbow"], ["scheme-fruit-salad", "Fruit salad"]]

    // Pictures only: live wallpapers are chosen in the picker, Mod+W.
    readonly property var wallFiles: {
        const key = commandRest.toLowerCase();
        const all = Wallpapers.imageFiles;
        return key === "" ? all : all.filter(path => Tools.score(Wallpapers.nameOf(path), key, "") > 0);
    }

    // One row object per app, built once: searching only chooses among them.
    readonly property var appEntries: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name)).map(entry => ({
                id: "app:" + entry.id,
                image: Quickshell.iconPath(entry.icon, true),
                icon: "windows",
                name: entry.name,
                detail: entry.comment || entry.genericName || "",
                extra: entry.genericName + " " + entry.keywords.join(" "),
                run: () => entry.execute()
            }))

    readonly property var results: {
        if (wallpaperMode)
            return [];
        if (calcMode)
            return calcRows();
        if (schemeMode)
            return schemeRows();
        if (commandMode)
            return ranked(commands, c => c.name, c => c.keywords, commandText.toLowerCase());
        return ranked(appEntries, a => a.name, a => a.extra, query.trim().toLowerCase());
    }

    function wordIs(names) {
        const word = commandWord.toLowerCase();
        return names.indexOf(word) >= 0 || names.indexOf(Tools.swapLayout(word)) >= 0;
    }

    // Keeps the original order on ties. An exact match hides guesses from scattered letters.
    function ranked(items, nameOf, extraOf, q) {
        const rows = items.map((item, order) => ({
                    item: item,
                    order: order,
                    rank: Tools.score(nameOf(item), q, extraOf(item))
                })).filter(r => r.rank > 0).sort((a, b) => b.rank - a.rank || a.order - b.order);
        const exact = rows.some(r => r.rank >= 300);
        return rows.filter(r => !exact || r.rank >= 300).map(r => r.item);
    }

    function schemeRows() {
        const key = commandRest.toLowerCase();
        const current = Settings.get("appearance.scheme", "");
        const rows = schemes.map(s => ({
                    id: s[0],
                    icon: s[0] === current ? "check" : "palette",
                    name: Tr.t(s[1]),
                    detail: "",
                    run: () => Settings.set("appearance.scheme", s[0])
                }));
        return ranked(rows, r => r.name, r => r.id, key);
    }

    function calcRows() {
        let value = "";
        try {
            value = commandRest === "" ? "" : Tools.calc(commandRest);
        } catch (e) {
            value = "";
        }
        return [
            {
                id: "result",
                icon: "chip",
                name: value || Tr.t("incomplete expression"),
                detail: Tr.t("Enter: copy"),
                run: () => {
                    if (!value)
                        return;
                    Quickshell.clipboardText = value;
                    Toasts.show(Tr.t("Copied"), value, "check");
                }
            }
        ];
    }

    function randomWallpaper() {
        const all = Wallpapers.imageFiles.filter(path => path !== Wallpapers.currentImage);
        if (all.length > 0)
            setWallpaper(all[Math.floor(Math.random() * all.length)]);
    }

    function runWallpaper(path) {
        wallWanted = path;
        if (!wallProcess.running)
            startWallpaper();
    }

    function startWallpaper() {
        wallDone = wallWanted;
        wallProcess.command = [Ui.binDir + "niri-desk-wallpaper", wallDone];
        wallProcess.running = true;
    }

    // Enter or a click: this picture stays.
    function setWallpaper(path) {
        tryTimer.stop();
        if (path !== wallTried) {
            Wallpapers.chosen(path, false);
            runWallpaper(path);
        }
        wallTried = "";
        Ui.popup = "";
    }

    // Moving with the arrows or the wheel puts the picture on the screen.
    function stepWall(by) {
        wallSelected = Math.max(0, Math.min(wallFiles.length - 1, wallSelected + by));
        tryTimer.restart();
    }

    // Esc, a click outside or leaving >wallpaper gives back what was there.
    function undoWallTry() {
        tryTimer.stop();
        if (wallTried === "")
            return;
        wallTried = "";
        Wallpapers.chosen(wallStartLive || wallStartImage, wallStartLive !== "");
        runWallpaper(wallStartLive || wallStartImage);
    }

    function startWallpapers() {
        Wallpapers.refresh();
        wallStartImage = Wallpapers.currentImage;
        wallStartLive = Wallpapers.currentLive;
        wallSelected = Math.max(0, wallFiles.indexOf(Wallpapers.currentImage));
        wallView.positionViewAtIndex(wallSelected, ListView.Center);
    }

    function runSession(item) {
        if (item.confirm && armed !== item.id) {
            armed = item.id;
            disarm.restart();
            return;
        }
        armed = "";
        Ui.popup = "";
        item.run();
    }

    function execute(index) {
        if (wallpaperMode) {
            if (wallFiles[wallSelected])
                setWallpaper(wallFiles[wallSelected]);
            return;
        }
        const item = results[index];
        if (!item)
            return;
        if (item.complete) {
            input.text = ">" + item.complete;
            return;
        }
        // A click or Enter in the list counts the same as a session button.
        if (item.confirm !== undefined) {
            runSession(item);
            return;
        }
        Ui.popup = "";
        item.run();
    }

    function pointerMoved(point) {
        if (pointerLive)
            return true;
        if (!pointerStart)
            pointerStart = point;
        else if (Math.abs(pointerStart.x - point.x) + Math.abs(pointerStart.y - point.y) > 3)
            pointerLive = true;
        return pointerLive;
    }

    // Gives whole steps from a mouse wheel notch or from many small touchpad deltas.
    function wheelSteps(delta) {
        wheelRest += delta;
        const steps = Math.trunc(wheelRest / 120);
        wheelRest -= steps * 120;
        return -steps;
    }

    // How far along an item with this delay is. Bindings on it follow `stagger`.
    function progress(delay) {
        const t = Math.max(0, Math.min(1, (stagger * 1.6 - delay) / 0.6));
        return 1 - Math.pow(1 - t, 3);
    }

    function syncRows() {
        const map = Object.assign({}, rowsById);
        for (const row of results)
            map[row.id] = row;
        rowsById = map;
        shownRows = results;
        shownIds = results.map(r => r.id);
        shownMode = mode;
        Ui.launcherRows = results.map(r => r.name);
    }

    function clearForNextTime() {
        modeSwap.stop();
        input.text = "";
        armed = "";
        hoveredSession = "";
        pointerStart = null;
        pointerLive = false;
        selected = 0;
        viewFade = 1;
        syncRows();
        list.positionViewAtBeginning();
    }

    onClosingChanged: {
        if (closing) {
            undoWallTry();
            fadeIn.stop();
            staggerIn.stop();
            fadeOut.start();
        } else {
            fadeOut.stop();
            input.forceActiveFocus();
            fadeIn.start();
            stagger = 0;
            staggerIn.start();
        }
    }
    onQueryChanged: {
        selected = 0;
        armed = "";
    }
    onModeChanged: modeSwap.restart()
    onWallpaperModeChanged: {
        if (!wallpaperMode)
            undoWallTry();
    }
    onResultsChanged: {
        if (mode === shownMode && !modeSwap.running)
            syncRows();
    }
    onSelectedChanged: Ui.launcherSelected = selected
    onWallFilesChanged: wallSelected = Math.min(wallSelected, Math.max(0, wallFiles.length - 1))
    Component.onCompleted: syncRows()

    visible: Ui.menuAlive
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
    WlrLayershell.namespace: "niri-desk-menu"
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    mask: Region {
        item: catcher
    }
    BackgroundEffect.blurRegion: Region {
        item: card
        topLeftRadius: card.topLeftRadius
        topRightRadius: card.topRightRadius
        bottomLeftRadius: card.bottomLeftRadius
        bottomRightRadius: card.bottomRightRadius
    }

    Connections {
        target: Ui
        function onLauncherInject(text) {
            input.text = text;
        }
    }

    SequentialAnimation {
        id: fadeIn

        // The surface reaches the screen a moment after it is mapped.
        PauseAnimation {
            duration: 30
        }
        NumberAnimation {
            target: root
            property: "reveal"
            to: 1
            duration: 480
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }
    }
    NumberAnimation {
        id: staggerIn

        target: root
        property: "stagger"
        to: 1
        duration: 560
    }
    SequentialAnimation {
        id: fadeOut

        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: 230
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
        }
        ScriptAction {
            script: {
                root.stagger = 0;
                root.clearForNextTime();
                Ui.menuAlive = false;
            }
        }
    }
    SequentialAnimation {
        id: modeSwap

        NumberAnimation {
            target: root
            property: "viewFade"
            to: 0
            duration: 90
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                root.syncRows();
                if (root.wallpaperMode)
                    root.startWallpapers();
            }
        }
        NumberAnimation {
            target: root
            property: "viewFade"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    Timer {
        id: tryTimer

        // Passing over pictures quickly only shows the one you stop at.
        interval: 300
        onTriggered: {
            const path = root.wallFiles[root.wallSelected];
            if (!path || path === Wallpapers.currentImage)
                return;
            root.wallTried = path;
            Wallpapers.chosen(path, false);
            root.runWallpaper(path);
        }
    }
    Process {
        id: wallProcess

        environment: ({
                NIRI_DESK_WALLPAPER_QUIET: "1"
            })
        onExited: {
            if (root.wallWanted !== root.wallDone)
                root.startWallpaper();
        }
    }
    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.armed = ""
    }

    MouseArea {
        id: catcher

        // Empty while closing, so clicks already reach what is behind.
        width: root.closing ? 0 : parent.width
        height: root.closing ? 0 : parent.height
        onClicked: Ui.popup = ""
    }

    // Inner curves that join the menu to the screen edge. They stay on the edge when the card
    // overshoots, and appear as soon as the card has risen far enough to meet them.
    Repeater {
        model: Settings.bottom ? [] : [0, 1]

        delegate: Shape {
            id: curve

            required property int modelData

            x: modelData === 0 ? card.x - 18 : card.x + card.width
            y: root.height - 18
            width: 18
            height: 18
            opacity: Math.max(0, Math.min(1, (root.height - card.y - root.overdraw) / 40))
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Theme.glassTop

                PathSvg {
                    path: curve.modelData === 0 ? "M0 18 L18 18 L18 0 A18 18 0 0 1 0 18 Z" : "M18 18 L0 18 L0 0 A18 18 0 0 0 18 18 Z"
                }
            }
        }
    }

    Rectangle {
        id: card

        readonly property int radiusSize: 26
        readonly property int bodyHeight: viewport.height + 10 + 46 + root.padding * 2

        x: Math.round((parent.width - width) / 2)
        y: parent.height - root.edgeGap - bodyHeight + (1 - root.reveal) * (bodyHeight + root.edgeGap + 4)
        width: root.shownWide ? Math.min(980, parent.width - 40) : 640
        height: bodyHeight + root.overdraw
        topLeftRadius: radiusSize
        topRightRadius: radiusSize
        bottomLeftRadius: Settings.bottom ? radiusSize : 0
        bottomRightRadius: Settings.bottom ? radiusSize : 0
        border.width: 1
        border.color: Theme.panelEdge
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.panel
            }
            GradientStop {
                position: 1
                color: Theme.glassTop
            }
        }

        Behavior on width {
            enabled: root.reveal > 0.5

            NumberAnimation {
                duration: 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.emphasized
            }
        }

        // Keeps clicks on the menu from closing it.
        MouseArea {
            anchors.fill: parent
        }

        // Rows above the search field. Only this height animates, so the field never moves.
        Item {
            id: viewport

            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            height: root.shownWide ? root.wallCard.height + 30 : root.rowHeight * Math.min(root.maxRows, Math.max(1, root.shownRows.length))
            clip: true
            opacity: root.viewFade
            scale: 0.97 + 0.03 * root.viewFade

            Behavior on height {
                enabled: root.reveal > 0.5

                NumberAnimation {
                    duration: 340
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.emphasized
                }
            }

            // Apps and commands
            ListView {
                id: list

                anchors.fill: parent
                visible: !root.shownWide
                cacheBuffer: 600
                currentIndex: root.selected
                // The wheel moves the selection and the list follows, so nothing fights over it.
                interactive: false
                highlightFollowsCurrentItem: false
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                highlightMoveDuration: 200
                highlightMoveVelocity: -1
                model: ScriptModel {
                    values: root.shownIds
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const steps = root.wheelSteps(event.angleDelta.y);
                        if (steps !== 0)
                            root.selected = Math.max(0, Math.min(root.results.length - 1, root.selected + steps));
                    }
                }

                highlight: Rectangle {
                    y: root.selected * root.rowHeight
                    width: list.width
                    height: root.rowHeight
                    radius: 15
                    visible: list.count > 0
                    color: list.currentItem && list.currentItem.isArmed ? Theme.error : Qt.alpha(Theme.text, 0.1)

                    Behavior on y {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.emphasized
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }
                }

                // Leaving rows are gone before new ones come, so text never overlaps.
                add: Transition {
                    SequentialAnimation {
                        PropertyAction {
                            property: "opacity"
                            value: 0
                        }
                        PauseAnimation {
                            duration: 70
                        }
                        NumberAnimation {
                            property: "opacity"
                            to: 1
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: 70
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 260
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.emphasized
                    }
                    NumberAnimation {
                        properties: "opacity,scale"
                        to: 1
                        duration: 160
                    }
                }
                move: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 260
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.emphasized
                    }
                    NumberAnimation {
                        properties: "opacity,scale"
                        to: 1
                        duration: 160
                    }
                }

                delegate: Item {
                    id: row

                    required property string modelData
                    required property int index

                    readonly property var entry: root.rowsById[modelData] || null
                    readonly property bool isSelected: index === root.selected
                    readonly property bool isArmed: root.armed !== "" && root.armed === modelData
                    readonly property color nameColor: isArmed ? Theme.pill : Theme.text
                    readonly property bool hasImage: !!entry && !!entry.image && picture.status === Image.Ready
                    // Rows unfold upward from the search field.
                    readonly property real rise: root.progress(Math.max(0, Math.min(root.maxRows, root.shownRows.length) - 1 - index) * 0.07)

                    width: ListView.view.width
                    height: root.rowHeight

                    Item {
                        anchors.fill: parent
                        opacity: row.rise
                        transform: Translate {
                            y: (1 - row.rise) * 18
                        }
                        scale: rowArea.pressed ? 0.98 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 110
                            }
                        }

                        Item {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            scale: row.isSelected ? 1.1 : 1

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2
                                }
                            }

                            Image {
                                id: picture

                                anchors.fill: parent
                                source: row.entry && row.entry.image ? row.entry.image : ""
                                sourceSize: Qt.size(64, 64)
                                asynchronous: true
                                visible: row.hasImage
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: !row.hasImage
                                name: row.entry ? row.entry.icon : "windows"
                                size: 22
                                color: row.nameColor
                            }
                        }
                        Column {
                            x: row.isSelected ? 62 : 58
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.parent.width - 74

                            Behavior on x {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: root.emphasized
                                }
                            }

                            Label {
                                width: parent.width
                                text: row.entry ? row.entry.name : ""
                                size: 14
                                color: row.nameColor
                                elide: Text.ElideRight
                            }
                            Label {
                                width: parent.width
                                visible: text !== ""
                                text: row.isArmed ? Tr.t("Press once more to proceed") : row.entry ? row.entry.detail : ""
                                size: 12
                                color: row.isArmed ? Theme.pill : Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => {
                            if (root.pointerMoved(mapToItem(null, mouse.x, mouse.y)))
                                root.selected = row.index;
                        }
                        onClicked: root.execute(row.index)
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                opacity: !root.shownWide && list.count === 0 ? 1 : 0
                text: Tr.t("Nothing found")
                color: Theme.muted

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }
            }

            // Wallpapers, plain and live
            ListView {
                id: wallView

                anchors.fill: parent
                visible: root.shownWide
                orientation: ListView.Horizontal
                spacing: 8
                cacheBuffer: 400
                currentIndex: root.wallSelected
                interactive: false
                highlightMoveDuration: 300
                highlightMoveVelocity: -1
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: (width - root.wallCard.width) / 2
                preferredHighlightEnd: (width + root.wallCard.width) / 2
                model: ScriptModel {
                    values: root.wallFiles
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const steps = root.wheelSteps(event.angleDelta.y);
                        if (steps !== 0)
                            root.stepWall(steps);
                    }
                }

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 200
                    }
                }
                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: 120
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        property: "x"
                        duration: 280
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.emphasized
                    }
                    NumberAnimation {
                        property: "opacity"
                        to: 1
                        duration: 160
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: wallView.count === 0
                    text: Tr.t("Nothing found")
                    color: Theme.muted
                }

                delegate: Item {
                    id: wall

                    required property string modelData
                    required property int index

                    readonly property bool isSelected: index === root.wallSelected

                    width: root.wallCard.width
                    height: wallView.height

                    ClippingRectangle {
                        width: root.wallCard.width
                        height: root.wallCard.height
                        radius: wall.isSelected ? 20 : 16
                        color: Qt.alpha(Theme.text, 0.06)
                        border.width: wall.isSelected ? 2 : 0
                        border.color: Theme.accent
                        scale: wall.isSelected ? 1 : 0.9
                        opacity: wall.isSelected ? 1 : 0.55

                        Behavior on scale {
                            NumberAnimation {
                                duration: 340
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.6
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 220
                            }
                        }
                        Behavior on radius {
                            NumberAnimation {
                                duration: 220
                            }
                        }

                        Image {
                            anchors.fill: parent
                            // Same size and fill as the service, so the picture is found in memory.
                            sourceSize: Wallpapers.thumbSize
                            fillMode: Image.PreserveAspectCrop
                            source: Wallpapers.thumbOf(wall.modelData)
                            asynchronous: true
                        }
                    }
                    Label {
                        y: root.wallCard.height + 8
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Wallpapers.nameOf(wall.modelData)
                        opacity: wall.isSelected ? 1 : 0
                        size: 12
                        color: Theme.muted
                        elide: Text.ElideMiddle

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => {
                            if (root.pointerMoved(mapToItem(null, mouse.x, mouse.y)))
                                root.wallSelected = wall.index;
                        }
                        onClicked: root.setWallpaper(wall.modelData)
                    }
                }
            }
        }

        // Search and session buttons
        Item {
            id: bottomRow

            x: root.padding
            y: viewport.y + viewport.height + 10
            width: parent.width - root.padding * 2
            height: 46

            Rectangle {
                anchors.left: parent.left
                anchors.right: sessionRow.left
                anchors.rightMargin: 10
                height: parent.height
                radius: 23
                color: Qt.alpha(Theme.text, input.text === "" ? 0.08 : 0.11)
                opacity: root.progress(0)

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }

                // The glass turns from a search into a command prompt.
                Icon {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 17
                    color: Theme.muted
                    opacity: root.commandMode ? 0 : 1
                    rotation: root.commandMode ? 90 : 0
                    scale: root.commandMode ? 0.6 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Icon {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: "forward"
                    size: 17
                    color: Theme.accent
                    opacity: root.commandMode ? 1 : 0
                    rotation: root.commandMode ? 0 : -90
                    scale: root.commandMode ? 1 : 0.6

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                TextInput {
                    id: input

                    anchors.left: parent.left
                    anchors.leftMargin: 44
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    focus: true
                    clip: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.family: Theme.sans
                    font.pixelSize: Math.round(15 * Theme.fontScale)
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: Ui.popup = ""
                    Keys.onReturnPressed: root.execute(root.selected)
                    Keys.onEnterPressed: root.execute(root.selected)
                    Keys.onDownPressed: root.selected = Math.min(root.results.length - 1, root.selected + 1)
                    Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                    Keys.onTabPressed: {
                        if (root.results.length > 0)
                            root.selected = (root.selected + 1) % root.results.length;
                    }
                    Keys.onLeftPressed: event => {
                        if (root.wallpaperMode)
                            root.stepWall(-1);
                        else
                            event.accepted = false;
                    }
                    Keys.onRightPressed: event => {
                        if (root.wallpaperMode)
                            root.stepWall(1);
                        else
                            event.accepted = false;
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        x: input.text === "" ? 0 : 10
                        opacity: input.text === "" ? 1 : 0
                        text: Tr.t("Search apps, or type > for commands")
                        color: Qt.alpha(Theme.text, 0.45)
                        size: 15
                        elide: Text.ElideRight

                        Behavior on x {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 70
                            }
                        }
                    }
                }
            }

            Row {
                id: sessionRow

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: root.session

                    delegate: Item {
                        id: sessionSlot

                        required property var modelData
                        required property int index

                        readonly property real pop: root.progress(0.1 + index * 0.07)

                        width: 42
                        height: 42
                        opacity: pop
                        scale: 0.6 + 0.4 * pop

                        Rectangle {
                            id: sessionButton

                            readonly property bool isArmed: root.armed === sessionSlot.modelData.id

                            anchors.fill: parent
                            radius: isArmed || sessionArea.containsMouse ? 14 : 21
                            color: isArmed ? Theme.error : Qt.alpha(Theme.text, sessionArea.containsMouse ? 0.15 : 0.06)
                            scale: sessionArea.pressed ? 0.88 : sessionArea.containsMouse ? 1.06 : 1

                            Behavior on radius {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.4
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 240
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2.2
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: sessionSlot.modelData.icon
                                size: 18
                                color: sessionButton.isArmed ? Theme.pill : Theme.text
                            }
                            MouseArea {
                                id: sessionArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: {
                                    if (containsMouse)
                                        root.hoveredSession = sessionSlot.modelData.id;
                                    else if (root.hoveredSession === sessionSlot.modelData.id)
                                        root.hoveredSession = "";
                                }
                                onClicked: root.runSession(sessionSlot.modelData)
                            }
                        }
                    }
                }
            }

            // The buttons have no text: their name shows above them.
            Rectangle {
                id: tipBox

                readonly property string current: root.armed || root.hoveredSession
                readonly property bool showing: current !== ""
                // Stays while it fades out, so the text does not vanish first.
                property var item: null

                onCurrentChanged: {
                    if (current !== "")
                        item = root.session.find(s => s.id === current) || null;
                }

                anchors.right: parent.right
                y: showing ? -34 : -28
                width: tip.implicitWidth + 20
                height: 28
                radius: 10
                color: root.armed !== "" ? Theme.error : Theme.pill
                opacity: showing ? 1 : 0
                visible: opacity > 0

                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }

                Label {
                    id: tip

                    anchors.centerIn: parent
                    text: tipBox.item ? (root.armed !== "" ? tipBox.item.name + ": " + Tr.t("Press once more to proceed") : tipBox.item.name) : ""
                    color: root.armed !== "" ? Theme.pill : Theme.text
                    size: 12
                }
            }
        }
    }
}
