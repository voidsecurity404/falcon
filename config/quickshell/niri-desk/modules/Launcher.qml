import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services
import "../services/tools.js" as Tools

// Bitta qidiruv oynasi: dasturlar, oynalar, clipboard, hisoblash, buyruq va tizim amallari.
LazyLoader {
    active: Ui.popup === "launcher" || Ui.popup === "clipboard"

    PanelWindow {
        id: root

        readonly property bool clipboardOnly: Ui.popup === "clipboard"
        property string query: ""
        property int selected: 0
        onSelectedChanged: Ui.launcherSelected = selected
        Component.onCompleted: {
            Ui.launcherSelected = 0;
            Ui.launcherRows = results.map(r => r.section + "|" + r.name);
        }
        property var clips: []
        property var lastPointer: null
        property string fileQuery: ""
        property var files: []

        onFileQueryChanged: fileTimer.restart()

        Connections {
            target: Ui
            function onLauncherInject(text) {
                input.text = text;
            }
        }

        Timer {
            id: fileTimer

            interval: 180
            onTriggered: {
                if (root.fileQuery.length < 2) {
                    root.files = [];
                    return;
                }
                filesProc.running = false;
                filesProc.command = ["fd", "--fixed-strings", "--ignore-case", "--max-results", "30", "--type", "f", "--", root.fileQuery, Settings.home];
                filesProc.running = true;
            }
        }

        Process {
            id: filesProc

            stdout: StdioCollector {
                onStreamFinished: root.files = text.split("\n").filter(l => l.length > 0)
            }
        }

        // Oyna ochilganda kursor tagida qolgan qator tanlanib ketmasin: faqat haqiqiy harakat hisoblanadi.
        function pointerMoved(index, point) {
            if (lastPointer && Math.abs(lastPointer.x - point.x) + Math.abs(lastPointer.y - point.y) > 3)
                selected = index;
            lastPointer = point;
        }

        readonly property var actions: [
            {
                name: Tr.t("Settings"),
                detail: "Mod+,",
                keywords: "settings config настройки",
                always: true,
                run: () => Ui.settingsOpen = true
            },
            {
                name: Tr.t("Change wallpaper"),
                detail: Tr.t("wallpaper and color"),
                keywords: "wallpaper color обои цвет",
                always: true,
                run: () => Ui.popup = "wallpapers"
            },
            {
                name: Tr.t("Focus mode"),
                detail: "Mod+F",
                keywords: "zen",
                always: true,
                run: () => Ui.run("niri-desk-zen")
            },
            {
                name: Tr.t("Record screen"),
                detail: "Mod+Shift+R",
                keywords: "record video запись видео",
                always: true,
                run: () => Ui.run("niri-desk-record")
            },
            {
                name: Tr.t("Translate from screen"),
                detail: "Mod+Alt+P",
                keywords: "translate перевод",
                always: false,
                run: () => Ui.run("niri-desk-translate")
            },
            {
                name: Tr.t("Back up settings to a file"),
                detail: Tr.t("backup"),
                keywords: "backup export копия",
                always: false,
                run: () => {
                    Ui.run("niri-desk-backup", "export");
                    Toasts.show(Tr.t("Backup saved"), Tr.t("In your home folder: niri-desk-settings-*.tar.gz"), "check");
                }
            },
            {
                name: Tr.t("Restore windows"),
                detail: Tr.t("last session"),
                keywords: "session restore сеанс восстановить",
                always: false,
                run: () => Ui.run("niri-desk-session", "restore", "--force")
            },
            {
                name: Tr.t("Pick color from screen"),
                detail: Tr.t("copies hex"),
                keywords: "color picker цвет",
                always: false,
                run: () => Ui.run("niri-desk-color")
            },
            {
                name: Tr.t("Network settings"),
                detail: "nmtui",
                keywords: "wifi network internet сеть",
                always: false,
                run: () => Quickshell.execDetached(["kitty", "--class", "niri-desk-tool", "nmtui"])
            },
            {
                name: Tr.t("Bluetooth devices"),
                detail: "bluetui",
                keywords: "bluetooth headphones наушники",
                always: false,
                run: () => Quickshell.execDetached(["kitty", "--class", "niri-desk-tool", "bluetui"])
            },
            {
                name: Tr.t("System monitor"),
                detail: "btop",
                keywords: "cpu process task процессы",
                always: false,
                run: () => Quickshell.execDetached(["kitty", "--class", "niri-desk-tool", "btop"])
            },
            {
                name: Tr.t("Copy text from screen"),
                detail: "Mod+P",
                keywords: "ocr tesseract текст",
                always: false,
                run: () => Ui.run("niri-desk-ocr")
            },
            {
                name: Tr.t("Lock screen"),
                detail: "Mod+X",
                keywords: "lock",
                always: false,
                run: () => Quickshell.execDetached(["loginctl", "lock-session"])
            },
            {
                name: Tr.t("Sleep"),
                detail: Tr.t("System"),
                keywords: "sleep suspend сон",
                always: false,
                run: () => Quickshell.execDetached(["systemctl", "suspend"])
            },
            {
                name: Tr.t("Reboot"),
                detail: Tr.t("System"),
                keywords: "reboot restart перезагрузка",
                always: false,
                run: () => Quickshell.execDetached(["systemctl", "reboot"])
            },
            {
                name: Tr.t("Shut down"),
                detail: Tr.t("System"),
                keywords: "shutdown poweroff выключение",
                always: false,
                run: () => Quickshell.execDetached(["systemctl", "poweroff"])
            },
            {
                name: Tr.t("Log out"),
                detail: Tr.t("System"),
                keywords: "logout quit выход",
                always: false,
                run: () => Niri.action("quit")
            }
        ]

        readonly property var results: {
            const raw = query.trim();
            const q = raw.toLowerCase();
            const out = [];

            const copyRow = (section, label, value) => ({
                        section: section,
                        name: value || label,
                        detail: label,
                        run: () => {
                            if (value) {
                                Quickshell.clipboardText = value;
                                Toasts.show(Tr.t("Copied"), value, "check");
                            }
                        }
                    });

            // Maxsus rejimlar: birinchi belgi yoki buyruq nomi bilan ishlaydi.
            if (!clipboardOnly && raw.length > 0) {
                if (raw[0] === "=" || Tools.looksLikeMath(raw)) {
                    const expr = raw[0] === "=" ? raw.slice(1) : raw;
                    try {
                        out.push(copyRow(Tr.t("Calculator"), Tr.t("Enter: copy"), Tools.calc(expr)));
                    } catch (e) {
                        if (raw[0] === "=")
                            out.push(copyRow(Tr.t("Calculator"), Tr.t("incomplete expression"), ""));
                    }
                }
                if (raw[0] === ">" && raw.length > 1) {
                    const cmd = raw.slice(1).trim();
                    out.push({
                        section: Tr.t("Command"),
                        name: cmd,
                        detail: Tr.t("runs in a terminal"),
                        run: () => Quickshell.execDetached(["kitty", "sh", "-c", cmd + '\necho; printf "' + Tr.t("Press Enter to close") + '"; read _'])
                    });
                    return out;
                }
                if (raw[0] === "?" && raw.length > 1) {
                    const term = raw.slice(1).trim();
                    out.push({
                        section: Tr.t("Web"),
                        name: term,
                        detail: "DuckDuckGo",
                        run: () => Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(term)])
                    });
                    return out;
                }
                if (raw[0] === "/") {
                    const pattern = raw.slice(1).trim();
                    root.fileQuery = pattern;
                    if (pattern.length < 2) {
                        out.push({
                            section: Tr.t("Files"),
                            name: Tr.t("Type at least 2 letters"),
                            detail: "",
                            run: () => {}
                        });
                        return out;
                    }
                    for (const file of root.files.slice(0, 9)) {
                        const path = file;
                        out.push({
                            section: Tr.t("Files"),
                            name: path.split("/").pop(),
                            detail: path.replace(Settings.home, "~"),
                            run: () => Quickshell.execDetached(["xdg-open", path])
                        });
                    }
                    return out;
                }
                if (raw[0] === "@") {
                    const key = raw.slice(1).trim().toLowerCase();
                    for (const profile of Library.profiles.filter(p => String(p.name).toLowerCase().indexOf(key) >= 0)) {
                        const name = String(profile.name);
                        out.push({
                            section: Tr.t("Work profiles"),
                            name: name,
                            detail: Tr.t(profile.detail || ""),
                            run: () => Ui.run("niri-desk-profile", name)
                        });
                    }
                    return out;
                }
            }
            // Teng natijalarda asl tartib saqlanadi: clipboard'da eng yangisi tepada turadi.
            const rows = (items, nameOf, extraOf) => items.map((item, order) => ({
                            item: item,
                            order: order,
                            rank: Tools.score(nameOf(item), q, extraOf ? extraOf(item) : "")
                        })).filter(r => r.rank > 0).sort((a, b) => b.rank - a.rank || a.order - b.order);
            const allApps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
            const appExtra = a => a.genericName + " " + a.keywords.join(" ");

            // Aniq moslik bo'lsa, harflar bo'yicha taxminiy natijalar chiqmaydi.
            const exact = rows(allApps, a => a.name, appExtra).some(r => r.rank >= 300) || rows(actions, a => a.name, a => a.keywords).some(r => r.rank >= 300);
            const ranked = (items, nameOf, extraOf) => rows(items, nameOf, extraOf).filter(r => !exact || r.rank >= 300).map(r => r.item);

            if (!clipboardOnly) {
                const list = q === "" ? allApps.slice().sort((a, b) => a.name.localeCompare(b.name)) : ranked(allApps, a => a.name, appExtra);
                for (const app of list.slice(0, q === "" ? 5 : 7)) {
                    const entry = app;
                    out.push({
                        section: Tr.t("Apps"),
                        name: entry.name,
                        detail: entry.genericName || entry.comment,
                        run: () => entry.execute()
                    });
                }
            }

            // Ochiq oynalarga tez o'tish
            if (!clipboardOnly && q !== "") {
                const open = Object.values(Niri.windows);
                for (const w of ranked(open, x => (x.title || "") + " " + (x.app_id || "")).slice(0, 4)) {
                    const id = w.id;
                    out.push({
                        section: Tr.t("Open windows"),
                        name: w.title || w.app_id || Tr.t("Window"),
                        detail: w.app_id || "",
                        run: () => Niri.action("focus-window", "--id", String(id))
                    });
                }
            }

            for (const clip of ranked(clips, c => c.text).slice(0, clipboardOnly ? 10 : q === "" ? 3 : 4)) {
                const id = clip.id;
                out.push({
                    section: Tr.t("Clipboard"),
                    name: clip.text,
                    detail: "",
                    run: () => {
                        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", id]);
                        Toasts.show(Tr.t("Copied"), clip.text, "check");
                    }
                });
            }

            if (!clipboardOnly) {
                const available = q === "" ? actions.filter(a => a.always) : ranked(actions, a => a.name, a => a.keywords);
                // Nomi aynan mos kelgan amal kalit so'z orqali topilgan dasturdan yuqori turadi.
                const named = q !== "" && available.some(a => Tools.score(a.name, q, "") >= 800) && !allApps.some(a => Tools.score(a.name, q, "") >= 800);
                const actionRows = available.slice(0, 4).map(action => ({
                            section: Tr.t("Actions"),
                            name: action.name,
                            detail: action.detail,
                            run: action.run
                        }));
                if (named)
                    out.unshift(...actionRows);
                else
                    out.push(...actionRows);
            }
            return out;
        }

        function execute(index) {
            const entry = results[index];
            if (!entry)
                return;
            Ui.popup = "";
            entry.run();
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
        WlrLayershell.namespace: "niri-desk-launcher-scrim"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onResultsChanged: {
            selected = Math.min(selected, Math.max(0, results.length - 1));
            Ui.launcherRows = results.map(r => r.section + "|" + r.name);
        }

        Process {
            command: ["cliphist", "list"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    root.clips = text.split("\n").filter(l => /^\d+\t/.test(l)).map(l => {
                        const tab = l.indexOf("\t");
                        return {
                            id: l.slice(0, tab),
                            text: l.slice(tab + 1).trim()
                        };
                    });
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.popup = ""
        }

        Rectangle {
            id: card

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.17)
            width: Math.min(680, parent.width - 40)
            height: column.implicitHeight
            radius: 17
            color: Theme.pill

            opacity: 0
            scale: 0.98
            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: column

                width: parent.width

                TextInput {
                    id: input

                    width: parent.width
                    leftPadding: 24
                    rightPadding: 24
                    topPadding: 20
                    bottomPadding: 20
                    focus: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.family: Theme.sans
                    font.pixelSize: 24
                    font.weight: Font.Light
                    onTextChanged: {
                        root.query = text;
                        root.selected = 0;
                    }
                    Keys.onEscapePressed: Ui.popup = ""
                    Keys.onReturnPressed: root.execute(root.selected)
                    Keys.onEnterPressed: root.execute(root.selected)
                    Keys.onDownPressed: root.selected = Math.min(root.results.length - 1, root.selected + 1)
                    Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                    Keys.onTabPressed: root.selected = (root.selected + 1) % Math.max(1, root.results.length)

                    Label {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text === ""
                        text: root.clipboardOnly ? Tr.t("Search clipboard history…") : Tr.t("App, /file, @profile, =math, >command, ?web…")
                        color: Qt.alpha(Theme.text, 0.36)
                        size: 24
                        font.weight: Font.Light
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.text, 0.08)
                }

                Column {
                    width: parent.width - 16
                    x: 8
                    topPadding: 8
                    bottomPadding: 8

                    Label {
                        visible: root.results.length === 0
                        leftPadding: 14
                        topPadding: 8
                        bottomPadding: 8
                        text: root.clipboardOnly ? Tr.t("Clipboard history is empty") : Tr.t("Nothing found")
                        color: Theme.muted
                    }

                    Repeater {
                        model: root.results

                        delegate: Column {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property bool firstOfSection: index === 0 || root.results[index - 1].section !== modelData.section
                            readonly property bool isSelected: index === root.selected

                            width: parent.width

                            Label {
                                visible: row.firstOfSection
                                leftPadding: 14
                                topPadding: row.index === 0 ? 4 : 10
                                bottomPadding: 4
                                text: row.modelData.section
                                color: Qt.alpha(Theme.text, 0.42)
                                size: 12
                            }

                            Rectangle {
                                width: parent.width
                                height: 40
                                radius: 9
                                color: row.isSelected ? Theme.accent : "transparent"

                                Label {
                                    id: rowName

                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.right: rowDetail.left
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.modelData.name
                                    color: row.isSelected ? Theme.accentText : Theme.text
                                }
                                Label {
                                    id: rowDetail

                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 260)
                                    text: row.modelData.detail
                                    color: row.isSelected ? Qt.alpha(Theme.accentText, 0.72) : Qt.alpha(Theme.text, 0.42)
                                    size: 13
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
                    }
                }
            }
        }
    }
}
