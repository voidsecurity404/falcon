import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Sozlamalar: har bir bo'lim ro'yxat ko'rinishida tasvirlangan, o'zgarish darhol qo'llanadi.
LazyLoader {
    active: Ui.settingsOpen

    FloatingWindow {
        id: win

        property int page: 0
        property string filter: ""

        onPageChanged: scroller.contentY = 0

        property var outputs: []
        readonly property var monitorItems: {
            let list = [];
            for (const name of outputs) {
                list = list.concat([
                    { key: "monitors." + name + ".scale", label: Tr.t("{name}: scale").replace("{name}", name), type: "slider", min: 0.5, max: 3, step: 0.05, fallback: 1 },
                    { key: "monitors." + name + ".transform", label: Tr.t("{name}: rotation").replace("{name}", name), type: "choice", options: ["normal", "90", "180", "270"], names: [Tr.t("None"), "90°", "180°", "270°"], fallback: "normal" },
                    { key: "monitors." + name + ".x", label: Tr.t("{name}: X position").replace("{name}", name), type: "number", fallback: 0 },
                    { key: "monitors." + name + ".y", label: Tr.t("{name}: Y position").replace("{name}", name), type: "number", fallback: 0 },
                    { key: "monitors." + name + ".off", label: Tr.t("{name}: disabled").replace("{name}", name), type: "toggle", fallback: false }
                ]);
            }
            return list;
        }

        Process {
            command: ["niri", "msg", "--json", "outputs"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        win.outputs = Object.keys(JSON.parse(text));
                    } catch (e) {
                        win.outputs = [];
                    }
                }
            }
        }

        readonly property var schemes: ["scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-fidelity", "scheme-content", "scheme-neutral", "scheme-monochrome", "scheme-rainbow", "scheme-fruit-salad"]
        readonly property var pages: [
            {
                title: Tr.t("Appearance"),
                icon: "palette",
                items: [
                    { key: "appearance.language", label: Tr.t("Language"), type: "choice", options: ["auto", "en", "ru"], names: [Tr.t("Automatic"), "English", "Русский"], fallback: "auto" },
                    { key: "appearance.mode", label: Tr.t("Mode"), type: "choice", options: ["dark", "light"], names: [Tr.t("Dark"), Tr.t("Light")] },
                    { key: "appearance.scheme", label: Tr.t("Color style"), type: "choice", options: schemes },
                    { key: "appearance.accent", label: Tr.t("Custom color"), hint: Tr.t("#rrggbb. Empty means taken from the wallpaper"), type: "text" },
                    { key: "appearance.font", label: Tr.t("Font"), type: "text" },
                    { key: "appearance.monoFont", label: Tr.t("Terminal font"), type: "text" },
                    { key: "appearance.fontScale", label: Tr.t("Text size"), type: "slider", min: 0.8, max: 1.3, step: 0.05 },
                    { key: "appearance.terminalOpacity", label: Tr.t("Terminal opacity"), type: "slider", min: 0.3, max: 1, step: 0.02 },
                    { key: "appearance.terminalFontSize", label: Tr.t("Terminal font size"), type: "slider", min: 8, max: 20, step: 1 },
                    { key: "appearance.cursorTheme", label: Tr.t("Cursor theme"), type: "text" },
                    { key: "appearance.cursorSize", label: Tr.t("Cursor size"), type: "slider", min: 16, max: 48, step: 2 }
                ]
            },
            {
                title: Tr.t("Windows"),
                icon: "windows",
                items: [
                    { key: "windows.gaps", label: Tr.t("Gaps between windows"), type: "slider", min: 0, max: 40, step: 1 },
                    { key: "windows.radius", label: Tr.t("Corner radius"), type: "slider", min: 0, max: 32, step: 1 },
                    { key: "windows.focusRing", label: Tr.t("Focus ring width"), type: "slider", min: 0, max: 8, step: 1 },
                    { key: "windows.shadow", label: Tr.t("Shadow"), type: "toggle" },
                    { key: "windows.blur", label: Tr.t("Blur"), type: "toggle" },
                    { key: "windows.inactiveOpacity", label: Tr.t("Inactive window opacity"), type: "slider", min: 0.4, max: 1, step: 0.02 },
                    { key: "windows.defaultWidth", label: Tr.t("New window width"), type: "choice", options: [0.33333, 0.5, 0.66667, 1], names: ["1/3", "1/2", "2/3", Tr.t("Full")] },
                    { key: "windows.centerFocused", label: Tr.t("Center focused column"), type: "choice", options: ["never", "on-overflow", "always"], names: [Tr.t("Never"), Tr.t("If it doesn't fit"), Tr.t("Always")] },
                    { key: "windows.centerSingle", label: Tr.t("Center a single window"), type: "toggle" },
                    { key: "windows.tabbedByDefault", label: Tr.t("Columns as tabs"), type: "toggle" },
                    { key: "windows.focusFollowsMouse", label: Tr.t("Focus follows cursor"), type: "toggle" },
                    { key: "windows.warpMouse", label: Tr.t("Cursor follows focus"), type: "toggle" },
                    { key: "windows.autoBackForth", label: Tr.t("Same number again goes to previous workspace"), type: "toggle" },
                    { key: "windows.animations", label: Tr.t("Animations"), type: "toggle" },
                    { key: "windows.animationSpeed", label: Tr.t("Animation speed"), type: "slider", min: 0.3, max: 3, step: 0.1 }
                ]
            },
            {
                title: Tr.t("Window rules"),
                icon: "rules",
                rules: true,
                items: []
            },
            {
                title: Tr.t("Panel"),
                icon: "panel",
                items: [
                    { key: "appearance.panelOpacity", label: Tr.t("Panel opacity"), hint: Tr.t("Lower is more see-through"), type: "slider", min: 0.15, max: 1, step: 0.05 },
                    { key: "panel.position", label: Tr.t("Position"), type: "choice", options: ["top", "bottom"], names: [Tr.t("Top"), Tr.t("Bottom")] },
                    { key: "panel.ribbon", label: Tr.t("Workspace numbers"), type: "toggle" },
                    { key: "panel.hideEmpty", label: Tr.t("Hide empty workspaces"), type: "toggle" },
                    { key: "panel.tray", label: Tr.t("Tray"), type: "toggle" },
                    { key: "panel.lang", label: Tr.t("Keyboard layout"), type: "toggle" },
                    { key: "panel.wifi", label: Tr.t("Wi-Fi icon"), type: "toggle" },
                    { key: "panel.volume", label: Tr.t("Volume"), type: "toggle" },
                    { key: "panel.battery", label: Tr.t("Battery"), type: "toggle" },
                    { key: "panel.clockSeconds", label: Tr.t("Seconds"), type: "toggle" },
                    { key: "panel.clockDate", label: Tr.t("Date"), type: "toggle" },
                    { key: "notifications.seconds", label: Tr.t("Notification duration, seconds"), type: "slider", min: 1, max: 15, step: 0.5 },
                    { key: "notifications.history", label: Tr.t("Notifications kept in history"), type: "slider", min: 5, max: 100, step: 5 }
                ]
            },
            {
                title: Tr.t("Keyboard"),
                icon: "keyboard",
                items: [
                    { key: "keyboard.layouts", label: Tr.t("Layouts"), hint: Tr.t("Example: us,ru"), type: "text" },
                    { key: "keyboard.options", label: Tr.t("XKB options"), type: "text" },
                    { key: "keyboard.perWindow", label: Tr.t("Remember layout per window"), type: "toggle" },
                    { key: "keyboard.repeatDelay", label: Tr.t("Repeat delay, ms"), type: "slider", min: 150, max: 800, step: 10 },
                    { key: "keyboard.repeatRate", label: Tr.t("Repeat rate"), type: "slider", min: 10, max: 80, step: 1 },
                    { key: "keyboard.numlock", label: Tr.t("NumLock on"), type: "toggle" },
                    { key: "pointer.tap", label: Tr.t("Touchpad: tap to click"), type: "toggle" },
                    { key: "pointer.naturalScroll", label: Tr.t("Touchpad: natural scroll"), type: "toggle" },
                    { key: "pointer.disableWhileTyping", label: Tr.t("Disable touchpad while typing"), type: "toggle" },
                    { key: "pointer.touchpadSpeed", label: Tr.t("Touchpad speed"), type: "slider", min: -1, max: 1, step: 0.05 },
                    { key: "pointer.scrollFactor", label: Tr.t("Scroll speed"), type: "slider", min: 0.2, max: 3, step: 0.1 },
                    { key: "pointer.mouseFlat", label: Tr.t("No mouse acceleration"), type: "toggle" },
                    { key: "pointer.mouseSpeed", label: Tr.t("Mouse speed"), type: "slider", min: -1, max: 1, step: 0.05 }
                ]
            },
            {
                title: Tr.t("Shortcuts"),
                icon: "shortcut",
                items: [
                    { key: "binds.terminal", label: Tr.t("Terminal"), type: "text" },
                    { key: "binds.apps", label: Tr.t("Apps"), type: "text" },
                    { key: "binds.launcher", label: Tr.t("Search"), type: "text" },
                    { key: "binds.clipboard", label: Tr.t("Clipboard history"), type: "text" },
                    { key: "binds.dashboard", label: Tr.t("Dashboard"), type: "text" },
                    { key: "binds.control", label: Tr.t("Control center"), type: "text" },
                    { key: "binds.wallpapers", label: Tr.t("Wallpaper and color"), type: "text" },
                    { key: "binds.settings", label: Tr.t("Settings"), type: "text" },
                    { key: "binds.zen", label: Tr.t("Focus mode"), type: "text" },
                    { key: "binds.lock", label: Tr.t("Lock screen"), type: "text" },
                    { key: "binds.overview", label: Tr.t("Overview"), type: "text" },
                    { key: "binds.scratch", label: Tr.t("Scratchpad terminal"), type: "text" },
                    { key: "binds.sticky", label: Tr.t("Sticky window"), type: "text" },
                    { key: "binds.browser", label: Tr.t("Browser"), type: "text" },
                    { key: "binds.files", label: Tr.t("Files"), type: "text" },
                    { key: "binds.notes", label: Tr.t("Notes"), type: "text" },
                    { key: "binds.close", label: Tr.t("Close window"), type: "text" },
                    { key: "binds.widthCycle", label: Tr.t("Column width"), type: "text" },
                    { key: "binds.maximize", label: Tr.t("Maximize column"), type: "text" },
                    { key: "binds.fullscreen", label: Tr.t("Fullscreen"), type: "text" },
                    { key: "binds.screenshot", label: Tr.t("Screenshot"), type: "text" },
                    { key: "binds.record", label: Tr.t("Record screen"), type: "text" },
                    { key: "binds.ocr", label: Tr.t("Copy text from screen"), type: "text" },
                    { key: "binds.translate", label: Tr.t("Translate from screen"), type: "text" },
                    { key: "binds.widgets", label: Tr.t("Edit widgets"), type: "text" }
                ]
            },
            {
                title: Tr.t("Monitors"),
                icon: "monitor",
                items: win.monitorItems
            },
            {
                title: Tr.t("AI"),
                icon: "sparkle",
                aiKey: true,
                items: [
                    { key: "ai.backend", label: Tr.t("Connection"), type: "choice", options: ["auto", "claude-code", "api"], names: [Tr.t("Automatic"), Tr.t("Claude Code subscription"), Tr.t("API key")], fallback: "auto" },
                    { key: "ai.model", label: Tr.t("Model"), type: "text" },
                    { key: "ai.effort", label: Tr.t("Effort"), hint: Tr.t("Higher is slower and costs more"), type: "choice", options: ["low", "medium", "high", "xhigh"], names: [Tr.t("Low"), Tr.t("Medium"), Tr.t("High"), Tr.t("Very high")] },
                    { key: "ai.system", label: Tr.t("Custom instructions"), hint: Tr.t("Empty means default"), type: "text", fallback: "" }
                ]
            },
            {
                title: Tr.t("Widgets"),
                icon: "windows",
                items: [
                    { key: "widgets.enabled", label: Tr.t("Widgets on the desktop"), type: "toggle" },
                    { key: "widgets.firstOnly", label: Tr.t("Only on the first workspace"), type: "toggle" },
                    { key: "widgets.opacity", label: Tr.t("Widget opacity"), hint: Tr.t("Lower is more see-through"), type: "slider", min: 0.1, max: 1, step: 0.05 },
                    { label: Tr.t("Move, add and remove widgets"), hint: Tr.t("Right click the desktop or press the shortcut"), type: "action", text: Tr.t("Edit widgets"), run: () => { Ui.settingsOpen = false; Widgets.editMode = true; } }
                ]
            },
            {
                title: Tr.t("System"),
                icon: "system",
                items: [
                    { key: "session.restore", label: Tr.t("Restore windows at login"), type: "toggle" },
                    { key: "schedule.mode", label: Tr.t("Switch light and dark by time"), type: "toggle" },
                    { key: "schedule.lightFrom", label: Tr.t("Light mode starts"), type: "text" },
                    { key: "schedule.darkFrom", label: Tr.t("Dark mode starts"), type: "text" },
                    { key: "nightlight.auto", label: Tr.t("Night light schedule"), type: "toggle" },
                    { key: "nightlight.from", label: Tr.t("Night light starts"), type: "text" },
                    { key: "nightlight.to", label: Tr.t("Night light ends"), type: "text" },
                    { key: "translate.to", label: Tr.t("Translate to"), hint: Tr.t("ru, en, de. Empty means the interface language"), type: "text", fallback: "" },
                    { key: "idle.lock", label: Tr.t("Lock after, seconds (0 is off)"), type: "slider", min: 0, max: 3600, step: 60 },
                    { key: "idle.screenOff", label: Tr.t("Screen off after, seconds"), type: "slider", min: 0, max: 3600, step: 60 },
                    { key: "idle.suspend", label: Tr.t("Sleep after, seconds"), type: "slider", min: 0, max: 7200, step: 60 },
                    { key: "nightlight.temperature", label: Tr.t("Night light temperature"), type: "slider", min: 2500, max: 6000, step: 100 },
                    { key: "weather.enabled", label: Tr.t("Weather"), type: "toggle" },
                    { key: "weather.lat", label: Tr.t("Latitude"), type: "number" },
                    { key: "weather.lon", label: Tr.t("Longitude"), type: "number" },
                    { key: "wallpaperDir", label: Tr.t("Wallpaper folder"), type: "text" }
                ]
            }
        ]

        readonly property var shown: {
            const q = filter.trim().toLowerCase();
            if (q === "")
                return pages[page].items;
            let found = [];
            for (const p of pages)
                found = found.concat(p.items.filter(i => i.label.toLowerCase().indexOf(q) >= 0 || i.key.toLowerCase().indexOf(q) >= 0));
            return found;
        }

        title: "niri-desk settings"
        implicitWidth: 860
        implicitHeight: 640
        color: Theme.pill
        visible: true
        onVisibleChanged: {
            if (!visible)
                Ui.settingsOpen = false;
        }

        // Tepadan tushadigan yengil rang, panel bilan bir xil.
        Rectangle {
            width: parent.width
            height: 180
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.accent, 0.1)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        Row {
            id: body

            anchors.fill: parent
            opacity: 0
            scale: 0.98
            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.25, 1.3, 0.35, 1, 1, 1]
                }
            }

            // Bo'limlar
            Column {
                width: 190
                height: parent.height
                topPadding: 18
                leftPadding: 10
                spacing: 2

                Label {
                    leftPadding: 12
                    bottomPadding: 12
                    text: Tr.t("Settings")
                    size: 19
                    font.weight: Font.Medium
                }

                Item {
                    width: 170
                    height: win.pages.length * 38 - 2

                    // Tanlov belgisi bo'limlar orasida sirpanadi.
                    Rectangle {
                        y: win.page * 38
                        width: 170
                        height: 36
                        radius: 11
                        color: Theme.accent
                        opacity: win.filter === "" ? 1 : 0

                        Behavior on y {
                            NumberAnimation {
                                duration: 420
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.3, 1.35, 0.4, 1, 1, 1]
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                            }
                        }
                    }

                    Column {
                        spacing: 2

                        Repeater {
                            model: win.pages

                            delegate: Rectangle {
                                id: tab

                                required property var modelData
                                required property int index

                                readonly property bool current: win.page === index && win.filter === ""

                                width: 170
                                height: 36
                                radius: 11
                                color: !current && tabArea.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 130
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 12
                                    spacing: 10
                                    scale: tabArea.pressed ? 0.96 : 1

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 110
                                        }
                                    }

                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: tab.modelData.icon
                                        size: 15
                                        color: tab.current ? Theme.accentText : Theme.text
                                    }
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tab.modelData.title
                                        size: 13
                                        color: tab.current ? Theme.accentText : Theme.text
                                        font.weight: tab.current ? Font.DemiBold : Font.Normal
                                    }
                                }
                                MouseArea {
                                    id: tabArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.filter = "";
                                        search.text = "";
                                        win.page = tab.index;
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 14
                }

                Rectangle {
                    id: resetButton

                    property bool armed: false

                    width: 170
                    height: 36
                    radius: 9
                    color: armed ? Theme.error : Qt.alpha(Theme.text, resetArea.containsMouse ? 0.13 : 0.06)

                    Label {
                        anchors.centerIn: parent
                        text: resetButton.armed ? Tr.t("Press to confirm") : Tr.t("Reset to defaults")
                        color: resetButton.armed ? Theme.pill : Theme.text
                        size: 13
                    }
                    MouseArea {
                        id: resetArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (resetButton.armed) {
                                resetButton.armed = false;
                                Settings.resetAll();
                                Toasts.show(Tr.t("Settings reset"), Tr.t("Location was kept"), "check");
                            } else {
                                resetButton.armed = true;
                                disarm.restart();
                            }
                        }
                    }
                    Timer {
                        id: disarm

                        interval: 4000
                        onTriggered: resetButton.armed = false
                    }
                }
            }

            // Tarkib
            Column {
                width: parent.width - 190
                height: parent.height

                Item {
                    width: parent.width
                    height: 62

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 14
                        anchors.bottomMargin: 10
                        radius: 9
                        color: Qt.alpha(Theme.text, 0.07)

                        TextInput {
                            id: search

                            anchors.fill: parent
                            leftPadding: 12
                            rightPadding: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.sans
                            font.pixelSize: 14
                            clip: true
                            onTextChanged: win.filter = text
                            Keys.onEscapePressed: Ui.settingsOpen = false

                            Label {
                                anchors.fill: parent
                                leftPadding: 12
                                verticalAlignment: Text.AlignVCenter
                                visible: search.text === ""
                                text: Tr.t("Search settings…")
                                color: Qt.alpha(Theme.text, 0.4)
                            }
                        }
                    }
                }

                Flickable {
                    id: scroller

                    width: parent.width
                    height: parent.height - 62
                    contentHeight: items.implicitHeight + 24
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: items

                        x: 14
                        width: parent.width - 28
                        spacing: 2

                        Repeater {
                            model: win.shown

                            // Bo'lim almashganda qatorlar navbat bilan chiqadi, qidiruvda esa darhol.
                            delegate: Reveal {
                                required property var modelData
                                required property int index

                                width: items.width
                                height: 46
                                animate: win.filter === ""
                                delay: Math.min(index, 12) * 22

                                SettingRow {
                                    width: parent.width
                                    item: modelData
                                }
                            }
                        }

                        Label {
                            visible: win.filter !== "" && win.shown.length === 0
                            text: Tr.t("Nothing found")
                            color: Theme.muted
                        }

                        // API kaliti settings.json'ga emas, alohida himoyalangan faylga yoziladi.
                        Item {
                            visible: win.filter === "" && !!win.pages[win.page].aiKey
                            width: items.width
                            height: 46

                            Column {
                                anchors.verticalCenter: parent.verticalCenter

                                Label {
                                    text: Tr.t("Anthropic API key")
                                }
                                Label {
                                    text: Tr.t("Only used with an API key")
                                    color: Theme.muted
                                    size: 12
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 300
                                height: 32
                                radius: 8
                                color: Qt.alpha(Theme.text, 0.07)

                                TextInput {
                                    id: keyInput

                                    anchors.fill: parent
                                    leftPadding: 10
                                    rightPadding: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    color: Theme.text
                                    font.family: Theme.mono
                                    font.pixelSize: 13
                                    echoMode: TextInput.Password
                                    onAccepted: {
                                        Ai.setKey(text);
                                        text = "";
                                        Toasts.show(Tr.t("Key saved"), Tr.t("Other users cannot read it"), "check");
                                    }
                                }
                                Label {
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: keyInput.text === ""
                                    text: Tr.t("Type and press Enter")
                                    color: Qt.alpha(Theme.text, 0.4)
                                    size: 13
                                }
                            }
                        }

                        RulesEditor {
                            visible: win.filter === "" && !!win.pages[win.page].rules
                            width: items.width
                        }
                    }
                }
            }
        }
    }
}
