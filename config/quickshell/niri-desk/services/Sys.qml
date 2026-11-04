pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// CPU, xotira, disk va batareya. Faqat kerak bo'lganda (active) o'qiladi.
Singleton {
    id: root

    property bool active: Ui.popup === "dashboard" || Widgets.systemLive

    property int cpu: 0
    property int ram: 0
    property real ramGb: 0
    property real ramTotalGb: 0
    property real netDown: 0
    property real netUp: 0
    property int disk: 0
    property int temperature: 0
    // CPU yuklamasi: oxirgi ikki daqiqa.
    property var history: []
    property string hwmon: ""

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery && battery.isLaptopBattery && battery.isPresent
    readonly property int batteryPercent: hasBattery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

    property var previousCpu: null
    property var previousNet: null
    property int warnedAt: 101

    // Batareya kamayganda har chegarada bir marta ogohlantiradi.
    onBatteryPercentChanged: {
        if (!hasBattery || charging) {
            warnedAt = 101;
            return;
        }
        for (const limit of [5, 10, 20]) {
            if (batteryPercent <= limit && warnedAt > limit) {
                warnedAt = limit;
                Toasts.show(Tr.t("Battery") + " " + batteryPercent + "%", limit === 5 ? Tr.t("Shutting down soon, plug in the charger") : Tr.t("Time to plug in"), "alert");
                break;
            }
        }
    }

    function readCpu(content) {
        const fields = content.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = fields[3] + (fields[4] || 0);
        const total = fields.reduce((a, b) => a + b, 0);
        if (previousCpu && total > previousCpu.total)
        {
            cpu = Math.round(100 * (1 - (idle - previousCpu.idle) / (total - previousCpu.total)));
            history = history.concat([cpu]).slice(-60);
        }
        previousCpu = {
            idle: idle,
            total: total
        };
    }

    function readMemory(content) {
        const value = key => {
            const m = content.match(new RegExp("^" + key + ":\\s+(\\d+)", "m"));
            return m ? Number(m[1]) : 0;
        };
        const total = value("MemTotal");
        const used = total - value("MemAvailable");
        ram = total > 0 ? Math.round(100 * used / total) : 0;
        ramGb = used / 1048576;
        ramTotalGb = total / 1048576;
    }

    // Bytes per second over all interfaces except loopback.
    function readNetwork(content) {
        let down = 0;
        let up = 0;
        for (const line of content.split("\n").slice(2)) {
            const m = line.trim().match(/^([^:]+):\s*(.*)$/);
            if (!m || m[1] === "lo")
                continue;
            const f = m[2].split(/\s+/).map(Number);
            down += f[0];
            up += f[8];
        }
        const now = Date.now();
        if (previousNet) {
            const seconds = (now - previousNet.at) / 1000;
            netDown = Math.max(0, down - previousNet.down) / seconds;
            netUp = Math.max(0, up - previousNet.up) / seconds;
        }
        previousNet = {
            at: now,
            down: down,
            up: up
        };
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: root.readCpu(text())
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: root.readMemory(text())
    }

    FileView {
        id: netdev

        path: "/proc/net/dev"
        onLoaded: root.readNetwork(text())
    }

    Process {
        running: true
        command: ["sh", "-c", 'for d in /sys/class/hwmon/*; do [ "$(cat "$d/name")" = coretemp ] && echo "$d" && exit; done']
        stdout: StdioCollector {
            onStreamFinished: root.hwmon = text.trim()
        }
    }

    FileView {
        id: thermal

        path: root.hwmon !== "" ? root.hwmon + "/temp1_input" : ""
        printErrors: false
        onLoaded: root.temperature = Math.round(Number(text()) / 1000)
    }

    Process {
        id: df

        command: ["df", "--output=pcent", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/(\d+)%/);
                if (m)
                    root.disk = Number(m[1]);
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            netdev.reload();
            if (root.hwmon !== "")
                thermal.reload();
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: df.running = true
    }
}
