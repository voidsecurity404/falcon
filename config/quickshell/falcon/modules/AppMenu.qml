import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services
import "../services/tools.js" as Tools

// App menu: rises from the bottom center of the screen. Typing searches apps, and ">" lists
// commands. The red button beside the search field opens the big power menu.
// The window stays built between openings, so it opens at once with its icons ready.
PanelWindow {
    id: root

    readonly property bool closing: Ui.popup !== "menu"
    // The menu floats above the bottom edge, and higher above a panel there.
    readonly property int edgeGap: Settings.bottom ? 56 : 14
    readonly property int rowHeight: 54
    readonly property int maxRows: 7
    readonly property int padding: 12
    readonly property var emphasized: [0.2, 0, 0, 1, 1, 1]

    property string query: ""
    property int selected: 0
    property real reveal: 0
    // Drives the rows and buttons that follow the card on opening, 0 to 1.
    property real stagger: 0
    // The pointer counts once it has really moved: a row left under it stays unselected at first.
    property var pointerStart: null
    property var pointerLast: null
    property bool pointerLive: false
    property real wheelRest: 0
    // Dangerous actions need a second press, this holds the first one.
    property string armed: ""
    readonly property bool commandMode: query[0] === ">" || query[0] === "Ю"
    readonly property string commandText: commandMode ? query.slice(1).replace(/^\s+/, "") : ""
    readonly property string commandWord: commandText.split(/\s+/)[0]
    readonly property string commandRest: commandText.slice(commandWord.length).trim()
    readonly property bool schemeMode: commandMode && wordIs(["scheme", "стиль"]) && commandText.length > commandWord.length
    readonly property bool calcMode: commandMode && wordIs(["calc", "счёт", "счет"]) && commandText.length > commandWord.length
    readonly property bool windowMode: commandMode && wordIs(["win", "окна"]) && commandText.length > commandWord.length
    readonly property bool emojiMode: commandMode && wordIs(["emoji", "эмодзи"]) && commandText.length > commandWord.length
    readonly property bool fileMode: commandMode && wordIs(["file", "файл"]) && commandText.length > commandWord.length
    readonly property bool timerMode: commandMode && wordIs(["timer", "таймер"]) && commandText.length > commandWord.length
    // "?" searches the web. "," is the same key on the Russian layout.
    readonly property bool webMode: query[0] === "?" || query[0] === ","
    readonly property string webText: webMode ? query.slice(1) : ""
    readonly property var webParts: Tools.webParts(webText)
    readonly property string mode: webMode ? "web" : timerMode ? "timer" : calcMode ? "calc" : schemeMode ? "scheme" : windowMode ? "windows" : emojiMode ? "emoji" : fileMode ? "files" : commandMode ? "commands" : "apps"

    property var emojiRows: []
    property bool emojiWanted: false
    property var fileRows: []
    // DuckDuckGo's instant answer for the words in `forText`: { forText, heading, text, url }.
    property var webAnswer: null

    // What is on screen follows the text. A change of mode first fades the old content away.
    property string shownMode: "apps"
    property var shownRows: []
    property var shownIds: []
    property var rowsById: ({})
    property real viewFade: 1

    readonly property var session: Session.items

    readonly property var commands: [
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
            id: "timer",
            icon: "timer",
            name: Tr.t("Timer"),
            detail: Countdown.active ? Countdown.text : Tr.t("Example: {e}").replace("{e}", ">timer 25"),
            keywords: "timer таймер countdown",
            complete: "timer "
        },
        {
            id: "pomodoro",
            icon: "focus",
            name: Tr.t("Pomodoro"),
            detail: Tr.t("{w} min of work, {b} min of break").replace("{w}", Settings.get("timer.work", 25)).replace("{b}", Settings.get("timer.shortBreak", 5)),
            keywords: "pomodoro помидор помодоро focus фокус",
            run: () => Countdown.pomodoro()
        },
        {
            id: "updates",
            icon: "update",
            name: Tr.t("Update the system"),
            detail: Updates.count > 0 ? Tr.t("{n} packages wait").replace("{n}", Updates.count) : Tr.t("Up to date when last checked"),
            keywords: "update upgrade обновить обновление pacman",
            run: () => Updates.open()
        },
        {
            id: "win",
            icon: "windows",
            name: Tr.t("Open windows"),
            detail: Tr.t("Go to a window"),
            keywords: "win windows окна",
            complete: "win "
        },
        {
            id: "file",
            icon: "note",
            name: Tr.t("Find a file"),
            detail: Tr.t("In the home folder"),
            keywords: "file find файл поиск",
            complete: "file "
        },
        {
            id: "emoji",
            icon: "sparkle",
            name: Tr.t("Emoji"),
            detail: Tr.t("Enter: copy"),
            keywords: "emoji эмодзи смайлик",
            complete: "emoji "
        },
        {
            id: "web",
            icon: "globe",
            name: Tr.t("Search the web"),
            detail: Tr.t("Type ? and the words, !yt for YouTube"),
            keywords: "web google search internet bang интернет поиск гугл",
            fill: "?"
        },
        {
            id: "game",
            icon: "game",
            name: GameMode.enabled ? Tr.t("Turn off game mode") : Tr.t("Game mode"),
            detail: Tr.t("No animations, full power, notifications wait"),
            keywords: "game gaming игра игровой режим steam",
            run: () => GameMode.toggle()
        },
        {
            id: "songrec",
            icon: "music",
            name: Tr.t("What song is this?"),
            detail: SongRec.listening ? Tr.t("Listening…") : Tr.t("Listens to what plays for 10 seconds"),
            keywords: "shazam song music recognize песня музыка узнать что играет",
            run: () => SongRec.recognize(false)
        },
        {
            id: "wallpapers",
            icon: "wallpaper",
            name: Tr.t("Wallpapers"),
            detail: Settings.get("binds.wallpapers", "Mod+W"),
            keywords: "wallpaper wallpapers background обои фон",
            run: () => Ui.popup = "wallpapers"
        },
        {
            id: "wallget",
            icon: "save",
            name: Tr.t("Download wallpapers"),
            detail: Tr.t("Wallhaven and MotionBGs"),
            keywords: "download wallpaper wallhaven motionbgs live скачать обои живые",
            run: () => Ui.popup = "wallget"
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
        if (webMode)
            return webRows();
        if (timerMode)
            return timerRows();
        if (calcMode)
            return calcRows();
        if (schemeMode)
            return schemeRows();
        if (windowMode)
            return windowRows();
        if (emojiMode)
            return emojiRanked(commandRest.toLowerCase().trim()).slice(0, 60);
        if (fileMode)
            return ranked(fileRows, r => r.name, r => r.detail, commandRest.toLowerCase());
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

    // Emoji by how well a name fits, in both languages: the whole name, then a whole word of it,
    // then the start of a word, then the keywords. Within each, the shorter name comes first,
    // so the plain red heart leads the hearts.
    function emojiRanked(q) {
        if (q === "")
            return emojiRows;
        const qs = [q, Tools.swapLayout(q)];
        const tierOf = row => {
            let best = -1;
            for (const name of [row.ru, row.en]) {
                const n = name.toLowerCase();
                const words = n.split(/[\s,:.\-]+/);
                for (const w of qs) {
                    if (n === w)
                        best = Math.max(best, 4);
                    else if (words.indexOf(w) >= 0)
                        best = Math.max(best, 3);
                    else if (words.some(x => x.startsWith(w)))
                        best = Math.max(best, 2);
                }
            }
            if (best < 0 && qs.some(w => row.keys.split(" ").some(k => k.startsWith(w))))
                best = 1;
            return best;
        };
        return emojiRows.map((row, order) => ({
                    row: row,
                    order: order,
                    tier: tierOf(row)
                })).filter(r => r.tier > 0).sort((a, b) => b.tier - a.tier || a.row.name.length - b.row.name.length || a.order - b.order).map(r => r.row);
    }

    // Opens a page and brings the browser forward, since niri leaves focus where it was.
    function openWeb(url) {
        Quickshell.execDetached(["sh", "-c", 'xdg-open "$1" >/dev/null 2>&1; sleep 0.5; "$HOME/.local/bin/falcon-raise" "firefox|chrom|brave|zen|helium" true >/dev/null 2>&1', "sh", url]);
    }

    function webRows() {
        const parts = webParts;
        const lang = Tr.language === "ru" ? "ru" : "en";
        const bangRow = b => ({
                id: "bang:" + b.id,
                icon: b.id === "g" ? "google" : "globe",
                name: b.name,
                detail: "!" + b.id,
                fill: "?!" + b.id + " "
            });
        // A bang being typed, or nothing typed yet: the list of sites.
        if (parts.partial !== null)
            return Tools.BANGS.filter(b => b.id.startsWith(parts.partial) || b.id.startsWith(Tools.swapLayout(parts.partial))).map(bangRow);
        if (webText.trim() === "")
            return Tools.BANGS.map(bangRow);

        const site = parts.bang || Tools.BANGS[0];
        const rows = [
            {
                id: "web:search",
                icon: site.id === "g" ? "google" : "globe",
                name: parts.query !== "" ? parts.query : site.name,
                detail: parts.query !== "" ? Tr.t("Search in {site}").replace("{site}", site.name) : Tr.t("Open {site}").replace("{site}", site.name),
                run: () => root.openWeb(Tools.bangUrl(site, parts.query, lang))
            }
        ];
        const address = parts.bang ? "" : Tools.asAddress(parts.query);
        if (address !== "") {
            const open = {
                id: "web:open",
                icon: "link",
                name: address.replace(/^https?:\/\//, ""),
                detail: Tr.t("Open the address"),
                run: () => root.openWeb(address)
            };
            // Typed with its scheme, the address is surely meant.
            if (/^\s*https?:/i.test(parts.query))
                rows.unshift(open);
            else
                rows.push(open);
        }
        const answer = webAnswer;
        if (!parts.bang && answer && !answer.empty && answer.forText === parts.query.trim())
            rows.push({
                id: "web:answer",
                icon: "note",
                name: answer.heading,
                detail: answer.text,
                run: () => root.openWeb(answer.url)
            });
        return rows;
    }

    function askAnswer() {
        const text = webMode && !webParts.bang && webParts.partial === null ? webParts.query.trim() : "";
        if (text.length < 3 || Tools.asAddress(text) !== "") {
            answerSearch.running = false;
            return;
        }
        if (webAnswer && webAnswer.forText === text)
            return;
        answerSearch.forText = text;
        answerSearch.exec(["curl", "-sf", "--max-time", "5", "-A", "falcon", "https://api.duckduckgo.com/?format=json&no_html=1&skip_disambig=1&no_redirect=1&t=falcon&q=" + encodeURIComponent(text)]);
    }

    function windowRows() {
        const rows = Object.keys(Niri.windows).map(key => {
            const w = Niri.windows[key];
            return {
                id: "win:" + w.id,
                image: Quickshell.iconPath(w.app_id || "", true),
                icon: "windows",
                name: w.title || w.app_id || "",
                detail: w.app_id || "",
                run: () => Niri.action("focus-window", "--id", String(w.id))
            };
        });
        return ranked(rows, r => r.name, r => r.detail, commandRest.toLowerCase());
    }

    function loadEmoji(content) {
        const russian = Settings.get("appearance.language", "ru") === "ru";
        emojiRows = JSON.parse(content).map(e => ({
                    id: "emoji:" + e.e,
                    glyph: e.e,
                    icon: "sparkle",
                    name: russian ? e.ru : e.en,
                    detail: "",
                    extra: e.ru + " " + e.en + " " + e.k,
                    ru: e.ru,
                    en: e.en,
                    keys: e.k.toLowerCase(),
                    run: () => {
                        Quickshell.clipboardText = e.e;
                        Toasts.show(Tr.t("Copied"), e.e, "check");
                    }
                }));
    }

    function searchFiles() {
        if (!fileMode || commandRest === "") {
            fileSearch.running = false;
            if (fileRows.length > 0)
                fileRows = [];
            return;
        }
        fileSearch.exec(["fd", "--type", "f", "--ignore-case", "--fixed-strings", "--max-results", "40", "--", commandRest, Quickshell.env("HOME")]);
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

    function timerRows() {
        const seconds = Countdown.parse(commandRest);
        const rows = [];
        if (seconds > 0)
            rows.push({
                id: "timer:start:" + seconds,
                icon: "timer",
                name: Tr.t("Start for {t}").replace("{t}", Countdown.format(seconds)),
                detail: Countdown.active ? Tr.t("Replaces the running timer") : Tr.t("Enter: start"),
                run: () => Countdown.start(seconds)
            });
        else if (commandRest !== "" && !/^[a-zа-яё]+$/i.test(commandRest))
            rows.push({
                id: "timer:bad",
                icon: "alert",
                name: Tr.t("Up to 24 hours. Examples: 25, 1:30, 90s, 1h"),
                detail: "",
                stay: true
            });
        const extra = Countdown.active ? [
            { id: "timer:pause", icon: "timer", name: Countdown.paused ? Tr.t("Continue") : Tr.t("Pause"), detail: Countdown.text, keywords: "pause пауза continue продолжить", run: () => Countdown.togglePause() },
            { id: "timer:add", icon: "timer", name: Tr.t("Add 5 minutes"), detail: Countdown.text, keywords: "add добавить", run: () => Countdown.add(300) },
            { id: "timer:stop", icon: "close", name: Tr.t("Stop the timer"), detail: Countdown.text, keywords: "stop стоп отмена cancel", run: () => Countdown.stop() }
        ] : [
            { id: "timer:5", icon: "timer", name: Tr.t("{n} min").replace("{n}", 5), detail: Tr.t("Enter: start"), keywords: "", run: () => Countdown.start(300) },
            { id: "timer:10", icon: "timer", name: Tr.t("{n} min").replace("{n}", 10), detail: Tr.t("Enter: start"), keywords: "", run: () => Countdown.start(600) },
            { id: "timer:25", icon: "timer", name: Tr.t("{n} min").replace("{n}", 25), detail: Tr.t("Enter: start"), keywords: "", run: () => Countdown.start(1500) }
        ];
        // A word filters them. Numbers already made the first row.
        const word = /^[a-zа-яё]+$/i.test(commandRest) ? commandRest.toLowerCase() : "";
        return rows.concat(extra.filter(r => word === "" ? seconds === 0 : (r.name + " " + r.keywords).toLowerCase().indexOf(word) >= 0));
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
        const item = results[index];
        if (!item)
            return;
        if (item.complete) {
            input.text = ">" + item.complete;
            return;
        }
        if (item.fill) {
            input.text = item.fill;
            return;
        }
        if (item.stay)
            return;
        // A click or Enter in the list counts the same as a session button.
        if (item.confirm !== undefined) {
            runSession(item);
            return;
        }
        Ui.popup = "";
        item.run();
    }

    // Qt also reports a move when rows slide under a pointer that stands still, so only a change of the
    // place on the screen counts. Otherwise the arrow keys and the wheel get pulled back to the pointer.
    function pointerMoved(point) {
        const moved = !!pointerLast && Math.abs(pointerLast.x - point.x) + Math.abs(pointerLast.y - point.y) > 0.5;
        pointerLast = point;
        if (!pointerStart)
            pointerStart = point;
        else if (Math.abs(pointerStart.x - point.x) + Math.abs(pointerStart.y - point.y) > 3)
            pointerLive = true;
        return pointerLive && moved;
    }

    // Selecting a row scrolls the list to it. A row only partly in view is left alone, so the pointer can
    // never scroll the list, which would bring the next row under it and scroll again.
    function rowInView(item) {
        return item.y >= list.contentY - 1 && item.y + item.height <= list.contentY + list.height + 1;
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
        fileTimer.stop();
        answerTimer.stop();
        answerSearch.running = false;
        input.text = "";
        armed = "";
        pointerStart = null;
        pointerLast = null;
        pointerLive = false;
        selected = 0;
        viewFade = 1;
        syncRows();
        list.positionViewAtBeginning();
    }

    onClosingChanged: {
        if (closing) {
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
        // Runs on every change: here the file mode binding may still hold its old value.
        fileTimer.restart();
        answerTimer.restart();
    }
    onEmojiModeChanged: {
        if (emojiMode)
            emojiWanted = true;
    }
    onModeChanged: modeSwap.restart()
    onResultsChanged: {
        if (mode === shownMode && !modeSwap.running)
            syncRows();
    }
    onSelectedChanged: Ui.launcherSelected = selected
    Component.onCompleted: syncRows()

    // The list is large, so it is read when the emoji mode is first opened.
    FileView {
        path: root.emojiWanted ? Quickshell.env("HOME") + "/.config/falcon/emoji.json" : ""
        printErrors: false
        onLoaded: root.loadEmoji(text())
    }

    Timer {
        id: answerTimer

        interval: 450
        onTriggered: root.askAnswer()
    }
    Process {
        id: answerSearch

        property string forText: ""

        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const answer = data.Answer && typeof data.Answer === "string" ? data.Answer : "";
                const summary = answer || data.AbstractText || data.Definition || "";
                if (summary === "") {
                    root.webAnswer = { forText: answerSearch.forText, heading: "", text: "", url: "", empty: true };
                    return;
                }
                root.webAnswer = {
                    forText: answerSearch.forText,
                    heading: data.Heading || answerSearch.forText,
                    text: summary + (data.AbstractSource ? " — " + data.AbstractSource : ""),
                    url: data.AbstractURL || data.DefinitionURL || ("https://duckduckgo.com/?q=" + encodeURIComponent(answerSearch.forText))
                };
            }
        }
    }

    Timer {
        id: fileTimer

        interval: 180
        onTriggered: root.searchFiles()
    }

    Process {
        id: fileSearch

        stdout: StdioCollector {
            onStreamFinished: {
                const home = Quickshell.env("HOME");
                root.fileRows = text.split("\n").filter(l => l !== "").map(path => ({
                            id: "file:" + path,
                            icon: "note",
                            name: path.slice(path.lastIndexOf("/") + 1),
                            detail: path.startsWith(home) ? "~" + path.slice(home.length) : path,
                            run: () => Quickshell.execDetached(["xdg-open", path])
                        }));
            }
        }
    }

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
    WlrLayershell.namespace: "falcon-menu"
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    mask: Region {
        item: catcher
    }
    BackgroundEffect.blurRegion: Region {
        item: card
        radius: card.radius
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
            script: root.syncRows()
        }
        NumberAnimation {
            target: root
            property: "viewFade"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        // Results that arrived during the fade, such as file search output.
        ScriptAction {
            script: {
                if (root.mode === root.shownMode)
                    root.syncRows();
            }
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

    Rectangle {
        id: card

        readonly property int bodyHeight: viewport.height + 10 + 46 + root.padding * 2

        x: Math.round((parent.width - width) / 2)
        y: parent.height - root.edgeGap - bodyHeight + (1 - root.reveal) * (bodyHeight + root.edgeGap + 4)
        width: 640
        height: bodyHeight
        radius: 26
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
            height: root.rowHeight * Math.min(root.maxRows, Math.max(1, root.shownRows.length))
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
                            Label {
                                anchors.centerIn: parent
                                visible: !!row.entry && !!row.entry.glyph
                                text: row.entry && row.entry.glyph ? row.entry.glyph : ""
                                size: 22
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: !row.hasImage && !(row.entry && row.entry.glyph)
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
                                text: row.isArmed ? (Session.warning !== "" ? Session.warning : Tr.t("Press once more to proceed")) : row.entry ? row.entry.detail : ""
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
                            if (root.pointerMoved(mapToItem(null, mouse.x, mouse.y)) && root.rowInView(row))
                                root.selected = row.index;
                        }
                        onClicked: root.execute(row.index)
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                opacity: list.count === 0 ? 1 : 0
                text: Tr.t("Nothing found")
                color: Theme.muted

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }
            }

        }

        // Search and the red button
        Item {
            id: bottomRow

            x: root.padding
            y: viewport.y + viewport.height + 10
            width: parent.width - root.padding * 2
            height: 46

            Rectangle {
                anchors.left: parent.left
                anchors.right: powerButton.left
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
                    opacity: root.commandMode || root.webMode ? 0 : 1
                    rotation: root.commandMode || root.webMode ? 90 : 0
                    scale: root.commandMode || root.webMode ? 0.6 : 1

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
                    name: "globe"
                    size: 17
                    color: Theme.accent
                    opacity: root.webMode ? 1 : 0
                    rotation: root.webMode ? 0 : -90
                    scale: root.webMode ? 1 : 0.6

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

            Rectangle {
                id: powerButton

                readonly property real pop: root.progress(0.1)

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 42
                radius: powerArea.containsMouse ? 14 : 21
                color: powerArea.containsMouse ? Qt.lighter(Session.red, 1.14) : Session.red
                opacity: pop
                scale: (0.6 + 0.4 * pop) * (powerArea.pressed ? 0.88 : powerArea.containsMouse ? 1.06 : 1)

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

                Icon {
                    anchors.centerIn: parent
                    name: "power"
                    size: 18
                    color: "white"
                }
                MouseArea {
                    id: powerArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.popup = "power"
                }
            }

            // The button has no text: its name shows above it.
            Rectangle {
                id: tipBox

                readonly property bool showing: powerArea.containsMouse

                anchors.right: parent.right
                y: showing ? -34 : -28
                width: tip.implicitWidth + 20
                height: 28
                radius: 10
                color: Theme.pill
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

                Label {
                    id: tip

                    anchors.centerIn: parent
                    text: Tr.t("Power menu")
                    color: Theme.text
                    size: 12
                }
            }
        }
    }
}
