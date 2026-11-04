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

    // Oxirgi xabarlar: {id, title, sub, app, time}
    property var history: []
    property int nextHistoryId: 1
    property int unread: 0
    // The history is on the Today tab of the dashboard.
    readonly property bool historySeen: Ui.popup === "dashboard" && Ui.dashTab === 0
    onHistorySeenChanged: {
        if (historySeen)
            unread = 0;
    }

    function start() {
    }

    function show(title, sub, icon, run) {
        enqueue({
            title: title,
            sub: String(sub || "").replace(/\x1b\[[0-9;]*m/g, "").replace(/\s+/g, " ").trim(),
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
            queue = queue.concat([item]);
            return;
        }
        display(item);
    }

    function display(item) {
        current = item;
        if (item.sticky) {
            timer.stop();
        } else {
            timer.interval = item.key !== "" ? 1600 : Settings.get("notifications.seconds", 3.6) * 1000;
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

    function remember(title, sub, app) {
        history = [
            {
                id: nextHistoryId++,
                title: title,
                sub: sub,
                app: app,
                time: Qt.formatTime(new Date(), "hh:mm")
            }
        ].concat(history).slice(0, Settings.get("notifications.history", 30));
        if (!historySeen)
            unread += 1;
    }

    function forget(ids) {
        history = history.filter(h => !ids.includes(h.id));
        if (history.length === 0)
            unread = 0;
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
            const body = n.body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ");
            root.remember(n.summary || n.appName, body, n.appName);
            const critical = n.urgency === NotificationUrgency.Critical;
            if (root.doNotDisturb && !critical) {
                n.dismiss();
                return;
            }
            n.tracked = true;
            root.enqueue({
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
