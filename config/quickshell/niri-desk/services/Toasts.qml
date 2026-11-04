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

    // Oxirgi xabarlar: {title, sub, app, time}
    property var history: []
    property int unread: 0

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
                title: title,
                sub: sub,
                app: app,
                time: Qt.formatTime(new Date(), "hh:mm")
            }
        ].concat(history).slice(0, Settings.get("notifications.history", 30));
        unread += 1;
    }

    function clearHistory() {
        history = [];
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
        imageSupported: false
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
                value: -1,
                key: "",
                notification: n,
                sticky: critical,
                run: null
            });
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

    Connections {
        target: Ui
        function onPopupChanged() {
            if (Ui.popup === "control")
                root.unread = 0;
        }
    }
}
