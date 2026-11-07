pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Orolda chiqadigan xabarlar navbati va xabarlar tarixi.
Singleton {
    id: root

    // {title, sub, icon, value, key, notification, sticky, run}
    property var current: null
    property var queue: []
    property bool doNotDisturb: false
    onDoNotDisturbChanged: Saved.set("doNotDisturb", doNotDisturb)
    Component.onCompleted: {
        doNotDisturb = Saved.get("doNotDisturb", false);
        const saved = Saved.get("notifications", null);
        if (saved && Array.isArray(saved.history)) {
            history = saved.history;
            unread = saved.unread || 0;
            nextHistoryId = history.reduce((top, h) => Math.max(top, h.id), 0) + 1;
        }
        historyLoaded = true;
    }
    readonly property int maxWaiting: 3

    // Oxirgi xabarlar: {id, title, sub, app, time}
    property var history: []
    property int nextHistoryId: 1
    property int unread: 0
    // The first value of history also fires its handler, and it must not overwrite the saved list.
    property bool historyLoaded: false
    onHistoryChanged: saveHistory()
    onUnreadChanged: saveHistory()
    // The history is on the Today tab of the dashboard.
    readonly property bool historySeen: Ui.popup === "dashboard" && Ui.dashTab === 0
    onHistorySeenChanged: {
        if (historySeen)
            unread = 0;
    }

    function start() {
    }

    // isPrivate keeps the text off the disk, for what was copied from the clipboard.
    function show(title, sub, icon, run, isPrivate) {
        const text = String(sub || "").replace(/\x1b\[[0-9;]*m/g, "").replace(/\s+/g, " ").trim();
        enqueue({
            historyId: remember(title, isPrivate ? "" : text, Tr.t("System"), true),
            title: title,
            sub: text,
            icon: icon || "check",
            value: -1,
            key: "",
            notification: null,
            sticky: false,
            run: run || null
        });
    }

    // Tez takrorlanadigan holat (ovoz, yorqinlik): faqat eng oxirgi qiymat muhim.
    // Boshqa daraja xabarini darhol almashtiradi. Oddiy xabar ochiq bo'lsa, navbatda har turdan bittasi turadi.
    // Focus mode hides the island. This one message still shows there, it says how to get out.
    function zenHint() {
        enqueue({
            title: Tr.t("Focus mode"),
            sub: Tr.t("{key} or the control center turns it off").replace("{key}", Settings.get("binds.zen", "Mod+F")),
            icon: "focus",
            value: -1,
            key: "",
            notification: null,
            sticky: false,
            run: null,
            inZen: true
        });
    }

    // Battery warnings show in focus mode too. An urgent one stays until it is clicked or the charger is plugged in.
    function batteryAlert(title, sub, urgent) {
        enqueue({
            historyId: remember(title, sub, Tr.t("System"), true),
            title: title,
            sub: sub,
            icon: "alert",
            value: -1,
            key: "",
            notification: null,
            sticky: urgent,
            run: null,
            inZen: true,
            battery: true
        });
    }

    // Something the user asked to be told about. It shows in focus mode, stays a minute, and is
    // kept in the history for whoever was away from the screen.
    function alarm(title, sub, icon) {
        enqueue({
            historyId: remember(title, sub, Tr.t("Timer")),
            title: title,
            sub: sub,
            icon: icon,
            value: -1,
            key: "",
            notification: null,
            sticky: false,
            run: null,
            inZen: true,
            hold: 60000
        });
    }

    function clearBatteryAlerts() {
        queue = queue.filter(q => !q.battery);
        if (current && current.battery)
            advance();
    }

    function level(key, title, value, icon) {
        const item = {
            title: title,
            sub: "",
            icon: icon,
            value: value,
            key: key,
            notification: null,
            sticky: false,
            run: null
        };
        if (!current || current.key !== "") {
            display(item);
            return;
        }
        const levels = queue.filter(q => q.key !== "" && q.key !== key).concat([item]);
        queue = levels.concat(queue.filter(q => q.key === ""));
    }

    function enqueue(item) {
        if (current) {
            queue = trimmed(queue.concat([item]));
            return;
        }
        display(item);
    }

    // A burst of notifications must not fill the island for minutes. The oldest waiting ones are
    // dropped from the screen and stay in the history. Urgent ones and the shell's own messages stay.
    function trimmed(items) {
        const waiting = items.filter(q => q.notification && !q.sticky);
        const extra = waiting.slice(0, Math.max(0, waiting.length - maxWaiting));
        for (const item of extra)
            item.notification.dismiss();
        return items.filter(q => !extra.includes(q));
    }

    function display(item) {
        current = item;
        if (item.sticky) {
            timer.stop();
        } else {
            timer.interval = item.hold ? item.hold : item.key !== "" ? 1600 : Settings.get("notifications.seconds", 3.6) * 1000;
            timer.restart();
        }
    }

    function advance() {
        if (current && current.notification)
            current.notification.dismiss();
        current = null;
        if (queue.length > 0) {
            display(queue[0]);
            queue = queue.slice(1);
        }
    }

    function activate() {
        const item = current;
        if (item && item.notification) {
            const action = item.notification.actions.find(a => a.identifier === "default") || item.notification.actions[0];
            if (action)
                action.invoke();
        }
        if (item && item.run)
            item.run();
        advance();
    }

    function saveHistory() {
        if (historyLoaded)
            Saved.set("notifications", {
                history: history,
                unread: unread
            });
    }

    // A saved notification can be from another day, then the time alone would mislead.
    function timeLabel(entry) {
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        if (!entry.date || entry.date === today)
            return entry.time;
        return entry.date.slice(8, 10) + "." + entry.date.slice(5, 7) + " " + entry.time;
    }

    // Every message is kept until it is cleared by hand. The shell's own messages are about what
    // the user just did, so they do not raise the unread dot.
    function remember(title, sub, app, seen) {
        const id = nextHistoryId++;
        history = [
            {
                id: id,
                title: title,
                sub: sub,
                app: app,
                time: Qt.formatTime(new Date(), "hh:mm"),
                date: Qt.formatDate(new Date(), "yyyy-MM-dd")
            }
        ].concat(history);
        if (!historySeen && !seen)
            unread += 1;
        return id;
    }

    function forget(ids) {
        history = history.filter(h => !ids.includes(h.id));
        if (history.length === 0)
            unread = 0;
        // What was cleared must not appear on the island once the dashboard closes.
        const cleared = item => item && ids.includes(item.historyId);
        for (const item of queue.filter(cleared)) {
            if (item.notification)
                item.notification.dismiss();
        }
        queue = queue.filter(item => !cleared(item));
        if (cleared(current))
            advance();
    }

    function bodyOf(n) {
        return n.body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ");
    }

    // An app can replace a notification still on the screen, and the server then reports no new
    // one. The new text is a message of its own in the history.
    function replaced(n) {
        const shown = current && current.notification === n ? current : queue.find(q => q.notification === n);
        if (!shown)
            return;
        const title = n.summary || n.appName;
        const body = bodyOf(n);
        if (shown.title === title && shown.sub === body)
            return;
        const next = Object.assign({}, shown, {
            historyId: remember(title, body, n.appName),
            title: title,
            sub: body,
            image: n.image || ""
        });
        if (shown === current) {
            current = next;
            if (!next.sticky)
                timer.restart();
        } else {
            queue = queue.map(q => q === shown ? next : q);
        }
    }

    Timer {
        id: timer

        // Dashboard ochiq turganda xabar vaqti o'tmaydi, u yopilgach ko'rinadi.
        running: false
        onTriggered: {
            if (Ui.popup === "dashboard")
                restart();
            else
                root.advance();
        }
    }

    NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: n => {
            // niri skrinshot haqida o'zi ham xabar yuboradi: o'rniga o'zbekcha xabarimiz chiqadi.
            if (n.summary === "Screenshot captured") {
                n.dismiss();
                return;
            }
            const body = root.bodyOf(n);
            const historyId = root.remember(n.summary || n.appName, body, n.appName);
            const critical = n.urgency === NotificationUrgency.Critical;
            if (root.doNotDisturb && !critical) {
                n.dismiss();
                return;
            }
            n.tracked = true;
            // A replacement changes both fields at once and is one message.
            const onReplaced = () => root.replaced(n);
            n.summaryChanged.connect(() => Qt.callLater(onReplaced));
            n.bodyChanged.connect(() => Qt.callLater(onReplaced));
            root.enqueue({
                historyId: historyId,
                title: n.summary || n.appName,
                sub: body,
                icon: critical ? "alert" : "bell",
                image: n.image || "",
                value: -1,
                key: "",
                notification: n,
                sticky: critical,
                run: null
            });
        }
    }

    Connections {
        target: Ui
        function onZenChanged() {
            if (Ui.zen)
                root.zenHint();
        }
    }

    Connections {
        target: Niri
        function onScreenshotTaken(path) {
            if (path === "") {
                root.show(Tr.t("Screenshot taken"), Tr.t("Copied to the clipboard"), "check");
                return;
            }
            root.show(Tr.t("Screenshot taken"), Tr.t("Click to edit"), "check", () => Quickshell.execDetached(["satty", "--filename", path, "--output-filename", path, "--early-exit", "--copy-command", "wl-copy"]));
        }
        function onConfigFailed() {
            root.show(Tr.t("Error in the niri config"), Tr.t("The previous settings stay active"), "alert");
        }
    }
}
