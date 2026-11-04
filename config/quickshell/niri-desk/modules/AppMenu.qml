import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services
import "../services/tools.js" as Tools

// App menu: rises from the bottom center of the screen. Typing searches apps, and ">" lists
// commands, ">wallpaper" among them. The session buttons sit beside the search field.
LazyLoader {
    active: Ui.menuAlive

    PanelWindow {
        id: root

        readonly property bool closing: Ui.popup !== "menu"
        // A panel at the bottom takes the edge, so the menu floats above it.
        readonly property int edgeGap: Settings.bottom ? 56 : 0
        readonly property int rowHeight: 54
        readonly property int maxRows: 7
        readonly property int padding: 12
        readonly property size wallCard: Qt.size(180, 210)

        property string query: ""
        property int selected: 0
        property int wallSelected: 0
        property real reveal: 0
        property var lastPointer: null
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

        readonly property var wallFiles: {
            const key = commandRest.toLowerCase();
            const all = Wallpapers.liveFiles.concat(Wallpapers.imageFiles);
            return key === "" ? all : all.filter(path => Tools.score(Wallpapers.nameOf(path), key, "") > 0);
        }

        readonly property var results: {
            if (wallpaperMode)
                return [];
            if (calcMode)
                return calcRows();
            if (schemeMode)
                return schemeRows();
            if (commandMode)
                return ranked(commands, c => c.name, c => c.keywords, commandText.toLowerCase());
            return appRows(query.trim().toLowerCase());
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

        function appRows(q) {
            const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name));
            return ranked(apps, a => a.name, a => a.genericName + " " + a.keywords.join(" "), q).map(entry => ({
                        id: entry.id,
                        image: Quickshell.iconPath(entry.icon, true),
                        icon: "windows",
                        name: entry.name,
                        detail: entry.comment || entry.genericName || "",
                        run: () => entry.execute()
                    }));
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

        function setWallpaper(path) {
            Wallpapers.chosen(path, Wallpapers.liveFiles.indexOf(path) >= 0);
            Ui.popup = "";
            Ui.run("niri-desk-wallpaper", path);
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

        function startWallpapers() {
            const live = wallFiles.indexOf(Wallpapers.currentLive);
            wallSelected = Math.max(0, live >= 0 ? live : wallFiles.indexOf(Wallpapers.currentImage));
            wallView.positionViewAtIndex(wallSelected, ListView.Center);
        }

        // A row left under the pointer stays unselected until the pointer really moves.
        function pointerMoved(index, point) {
            if (lastPointer && Math.abs(lastPointer.x - point.x) + Math.abs(lastPointer.y - point.y) > 3)
                selected = index;
            lastPointer = point;
        }

        onClosingChanged: {
            if (closing) {
                fadeIn.stop();
                fadeOut.start();
            } else {
                fadeOut.stop();
                input.text = "";
                input.forceActiveFocus();
                fadeIn.start();
            }
        }
        onResultsChanged: {
            selected = 0;
            Ui.launcherSelected = 0;
            Ui.launcherRows = results.map(r => r.name);
        }
        onSelectedChanged: Ui.launcherSelected = selected
        onWallpaperModeChanged: {
            if (wallpaperMode) {
                Wallpapers.refresh();
                startWallpapers();
            }
        }
        onCommandRestChanged: {
            if (wallpaperMode)
                wallSelected = 0;
        }
        Component.onCompleted: {
            Ui.launcherRows = results.map(r => r.name);
            fadeIn.start();
        }

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
            item: root.closing ? null : catcher
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

            // The surface reaches the screen a moment after it is created.
            PauseAnimation {
                duration: 40
            }
            NumberAnimation {
                target: root
                property: "reveal"
                to: 1
                duration: 360
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
            }
        }
        SequentialAnimation {
            id: fadeOut

            NumberAnimation {
                target: root
                property: "reveal"
                to: 0
                duration: 240
                easing.type: Easing.InCubic
            }
            ScriptAction {
                script: Ui.menuAlive = false
            }
        }
        Timer {
            id: disarm

            interval: 4000
            onTriggered: root.armed = ""
        }

        MouseArea {
            id: catcher

            anchors.fill: parent
            onClicked: Ui.popup = ""
        }

        Rectangle {
            id: card

            readonly property int radiusSize: 26
            readonly property bool wide: root.wallpaperMode

            x: Math.round((parent.width - width) / 2)
            y: parent.height - root.edgeGap - height + (1 - root.reveal) * (height + root.edgeGap)
            width: wide ? Math.min(980, parent.width - 40) : 640
            height: column.implicitHeight + root.padding * 2
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
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                }
            }
            Behavior on height {
                enabled: root.reveal === 1

                NumberAnimation {
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                }
            }

            // Inner curves that join the menu to the screen edge.
            Repeater {
                model: Settings.bottom ? [] : [0, 1]

                delegate: Shape {
                    id: curve

                    required property int modelData

                    x: modelData === 0 ? -18 : card.width
                    y: card.height - 18
                    width: 18
                    height: 18
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

            // Keeps clicks on the menu from closing it.
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: column

                x: root.padding
                y: root.padding
                width: parent.width - root.padding * 2
                spacing: 10

                // Apps and commands
                ListView {
                    id: list

                    width: parent.width
                    height: root.wallpaperMode ? 0 : root.rowHeight * Math.min(root.maxRows, Math.max(1, count))
                    visible: !root.wallpaperMode
                    clip: true
                    model: root.results
                    currentIndex: root.selected
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 140
                    highlightMoveVelocity: -1
                    highlightResizeDuration: 0
                    highlight: Rectangle {
                        radius: 14
                        color: root.results[root.selected] && root.armed === root.results[root.selected].id ? Theme.error : Qt.alpha(Theme.text, 0.1)
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: Tr.t("Nothing found")
                        color: Theme.muted
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool isArmed: root.armed !== "" && root.armed === modelData.id
                        readonly property color nameColor: isArmed ? Theme.pill : Theme.text
                        readonly property bool hasImage: !!modelData.image && picture.status === Image.Ready

                        width: ListView.view.width
                        height: root.rowHeight

                        Image {
                            id: picture

                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            source: row.modelData.image || ""
                            sourceSize: Qt.size(64, 64)
                            asynchronous: true
                            visible: row.hasImage
                        }
                        Icon {
                            x: 17
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !row.hasImage
                            name: row.modelData.icon
                            size: 22
                            color: row.nameColor
                        }
                        Column {
                            x: 58
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 70

                            Label {
                                width: parent.width
                                text: row.modelData.name
                                size: 14
                                color: row.nameColor
                                elide: Text.ElideRight
                            }
                            Label {
                                width: parent.width
                                visible: text !== ""
                                text: row.isArmed ? Tr.t("Press once more to proceed") : row.modelData.detail
                                size: 12
                                color: row.isArmed ? Theme.pill : Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => root.pointerMoved(row.index, mapToItem(null, mouse.x, mouse.y))
                            onClicked: root.execute(row.index)
                        }
                    }
                }

                // Wallpapers, plain and live
                ListView {
                    id: wallView

                    width: parent.width
                    height: root.wallpaperMode ? root.wallCard.height + 30 : 0
                    visible: root.wallpaperMode
                    clip: true
                    orientation: ListView.Horizontal
                    spacing: 8
                    model: root.wallFiles
                    currentIndex: root.wallSelected
                    highlightMoveDuration: 240
                    highlightMoveVelocity: -1
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: (width - root.wallCard.width) / 2
                    preferredHighlightEnd: (width + root.wallCard.width) / 2
                    onCountChanged: {
                        if (root.wallSelected >= count)
                            root.wallSelected = Math.max(0, count - 1);
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
                            radius: 16
                            color: Qt.alpha(Theme.text, 0.06)
                            border.width: wall.isSelected ? 2 : 0
                            border.color: Theme.accent
                            scale: wall.isSelected ? 1 : 0.92
                            opacity: wall.isSelected ? 1 : 0.6

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
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
                            Rectangle {
                                x: 8
                                y: 8
                                width: 24
                                height: 24
                                radius: 12
                                color: Theme.pill
                                visible: Wallpapers.liveFiles.indexOf(wall.modelData) >= 0

                                Icon {
                                    anchors.centerIn: parent
                                    name: "play"
                                    size: 12
                                }
                            }
                        }
                        Label {
                            y: root.wallCard.height + 8
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Wallpapers.nameOf(wall.modelData)
                            visible: wall.isSelected
                            size: 12
                            color: Theme.muted
                            elide: Text.ElideMiddle
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setWallpaper(wall.modelData)
                            onWheel: wheel => {
                                const step = wheel.angleDelta.y > 0 ? -1 : 1;
                                root.wallSelected = Math.max(0, Math.min(wallView.count - 1, root.wallSelected + step));
                            }
                        }
                    }
                }

                // Search and session buttons
                Item {
                    width: parent.width
                    height: 46

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: sessionRow.left
                        anchors.rightMargin: 10
                        height: parent.height
                        radius: 23
                        color: Qt.alpha(Theme.text, 0.08)

                        Icon {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            name: root.commandMode ? "forward" : "search"
                            size: 17
                            color: root.commandMode ? Theme.accent : Theme.muted
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
                            onTextChanged: {
                                root.query = text;
                                root.armed = "";
                            }
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
                                    root.wallSelected = Math.max(0, root.wallSelected - 1);
                                else
                                    event.accepted = false;
                            }
                            Keys.onRightPressed: event => {
                                if (root.wallpaperMode)
                                    root.wallSelected = Math.min(wallView.count - 1, root.wallSelected + 1);
                                else
                                    event.accepted = false;
                            }

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                visible: input.text === ""
                                text: Tr.t("Search apps, or type > for commands")
                                color: Qt.alpha(Theme.text, 0.45)
                                size: 15
                                elide: Text.ElideRight
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

                            delegate: Rectangle {
                                id: sessionButton

                                required property var modelData

                                readonly property bool isArmed: root.armed === modelData.id

                                width: 42
                                height: 42
                                radius: isArmed || sessionArea.containsMouse ? 14 : 21
                                color: isArmed ? Theme.error : Qt.alpha(Theme.text, sessionArea.containsMouse ? 0.14 : 0.06)

                                Behavior on radius {
                                    NumberAnimation {
                                        duration: 180
                                    }
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    name: sessionButton.modelData.icon
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
                                            root.hoveredSession = sessionButton.modelData.id;
                                        else if (root.hoveredSession === sessionButton.modelData.id)
                                            root.hoveredSession = "";
                                    }
                                    onClicked: root.runSession(sessionButton.modelData)
                                }
                            }
                        }
                    }

                    // The buttons have no text: their name shows above them.
                    Rectangle {
                        readonly property var item: root.session.find(s => s.id === (root.armed || root.hoveredSession)) || null

                        anchors.right: parent.right
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 6
                        width: tip.implicitWidth + 20
                        height: 28
                        radius: 10
                        color: root.armed !== "" ? Theme.error : Theme.pill
                        visible: !!item
                        z: 5

                        Label {
                            id: tip

                            anchors.centerIn: parent
                            text: parent.item ? (root.armed !== "" ? parent.item.name + ": " + Tr.t("Press once more to proceed") : parent.item.name) : ""
                            color: root.armed !== "" ? Theme.pill : Theme.text
                            size: 12
                        }
                    }
                }
            }
        }
    }
}
