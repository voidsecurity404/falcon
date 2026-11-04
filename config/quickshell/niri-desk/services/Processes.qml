pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Busiest processes and the GPU clock. Runs only while the System tab of the dashboard is open.
Singleton {
    id: root

    readonly property bool active: Ui.popup === "dashboard" && Ui.dashTab === 2
    readonly property string user: Quickshell.env("USER")

    // {pid, user, cpu, mem, name}
    property var rows: []
    property int gpuMhz: 0
    property string gpuPath: ""

    function end(pid) {
        Quickshell.execDetached(["kill", String(pid)]);
    }

    function read(content) {
        // top prints two reports with -n 2. Only the second measures the current load.
        const report = content.slice(content.lastIndexOf("PID USER"));
        rows = report.split("\n").slice(1).map(line => {
            const f = line.trim().split(/\s+/);
            return f.length < 12 ? null : {
                pid: Number(f[0]),
                user: f[1],
                cpu: Number(f[8]),
                mem: Number(f[9]),
                name: f.slice(11).join(" ")
            };
        }).filter(r => r && r.name !== "top").slice(0, 11);
    }

    Process {
        id: top

        command: ["top", "-b", "-n", "2", "-d", "0.7", "-o", "%CPU", "-w", "160"]
        environment: ({
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            onStreamFinished: root.read(text)
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/drm/card*/gt_cur_freq_mhz 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: root.gpuPath = text.trim()
        }
    }

    FileView {
        id: gpu

        path: root.gpuPath
        printErrors: false
        onLoaded: root.gpuMhz = Number(text())
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            if (!top.running)
                top.running = true;
            if (root.gpuPath !== "")
                gpu.reload();
        }
    }
}
