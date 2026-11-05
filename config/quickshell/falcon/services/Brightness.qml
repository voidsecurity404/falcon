pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// brightnessctl orqali. Yorqinlik boshqaruvi yo'q qurilmada (masalan VM) slider ko'rinmaydi.
Singleton {
    id: root

    property bool available: false
    property int percent: 100
    // Slider bilan bir xil chegara: qadam ham ekranni qoraytirmasin.
    property int minimumRaw: 1
    property bool announceNext: false

    function refresh() {
        reader.running = true;
    }

    function step(amount) {
        announceNext = true;
        setter.command = ["brightnessctl", "--class=backlight", "--min-value=" + minimumRaw, "set", amount];
        setter.running = true;
    }

    function setPercent(value) {
        percent = Math.max(5, Math.min(100, Math.round(value)));
        setter.command = ["brightnessctl", "--class=backlight", "set", percent + "%"];
        setter.running = true;
    }

    Process {
        id: reader

        command: ["brightnessctl", "--class=backlight", "-m", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                root.available = parts.length >= 5;
                if (root.available) {
                    root.percent = parseInt(parts[3]);
                    root.minimumRaw = Math.max(1, Math.ceil(parseInt(parts[4]) * 0.05));
                }
                if (root.announceNext) {
                    root.announceNext = false;
                    Toasts.level("brightness", Tr.t("Brightness") + " " + root.percent + "%", root.percent / 100, "sun");
                }
            }
        }
    }

    Process {
        id: setter

        onExited: root.refresh()
    }

    Component.onCompleted: refresh()
}
