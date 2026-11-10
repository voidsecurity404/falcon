import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Settings: sidebar with grouped pages, each page made of titled cards. Changes apply at once.
LazyLoader {
    active: Ui.settingsOpen

    FloatingWindow {
        id: win

        readonly property int page: Math.max(0, Math.min(pages.length - 1, Ui.settingsPage))
        property string filter: ""

        onPageChanged: {
            scroller.contentY = 0;
            ensureTabVisible();
        }

        // The list of pages is taller than the window, and a page can be opened from outside it.
        function ensureTabVisible() {
            const top = page * tabHeight + (pages[page].group + 1) * groupHeight;
            if (top < sideList.contentY)
                sideList.contentY = Math.max(0, top - groupHeight);
            else if (top + tabHeight > sideList.contentY + sideList.height)
                sideList.contentY = top + tabHeight - sideList.height + 8;
        }

        property var outputs: []
        readonly property var monitorSections: {
            let list = [];
            for (const name of outputs) {
                list.push({
                    title: name,
                    items: [
                        { key: "monitors." + name + ".scale", label: Tr.t("Scale"), type: "slider", min: 0.5, max: 3, step: 0.05, fallback: 1, unit: "scale" },
                        { key: "monitors." + name + ".transform", label: Tr.t("Rotation"), type: "choice", options: ["normal", "90", "180", "270"], names: [Tr.t("None"), "90°", "180°", "270°"], fallback: "normal" },
                        { key: "monitors." + name + ".x", label: Tr.t("X position"), type: "number", fallback: 0, width: 120 },
                        { key: "monitors." + name + ".y", label: Tr.t("Y position"), type: "number", fallback: 0, width: 120 },
                        { key: "monitors." + name + ".off", label: Tr.t("Turn off this monitor"), type: "toggle", fallback: false }
                    ]
                });
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

        function bind(name, label) {
            return { key: "binds." + name, label: label, type: "text", width: 200 };
        }

        readonly property var groups: [Tr.t("Personalization"), Tr.t("Workspace"), Tr.t("Input"), Tr.t("Other")]

        readonly property var pages: [
            {
                title: Tr.t("Appearance"),
                subtitle: Tr.t("Language, colors, fonts and cursor"),
                icon: "palette",
                group: 0,
                sections: [
                    {
                        title: Tr.t("Theme"),
                        items: [
                            { key: "appearance.language", label: Tr.t("Language"), type: "choice", options: ["auto", "en", "ru"], names: [Tr.t("Automatic"), "English", "Русский"], fallback: "auto" },
                            { key: "appearance.mode", label: Tr.t("Mode"), type: "choice", options: ["dark", "light"], names: [Tr.t("Dark"), Tr.t("Light")] },
                            { key: "appearance.accent", label: Tr.t("Accent color"), type: "color", autoText: Tr.t("From wallpaper"), colors: ["#7aa2f7", "#bb9af7", "#f7768e", "#ff9e64", "#e0af68", "#9ece6a", "#2ac3de", "#c0caf5"] },
                            { key: "appearance.scheme", label: Tr.t("Color style"), type: "choice", layout: "chips", options: ["scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-fidelity", "scheme-content", "scheme-neutral", "scheme-monochrome", "scheme-rainbow", "scheme-fruit-salad"], names: [Tr.t("Tonal"), Tr.t("Vibrant"), Tr.t("Expressive"), Tr.t("Faithful"), Tr.t("Content"), Tr.t("Neutral"), Tr.t("Monochrome"), Tr.t("Rainbow"), Tr.t("Fruit salad")] }
                        ]
                    },
                    {
                        title: Tr.t("Text"),
                        items: [
                            { key: "appearance.font", label: Tr.t("Font"), type: "text" },
                            { key: "appearance.fontScale", label: Tr.t("Text size"), type: "slider", min: 0.8, max: 1.3, step: 0.05, unit: "percent" }
                        ]
                    },
                    {
                        title: Tr.t("Cursor"),
                        items: [
                            { key: "appearance.cursorTheme", label: Tr.t("Cursor theme"), type: "text" },
                            { key: "appearance.cursorSize", label: Tr.t("Cursor size"), type: "slider", min: 16, max: 48, step: 2, unit: "px" },
                            { key: "appearance.cursorHideTyping", label: Tr.t("Hide cursor while typing"), type: "toggle" },
                            { key: "appearance.cursorHideAfter", label: Tr.t("Hide idle cursor after"), type: "slider", min: 0, max: 60, step: 1, unit: "time" }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Wallpaper"),
                subtitle: Tr.t("Folder and how wallpapers change"),
                icon: "wallpaper",
                group: 0,
                sections: [
                    {
                        title: Tr.t("Wallpapers"),
                        items: [
                            { key: "wallpaperDir", label: Tr.t("Wallpaper folder"), type: "text" },
                            { label: Tr.t("Choose a wallpaper"), type: "action", text: Tr.t("Open"), run: () => { Ui.settingsOpen = false; Ui.popup = "wallpapers"; } }
                        ]
                    },
                    {
                        title: Tr.t("Change by itself"),
                        items: [
                            { key: "wallpaper.auto", label: Tr.t("Mode"), hint: Tr.t("A wallpaper you choose yourself stays until the next change"), type: "choice", options: ["off", "slideshow", "dayNight"], names: [Tr.t("Off"), Tr.t("Slideshow"), Tr.t("Day and night")] },
                            { key: "wallpaper.slideshowEvery", label: Tr.t("Slideshow: change every"), hint: Tr.t("It waits while you are away or a live wallpaper is on"), type: "slider", min: 300, max: 14400, step: 300, unit: "time" },
                            { key: "wallpaper.slideshowOrder", label: Tr.t("Slideshow: order"), type: "choice", options: ["random", "name"], names: [Tr.t("Random"), Tr.t("By name")] },
                            { key: "wallpaper.slideshowOnBattery", label: Tr.t("Slideshow: also on battery"), type: "toggle" },
                            { key: "wallpaper.day", label: Tr.t("Day wallpaper"), type: "text" },
                            { label: Tr.t("Use the current wallpaper for the day"), type: "action", text: Tr.t("Use"), run: () => WallpaperAuto.useCurrentFor("day") },
                            { key: "wallpaper.night", label: Tr.t("Night wallpaper"), type: "text" },
                            { label: Tr.t("Use the current wallpaper for the night"), type: "action", text: Tr.t("Use"), run: () => WallpaperAuto.useCurrentFor("night") },
                            { key: "schedule.lightFrom", label: Tr.t("Day starts"), hint: Tr.t("The same times as light and dark mode"), type: "text", width: 100 },
                            { key: "schedule.darkFrom", label: Tr.t("Night starts"), type: "text", width: 100 }
                        ]
                    },
                    {
                        title: Tr.t("Transition"),
                        items: [
                            { key: "wallpaper.transition", label: Tr.t("Effect"), hint: Tr.t("Random picks another one each time"), type: "choice", layout: "chips", options: ["random", "grow", "fade", "wipe", "wave", "dissolve", "pixels", "blocks", "shatter", "glitch", "melt", "ripple", "zoom", "swirl", "blinds", "push", "none"], names: [Tr.t("Random"), Tr.t("Grow"), Tr.t("Fade"), Tr.t("Wipe"), Tr.t("Wave"), Tr.t("Dissolve"), Tr.t("Pixels"), Tr.t("Blocks"), Tr.t("Shatter"), Tr.t("Glitch"), Tr.t("Melt"), Tr.t("Ripple"), Tr.t("Zoom"), Tr.t("Swirl"), Tr.t("Blinds"), Tr.t("Push"), Tr.t("None")] },
                            { key: "wallpaper.duration", label: Tr.t("Duration"), type: "slider", min: 0.2, max: 4, step: 0.2, unit: "sec" }
                        ]
                    },
                    {
                        title: Tr.t("Depth"),
                        items: [
                            { key: "wallpaper.parallax", label: Tr.t("Parallax"), hint: Tr.t("The wallpaper slides a little as you move between workspaces"), type: "toggle" },
                            { key: "wallpaper.parallaxAmount", label: Tr.t("Parallax strength"), hint: Tr.t("How much taller than the screen the wallpaper is drawn"), type: "slider", min: 0.02, max: 0.2, step: 0.01, unit: "percent" }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Panel"),
                subtitle: Tr.t("Top bar, clock and notifications"),
                icon: "panel",
                group: 0,
                sections: [
                    {
                        title: Tr.t("Look"),
                        items: [
                            { key: "appearance.panelOpacity", label: Tr.t("Panel opacity"), hint: Tr.t("Lower is more see-through"), type: "slider", min: 0.15, max: 1, step: 0.05, unit: "percent" },
                            { key: "panel.position", label: Tr.t("Position"), type: "choice", options: ["top", "bottom"], names: [Tr.t("Top"), Tr.t("Bottom")] },
                            { key: "panel.style", label: Tr.t("Panel shape"), type: "choice", options: ["hug", "float"], names: [Tr.t("In the corners"), Tr.t("Floating")] }
                        ]
                    },
                    {
                        title: Tr.t("Dock"),
                        items: [
                            { key: "dock.enabled", label: Tr.t("Show the dock at the bottom edge"), hint: Tr.t("Right click an icon to pin or unpin it"), type: "toggle" }
                        ]
                    },
                    {
                        title: Tr.t("Clock"),
                        items: [
                            { key: "panel.clock24", label: Tr.t("24-hour clock"), type: "toggle" },
                            { key: "panel.clockSeconds", label: Tr.t("Seconds"), type: "toggle" },
                            { key: "panel.clockDate", label: Tr.t("Date"), type: "toggle" }
                        ]
                    },
                    {
                        title: Tr.t("Shown on the panel"),
                        items: [
                            { key: "panel.ribbon", label: Tr.t("Workspace numbers"), type: "toggle" },
                            { key: "panel.hideEmpty", label: Tr.t("Hide empty workspaces"), type: "toggle" },
                            { key: "panel.tray", label: Tr.t("Tray"), type: "toggle" },
                            { key: "panel.claude", label: Tr.t("Claude icon"), type: "toggle" },
                            { key: "panel.updates", label: Tr.t("Waiting updates"), type: "toggle" },
                            { key: "panel.privacy", label: Tr.t("Microphone and camera in use"), type: "toggle" },
                            { key: "panel.lang", label: Tr.t("Keyboard layout"), type: "toggle" },
                            { key: "panel.wifi", label: Tr.t("Wi-Fi icon"), type: "toggle" },
                            { key: "panel.volume", label: Tr.t("Volume"), type: "toggle" },
                            { key: "panel.battery", label: Tr.t("Battery"), type: "toggle" }
                        ]
                    },
                    {
                        title: Tr.t("Notifications"),
                        items: [
                            { key: "notifications.seconds", label: Tr.t("Notification duration"), type: "slider", min: 1, max: 15, step: 0.5, unit: "sec" }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Widgets"),
                subtitle: Tr.t("Clock, weather and notes on the desktop"),
                icon: "widgets",
                group: 0,
                sections: [
                    {
                        title: Tr.t("Desktop"),
                        items: [
                            { key: "widgets.enabled", label: Tr.t("Widgets on the desktop"), type: "toggle" },
                            { key: "widgets.firstOnly", label: Tr.t("Only on the first workspace"), type: "toggle" },
                            { key: "widgets.opacity", label: Tr.t("Widget opacity"), hint: Tr.t("Lower is more see-through"), type: "slider", min: 0.1, max: 1, step: 0.05, unit: "percent" },
                            { key: "widgets.followWallpaper", label: Tr.t("With a new wallpaper"), hint: Tr.t("A layout arranged by hand is remembered"), type: "choice", options: ["full", "place", "off"], names: [Tr.t("Place and form"), Tr.t("Place only"), Tr.t("Stay as they are")] },
                            { label: Tr.t("Move, add and remove widgets"), hint: Tr.t("Right click the desktop or press the shortcut"), type: "action", text: Tr.t("Edit widgets"), run: () => { Ui.settingsOpen = false; Widgets.editMode = true; } }
                        ]
                    },
                    {
                        title: Tr.t("Music"),
                        items: [
                            { key: "waves.enabled", label: Tr.t("Sound waves on the desktop"), hint: Tr.t("Along the bottom of the screen while music plays"), type: "toggle" },
                            { key: "waves.style", label: Tr.t("Style"), type: "choice", options: ["bars", "wave", "line", "dots"], names: [Tr.t("Bars"), Tr.t("Wave"), Tr.t("Line"), Tr.t("Dots")] },
                            { key: "waves.height", label: Tr.t("Height"), hint: Tr.t("Widgets stay above it"), type: "slider", min: 60, max: 320, step: 10, unit: "px" },
                            { key: "waves.opacity", label: Tr.t("Brightness"), type: "slider", min: 0.2, max: 1, step: 0.05, unit: "percent" },
                            { key: "waves.gain", label: Tr.t("Sensitivity"), hint: Tr.t("Higher moves more at the same sound"), type: "slider", min: 0.5, max: 2, step: 0.1, unit: "percent" },
                            { key: "waves.smoothing", label: Tr.t("Smoothness"), hint: Tr.t("Lower follows each beat more sharply"), type: "slider", min: 20, max: 300, step: 10, unit: "ms" },
                            { key: "waves.thickness", label: Tr.t("Thickness of bars and dots"), type: "choice", options: ["thick", "medium", "thin"], names: [Tr.t("Thick"), Tr.t("Medium"), Tr.t("Thin")] },
                            { key: "waves.mirror", label: Tr.t("From the middle to the sides"), hint: Tr.t("Off puts low notes on the left"), type: "toggle" },
                            { key: "waves.fromCover", label: Tr.t("Color of the album cover"), hint: Tr.t("Off uses the color below"), type: "toggle" },
                            { key: "waves.color", label: Tr.t("Color"), type: "color", autoText: Tr.t("From wallpaper"), colors: ["#7aa2f7", "#bb9af7", "#f7768e", "#ff9e64", "#e0af68", "#9ece6a", "#2ac3de", "#ffffff"] }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Windows"),
                subtitle: Tr.t("Layout, decoration and animations"),
                icon: "windows",
                group: 1,
                sections: [
                    {
                        title: Tr.t("Layout"),
                        items: [
                            { key: "windows.gaps", label: Tr.t("Gaps between windows"), type: "slider", min: 0, max: 40, step: 1, unit: "px" },
                            { key: "windows.edgeMargin", label: Tr.t("Margin from screen edges"), type: "slider", min: 0, max: 80, step: 2, unit: "px" },
                            { key: "windows.defaultWidth", label: Tr.t("New window width"), type: "choice", options: [0.33333, 0.5, 0.66667, 1], names: ["1/3", "1/2", "2/3", Tr.t("Full")] },
                            { key: "windows.centerFocused", label: Tr.t("Center focused column"), type: "choice", options: ["never", "on-overflow", "always"], names: [Tr.t("Never"), Tr.t("If it doesn't fit"), Tr.t("Always")] },
                            { key: "windows.centerSingle", label: Tr.t("Center a single window"), type: "toggle" },
                            { key: "windows.tabbedByDefault", label: Tr.t("Columns as tabs"), type: "toggle" }
                        ]
                    },
                    {
                        title: Tr.t("Decoration"),
                        items: [
                            { key: "windows.radius", label: Tr.t("Corner radius"), type: "slider", min: 0, max: 32, step: 1, unit: "px" },
                            { key: "windows.focusRing", label: Tr.t("Focus ring width"), type: "slider", min: 0, max: 8, step: 1, unit: "px" },
                            { key: "windows.inactiveOpacity", label: Tr.t("Inactive window opacity"), type: "slider", min: 0.4, max: 1, step: 0.02, unit: "percent" },
                            { key: "windows.shadow", label: Tr.t("Shadow"), type: "toggle" },
                            { key: "windows.shadowSoftness", label: Tr.t("Shadow softness"), type: "slider", min: 0, max: 80, step: 2, unit: "px" },
                            { key: "windows.blur", label: Tr.t("Blur"), type: "toggle" },
                            { key: "windows.blurStrength", label: Tr.t("Blur strength"), type: "slider", min: 1, max: 6, step: 1 }
                        ]
                    },
                    {
                        title: Tr.t("Behavior"),
                        items: [
                            { key: "windows.focusFollowsMouse", label: Tr.t("Focus follows cursor"), type: "toggle" },
                            { key: "windows.warpMouse", label: Tr.t("Cursor follows focus"), type: "toggle" },
                            { key: "windows.autoBackForth", label: Tr.t("Same number again goes to previous workspace"), type: "toggle" }
                        ]
                    },
                    {
                        title: Tr.t("Animations"),
                        items: [
                            { key: "windows.animations", label: Tr.t("Animations"), type: "toggle" },
                            { key: "windows.animationSpeed", label: Tr.t("Animation speed"), type: "slider", min: 0.3, max: 3, step: 0.1, unit: "scale" },
                            { key: "windows.overviewZoom", label: Tr.t("Overview zoom"), type: "slider", min: 0.25, max: 0.75, step: 0.01, unit: "percent" }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Window rules"),
                subtitle: Tr.t("How chosen apps open"),
                icon: "rules",
                group: 1,
                rules: true,
                sections: []
            },
            {
                title: Tr.t("Monitors"),
                subtitle: Tr.t("Scale, rotation and position"),
                icon: "monitor",
                group: 1,
                sections: [{
                    title: Tr.t("When a display is plugged in"),
                    items: [
                        { key: "monitorConnect", label: Tr.t("Current workspace"), hint: Tr.t("Each display keeps its own settings, on any port"), type: "choice", options: ["stay", "move"], names: [Tr.t("Stays here"), Tr.t("Moves to it")] }
                    ]
                }].concat(win.monitorSections)
            },
            {
                title: Tr.t("Keyboard"),
                subtitle: Tr.t("Layouts and key repeat"),
                icon: "keyboard",
                group: 2,
                sections: [
                    {
                        title: Tr.t("Layouts"),
                        items: [
                            { key: "keyboard.layouts", label: Tr.t("Layouts"), hint: Tr.t("Example: us,ru"), type: "text" },
                            { key: "keyboard.options", label: Tr.t("XKB options"), type: "text", width: 340 },
                            { key: "keyboard.perWindow", label: Tr.t("Remember layout per window"), type: "toggle" }
                        ]
                    },
                    {
                        title: Tr.t("Typing"),
                        items: [
                            { key: "keyboard.repeatDelay", label: Tr.t("Repeat delay"), type: "slider", min: 150, max: 800, step: 10, unit: "ms" },
                            { key: "keyboard.repeatRate", label: Tr.t("Repeat rate"), type: "slider", min: 10, max: 80, step: 1 },
                            { key: "keyboard.numlock", label: Tr.t("NumLock on"), type: "toggle" }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Mouse and touchpad"),
                subtitle: Tr.t("Speed, scrolling and clicks"),
                icon: "mouse",
                group: 2,
                sections: [
                    {
                        title: Tr.t("Touchpad"),
                        items: [
                            { key: "pointer.tap", label: Tr.t("Tap to click"), type: "toggle" },
                            { key: "pointer.naturalScroll", label: Tr.t("Natural scrolling"), type: "toggle" },
                            { key: "pointer.disableWhileTyping", label: Tr.t("Disable while typing"), type: "toggle" },
                            { key: "pointer.clickMethod", label: Tr.t("Right click"), type: "choice", options: ["button-areas", "clickfinger"], names: [Tr.t("Bottom right corner"), Tr.t("Two fingers")] },
                            { key: "pointer.touchpadSpeed", label: Tr.t("Touchpad speed"), type: "slider", min: -1, max: 1, step: 0.05 },
                            { key: "pointer.scrollFactor", label: Tr.t("Scroll speed"), type: "slider", min: 0.2, max: 3, step: 0.1, unit: "scale" }
                        ]
                    },
                    {
                        title: Tr.t("Mouse"),
                        items: [
                            { key: "pointer.mouseFlat", label: Tr.t("No mouse acceleration"), type: "toggle" },
                            { key: "pointer.mouseNaturalScroll", label: Tr.t("Natural scrolling"), type: "toggle" },
                            { key: "pointer.mouseSpeed", label: Tr.t("Mouse speed"), type: "slider", min: -1, max: 1, step: 0.05 }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Shortcuts"),
                subtitle: Tr.t("Example: Mod+Shift+T. Mod is the Super key"),
                icon: "shortcut",
                group: 2,
                sections: [
                    {
                        title: Tr.t("Panels and menus"),
                        items: [
                            win.bind("apps", Tr.t("Apps")),
                            win.bind("clipboard", Tr.t("Clipboard history")),
                            win.bind("dashboard", Tr.t("Dashboard")),
                            win.bind("control", Tr.t("Control center")),
                            win.bind("wallpapers", Tr.t("Wallpaper and color")),
                            win.bind("settings", Tr.t("Settings")),
                            win.bind("widgets", Tr.t("Edit widgets"))
                        ]
                    },
                    {
                        title: Tr.t("Apps"),
                        items: [
                            win.bind("terminal", Tr.t("Terminal")),
                            win.bind("scratch", Tr.t("Scratchpad terminal")),
                            win.bind("browser", Tr.t("Browser")),
                            win.bind("files", Tr.t("Files")),
                            win.bind("notes", Tr.t("Notes"))
                        ]
                    },
                    {
                        title: Tr.t("Windows"),
                        items: [
                            win.bind("close", Tr.t("Close window")),
                            win.bind("widthCycle", Tr.t("Column width")),
                            win.bind("maximize", Tr.t("Maximize column")),
                            win.bind("fullscreen", Tr.t("Fullscreen")),
                            win.bind("sticky", Tr.t("Sticky window")),
                            win.bind("overview", Tr.t("Overview")),
                            win.bind("zen", Tr.t("Focus mode"))
                        ]
                    },
                    {
                        title: Tr.t("Screen"),
                        items: [
                            win.bind("lock", Tr.t("Lock screen")),
                            win.bind("screenshot", Tr.t("Screenshot")),
                            win.bind("record", Tr.t("Record screen")),
                            win.bind("ocr", Tr.t("Copy text from screen")),
                            win.bind("translate", Tr.t("Translate from screen")),
                            win.bind("pin", Tr.t("Pin an area of the screen"))
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Sound"),
                subtitle: Tr.t("Sound output and microphone"),
                icon: "volume",
                group: 3,
                sound: true,
                sections: [
                    {
                        title: Tr.t("Hearing protection"),
                        items: [
                            { key: "audio.protection", label: Tr.t("Stop sudden volume jumps"), hint: Tr.t("An app or a new device cannot make it much louder at once"), type: "toggle" },
                            { key: "audio.maxStep", label: Tr.t("Largest jump"), hint: Tr.t("The volume keys move by 5%"), type: "slider", min: 0.05, max: 0.5, step: 0.05, unit: "percent" },
                            { key: "audio.maxVolume", label: Tr.t("Maximum volume"), type: "slider", min: 0.3, max: 1, step: 0.05, unit: "percent" }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Battery and power"),
                subtitle: Tr.t("Charge limit and power mode"),
                icon: "charging",
                group: 3,
                power: true,
                sections: [
                    {
                        title: Tr.t("Charge limit"),
                        items: [
                            { key: "power.chargeLimitOn", label: Tr.t("Stop charging early"), hint: Tr.t("Good when the laptop mostly stays on the charger"), type: "toggle" },
                            { key: "power.chargeLimit", label: Tr.t("Stop at"), type: "slider", min: 50, max: 100, step: 5, unit: "lineHeight" }
                        ]
                    },
                    {
                        title: Tr.t("Power mode"),
                        items: [
                            { key: "power.auto", label: Tr.t("Follow the charger"), hint: Tr.t("A mode you choose yourself stays until the charger changes"), type: "toggle" },
                            { key: "power.onBattery", label: Tr.t("On battery"), type: "choice", options: ["power-saver", "balanced", "performance"], names: [Tr.t("Saver"), Tr.t("Balanced"), Tr.t("Performance")] },
                            { key: "power.onCharger", label: Tr.t("On the charger"), type: "choice", options: ["power-saver", "balanced", "performance"], names: [Tr.t("Saver"), Tr.t("Balanced"), Tr.t("Performance")] }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Terminal"),
                subtitle: Tr.t("Kitty look. Some changes apply to new windows"),
                icon: "terminal",
                group: 3,
                sections: [
                    {
                        title: Tr.t("Look"),
                        items: [
                            { key: "appearance.monoFont", label: Tr.t("Terminal font"), type: "text" },
                            { key: "appearance.terminalFontSize", label: Tr.t("Terminal font size"), type: "slider", min: 8, max: 20, step: 1, unit: "px" },
                            { key: "appearance.terminalOpacity", label: Tr.t("Terminal opacity"), type: "slider", min: 0.3, max: 1, step: 0.02, unit: "percent" },
                            { key: "terminal.lineHeight", label: Tr.t("Line height"), type: "slider", min: 100, max: 160, step: 5, unit: "lineHeight" },
                            { key: "terminal.padding", label: Tr.t("Padding"), type: "slider", min: 0, max: 40, step: 2, unit: "px" }
                        ]
                    },
                    {
                        title: Tr.t("Cursor"),
                        items: [
                            { key: "terminal.cursorShape", label: Tr.t("Cursor shape"), type: "choice", options: ["block", "beam", "underline"], names: [Tr.t("Block"), Tr.t("Beam"), Tr.t("Underline")] },
                            { key: "terminal.cursorBlink", label: Tr.t("Blinking cursor"), type: "toggle" }
                        ]
                    },
                    {
                        title: Tr.t("History"),
                        items: [
                            { key: "terminal.scrollback", label: Tr.t("Scrollback lines"), type: "slider", min: 1000, max: 50000, step: 1000, unit: "lines" }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Fastfetch"),
                subtitle: Tr.t("The greeting of a new terminal. Applies to new windows"),
                icon: "sparkle",
                group: 3,
                fetch: true,
                sections: [
                    {
                        title: Tr.t("Greeting"),
                        items: [
                            { key: "fetch.enabled", label: Tr.t("Show fastfetch in new terminals"), type: "toggle" },
                            { key: "fetch.seconds", label: Tr.t("Length of one loop"), hint: Tr.t("Lower is faster"), type: "slider", min: 1.5, max: 8, step: 0.1, unit: "sec" }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("Telegram bot"),
                subtitle: Tr.t("Control this computer from the phone"),
                icon: "send",
                group: 3,
                remote: true,
                sections: [
                    {
                        title: Tr.t("Bot"),
                        items: [
                            { key: "remote.enabled", label: Tr.t("Remote control through Telegram"), hint: Tr.t("Starts with the computer, even before you log in"), type: "toggle" },
                            { label: Tr.t("Bot token"), hint: Tr.t("From @BotFather. Kept in a file only you can read"), type: "secret", placeholder: Tr.t("Paste and press Enter"), width: 260, run: value => { if (value.trim() !== "") { Quickshell.execDetached({ command: ["falcon-remote", "token"], environment: { FALCON_TOKEN: value.trim() } }); Toasts.show(Tr.t("Token saved"), Tr.t("The bot restarts with it"), "check"); } } },
                            { key: "remote.owner", label: Tr.t("Your Telegram ID"), hint: Tr.t("Only this account can use the bot. The bot tells you your ID"), type: "text", width: 160 }
                        ]
                    },
                    {
                        title: Tr.t("Allowed from the phone"),
                        items: [
                            { key: "remote.terminalRoot", label: Tr.t("Allow root in the terminal"), hint: Tr.t("The terminal switches between your user and root. Root asks your password once"), type: "toggle" },
                            { key: "remote.screen", label: Tr.t("Screenshots of the screen and windows"), type: "toggle" },
                            { key: "remote.power", label: Tr.t("Sleep, restart and shut down"), type: "toggle" },
                            { key: "remote.chatClipboard", label: Tr.t("Messages to the bot go to the clipboard"), hint: Tr.t("Text and pictures. Files are saved to Downloads"), type: "toggle" },
                            { key: "remote.notifyBoot", label: Tr.t("Message when the computer starts"), type: "toggle" }
                        ]
                    },
                    {
                        title: Tr.t("Token"),
                        items: [
                            { label: Tr.t("Forget the token"), hint: Tr.t("The bot stops until a new token is pasted"), type: "action", danger: true, text: Tr.t("Forget"), confirm: Tr.t("Press to confirm"), run: () => { Quickshell.execDetached(["falcon-remote", "token", "--clear"]); Toasts.show(Tr.t("Token removed"), "", "check"); } }
                        ]
                    }
                ]
            },
            {
                title: Tr.t("System"),
                subtitle: Tr.t("Power, schedules, weather and reset"),
                icon: "chip",
                group: 3,
                sections: [
                    {
                        title: Tr.t("Session and power"),
                        items: [
                            { key: "session.restore", label: Tr.t("Restore windows at login"), type: "toggle" },
                            { key: "session.lockScreen", label: Tr.t("Lock screen style"), hint: Tr.t("The shell one matches the panels and has had less testing"), type: "choice", options: ["hyprlock", "shell"], names: [Tr.t("Standard"), Tr.t("Shell")] },
                        ]
                    },
                    {
                        title: Tr.t("On the charger"),
                        items: [
                            { key: "idle.lock", label: Tr.t("Lock after"), type: "slider", min: 0, max: 3600, step: 60, unit: "time" },
                            { key: "idle.screenOff", label: Tr.t("Screen off after"), type: "slider", min: 0, max: 3600, step: 60, unit: "time" },
                            { key: "idle.suspend", label: Tr.t("Sleep after"), type: "slider", min: 0, max: 7200, step: 60, unit: "time" }
                        ]
                    },
                    {
                        title: Tr.t("On battery"),
                        items: [
                            { key: "idle.battery.lock", label: Tr.t("Lock after"), type: "slider", min: 0, max: 3600, step: 60, unit: "time" },
                            { key: "idle.battery.screenOff", label: Tr.t("Screen off after"), type: "slider", min: 0, max: 3600, step: 60, unit: "time" },
                            { key: "idle.battery.suspend", label: Tr.t("Sleep after"), type: "slider", min: 0, max: 7200, step: 60, unit: "time" }
                        ]
                    },
                    {
                        title: Tr.t("System updates"),
                        items: [
                            { key: "updates.enabled", label: Tr.t("Check for updates"), hint: Tr.t("Only looks. Installing always asks you first"), type: "toggle" },
                            { key: "updates.hours", label: Tr.t("Check every (hours)"), type: "slider", min: 1, max: 24, step: 1 }
                        ]
                    },
                    {
                        title: Tr.t("Timer"),
                        items: [
                            { key: "timer.sound", label: Tr.t("Sound when it ends"), hint: Tr.t("Silent mode turns it off too"), type: "toggle" },
                            { key: "timer.work", label: Tr.t("Pomodoro: work (min)"), type: "slider", min: 5, max: 90, step: 5 },
                            { key: "timer.shortBreak", label: Tr.t("Pomodoro: break (min)"), type: "slider", min: 1, max: 30, step: 1 },
                            { key: "timer.longBreak", label: Tr.t("Pomodoro: every fourth break (min)"), type: "slider", min: 5, max: 60, step: 5 }
                        ]
                    },
                    {
                        title: Tr.t("Light and dark by time"),
                        items: [
                            { key: "schedule.mode", label: Tr.t("Switch light and dark by time"), type: "toggle" },
                            { key: "schedule.lightFrom", label: Tr.t("Light mode starts"), type: "text", width: 100 },
                            { key: "schedule.darkFrom", label: Tr.t("Dark mode starts"), type: "text", width: 100 }
                        ]
                    },
                    {
                        title: Tr.t("Night light"),
                        items: [
                            { key: "nightlight.auto", label: Tr.t("Night light schedule"), type: "toggle" },
                            { key: "nightlight.from", label: Tr.t("Night light starts"), type: "text", width: 100 },
                            { key: "nightlight.to", label: Tr.t("Night light ends"), type: "text", width: 100 },
                            { key: "nightlight.temperature", label: Tr.t("Night light temperature"), type: "slider", min: 2500, max: 6000, step: 100, unit: "kelvin" }
                        ]
                    },
                    {
                        title: Tr.t("Weather"),
                        items: [
                            { key: "weather.enabled", label: Tr.t("Weather"), type: "toggle" },
                            { key: "weather.unit", label: Tr.t("Temperature"), type: "choice", options: ["celsius", "fahrenheit"], names: ["°C", "°F"] },
                            { key: "weather.lat", label: Tr.t("Latitude"), type: "number", width: 120 },
                            { key: "weather.lon", label: Tr.t("Longitude"), type: "number", width: 120 }
                        ]
                    },
                    {
                        title: Tr.t("Translation"),
                        items: [
                            { key: "translate.to", label: Tr.t("Translate to"), hint: Tr.t("ru, en, de. Empty means the interface language"), type: "text", width: 120, fallback: "" }
                        ]
                    },
                    {
                        title: Tr.t("Reset"),
                        items: [
                            { label: Tr.t("Restore default values"), hint: Tr.t("Location and wallpaper folder are kept"), type: "action", danger: true, text: Tr.t("Reset to defaults"), confirm: Tr.t("Press to confirm"), run: () => { Settings.resetAll(); Toasts.show(Tr.t("Settings reset"), Tr.t("Location was kept"), "check"); } }
                        ]
                    }
                ]
            }
        ]

        readonly property var shown: {
            const q = filter.trim().toLowerCase();
            if (q === "")
                return pages[page].sections;
            let found = [];
            for (const p of pages) {
                let items = [];
                for (const s of p.sections)
                    items = items.concat(s.items.filter(i => (i.label + " " + (i.hint || "") + " " + (i.text || "") + " " + (i.key || "")).toLowerCase().indexOf(q) >= 0));
                if (items.length > 0)
                    found.push({ title: p.title, items: items });
            }
            return found;
        }

        readonly property int tabHeight: 36
        readonly property int groupHeight: 28

        title: "falcon settings"
        implicitWidth: 1000
        implicitHeight: 720
        color: Theme.pill
        visible: true
        onVisibleChanged: {
            if (!visible)
                Ui.settingsOpen = false;
        }

        // A soft wash of the theme color from the top.
        Rectangle {
            width: parent.width
            height: 220
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

        Item {
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

            // Sidebar
            Rectangle {
                id: sidebar

                width: 248
                height: parent.height
                color: Qt.alpha(Theme.text, 0.03)

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: Qt.alpha(Theme.text, 0.07)
                }

                Row {
                    id: brand

                    x: 20
                    y: 20
                    spacing: 11

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 11
                        color: Qt.alpha(Theme.accent, 0.2)

                        Icon {
                            anchors.centerIn: parent
                            name: "settings"
                            size: 19
                            color: Theme.accent
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tr.t("Settings")
                        size: 18
                        font.weight: Font.DemiBold
                    }
                }

                // Search
                Rectangle {
                    id: searchBox

                    x: 14
                    y: 66
                    width: parent.width - 28
                    height: 36
                    radius: 11
                    color: Qt.alpha(Theme.text, search.activeFocus ? 0.1 : 0.07)

                    Icon {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: 15
                        color: Theme.muted
                    }
                    TextInput {
                        id: search

                        anchors.fill: parent
                        leftPadding: 34
                        rightPadding: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: 13
                        clip: true
                        focus: true
                        onTextChanged: win.filter = text
                        Keys.onEscapePressed: Ui.settingsOpen = false
                    }
                    Label {
                        x: 34
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: Tr.t("Search settings…")
                        color: Qt.alpha(Theme.text, 0.4)
                        size: 13
                    }
                }

                // Pages, in groups
                Flickable {
                    id: sideList

                    Component.onCompleted: win.ensureTabVisible()
                    x: 14
                    y: 108
                    width: parent.width - 28
                    height: parent.height - y - 8
                    contentHeight: tabs.height + 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Item {
                        id: tabs

                        width: parent.width
                        height: win.pages.length * win.tabHeight + win.groups.length * win.groupHeight

                        // The highlight slides between pages.
                        Rectangle {
                            y: win.page * win.tabHeight + (win.pages[win.page].group + 1) * win.groupHeight
                            width: parent.width
                            height: win.tabHeight - 2
                            radius: 11
                            color: Theme.accent
                            opacity: win.filter === "" ? 1 : 0

                            Behavior on y {
                                NumberAnimation {
                                    duration: 420
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.3, 1.25, 0.4, 1, 1, 1]
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                }
                            }
                        }

                        Column {
                            width: parent.width

                            Repeater {
                                model: win.pages

                                delegate: Column {
                                    id: tab

                                    required property var modelData
                                    required property int index

                                    readonly property bool current: win.page === index && win.filter === ""
                                    readonly property bool opensGroup: index === 0 || win.pages[index - 1].group !== modelData.group

                                    width: parent.width

                                    Item {
                                        visible: tab.opensGroup
                                        width: parent.width
                                        height: win.groupHeight

                                        Label {
                                            x: 12
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 7
                                            text: win.groups[tab.modelData.group]
                                            color: Theme.muted
                                            size: 11
                                            font.weight: Font.Medium
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: win.tabHeight - 2
                                        radius: 11
                                        color: !tab.current && tabArea.containsMouse ? Qt.alpha(Theme.text, 0.07) : "transparent"

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 130
                                            }
                                        }

                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: 12
                                            spacing: 11
                                            scale: tabArea.pressed ? 0.97 : 1

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: 110
                                                }
                                            }

                                            Icon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                name: tab.modelData.icon
                                                size: 16
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
                                                Ui.settingsPage = tab.index;
                                            }
                                        }
                                    }

                                    Item {
                                        width: 1
                                        height: 2
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Content
            Item {
                x: sidebar.width
                width: parent.width - sidebar.width
                height: parent.height

                Row {
                    id: pageHeader

                    x: 28
                    y: 22
                    spacing: 14

                    Rectangle {
                        width: 46
                        height: 46
                        radius: 15
                        color: Qt.alpha(Theme.accent, 0.18)

                        Icon {
                            anchors.centerIn: parent
                            name: win.filter === "" ? win.pages[win.page].icon : "search"
                            size: 23
                            color: Theme.accent
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Label {
                            text: win.filter === "" ? win.pages[win.page].title : Tr.t("Search results")
                            size: 22
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: win.filter === "" ? win.pages[win.page].subtitle : win.filter
                            color: Theme.muted
                            size: 13
                        }
                    }
                }

                Flickable {
                    id: scroller

                    y: 86
                    width: parent.width
                    height: parent.height - y
                    contentHeight: cards.implicitHeight + 28
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: cards

                        x: 28
                        width: scroller.width - 56
                        spacing: 16

                        RemoteStatus {
                            visible: win.filter === "" && !!win.pages[win.page].remote
                            width: cards.width
                        }

                        FetchStudio {
                            visible: win.filter === "" && !!win.pages[win.page].fetch
                            width: cards.width
                        }

                        Repeater {
                            model: win.shown

                            // Cards rise one after another when the page changes, at once while searching.
                            delegate: Reveal {
                                id: section

                                required property var modelData
                                required property int index

                                width: cards.width
                                animate: win.filter === ""
                                delay: Math.min(index, 5) * 40

                                Column {
                                    width: parent.width
                                    spacing: 7

                                    Label {
                                        x: 6
                                        text: section.modelData.title
                                        color: Theme.muted
                                        size: 12
                                        font.weight: Font.Medium
                                    }
                                    Rectangle {
                                        width: parent.width
                                        height: rows.implicitHeight + 8
                                        radius: 18
                                        color: Qt.alpha(Theme.text, 0.045)
                                        border.width: 1
                                        border.color: Qt.alpha(Theme.text, 0.06)

                                        Column {
                                            id: rows

                                            x: 18
                                            y: 4
                                            width: parent.width - 36

                                            Repeater {
                                                model: section.modelData.items

                                                delegate: Column {
                                                    id: rowHolder

                                                    required property var modelData
                                                    required property int index

                                                    width: rows.width

                                                    Rectangle {
                                                        visible: rowHolder.index > 0
                                                        width: parent.width
                                                        height: 1
                                                        color: Qt.alpha(Theme.text, 0.06)
                                                    }
                                                    SettingRow {
                                                        width: parent.width
                                                        item: rowHolder.modelData
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Label {
                            visible: win.filter !== "" && win.shown.length === 0
                            text: Tr.t("Nothing found")
                            color: Theme.muted
                        }

                        RulesEditor {
                            visible: win.filter === "" && !!win.pages[win.page].rules
                            width: cards.width
                        }

                        SoundDevices {
                            visible: win.filter === "" && !!win.pages[win.page].sound
                            width: cards.width
                        }

                        PowerCare {
                            visible: win.filter === "" && !!win.pages[win.page].power
                            width: cards.width
                        }
                    }
                }

                // Thin scrollbar, only while there is more to see.
                Rectangle {
                    visible: scroller.contentHeight > scroller.height
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    y: scroller.y + scroller.visibleArea.yPosition * scroller.height
                    width: 4
                    height: scroller.visibleArea.heightRatio * scroller.height
                    radius: 2
                    color: Qt.alpha(Theme.text, 0.18)
                }
            }
        }
    }
}
