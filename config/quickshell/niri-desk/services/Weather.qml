pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open-Meteo: kalit talab qilmaydi. Internet bo'lmasa dashboard'da ko'rsatilmaydi.
Singleton {
    id: root

    property string summary: ""

    function describe(code) {
        if (code === 0)
            return Tr.t("clear");
        if (code <= 2)
            return Tr.t("partly cloudy");
        if (code === 3)
            return Tr.t("cloudy");
        if (code <= 48)
            return Tr.t("fog");
        if (code <= 67 || (code >= 80 && code <= 82))
            return Tr.t("rain");
        if (code <= 77 || code === 85 || code === 86)
            return Tr.t("snow");
        return Tr.t("thunderstorm");
    }

    Process {
        id: fetch

        command: ["curl", "-fsS", "--max-time", "8", "https://api.open-meteo.com/v1/forecast?latitude=" + Settings.weatherLat + "&longitude=" + Settings.weatherLon + "&current=temperature_2m,weather_code&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).current;
                    root.summary = Math.round(c.temperature_2m) + "° " + root.describe(c.weather_code);
                } catch (e) {
                    root.summary = "";
                    retry.restart();
                }
            }
        }
    }

    // Sessiya boshida tarmoq hali tayyor bo'lmasligi mumkin.
    Timer {
        id: retry

        interval: 30000
        onTriggered: fetch.running = true
    }

    Timer {
        interval: 1800000
        repeat: true
        running: Settings.get("weather.enabled", true)
        triggeredOnStart: true
        onTriggered: fetch.running = true
    }
}
