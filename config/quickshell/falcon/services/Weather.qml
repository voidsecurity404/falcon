pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open-Meteo: kalit talab qilmaydi. Internet bo'lmasa dashboard'da ko'rsatilmaydi.
Singleton {
    id: root

    property string summary: ""
    readonly property bool enabled: Settings.get("weather.enabled", true)
    readonly property bool hasData: enabled && summary !== ""
    // When the last answer came. A failed request keeps it for a while: a short drop of the
    // network used to empty the weather everywhere until the next try.
    property real fetchedAt: 0
    readonly property int keepMs: 3 * 3600000
    property int temperature: 0
    property int feels: 0
    property int humidity: 0
    property int wind: 0
    property int code: 0
    property bool isDay: true
    // Next 24 hours: { time (ms), temp, code }.
    property var hourly: []
    // Today and the next days: { date (ms), code, max, min }.
    property var daily: []
    property real sunrise: 0
    property real sunset: 0

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

    // One of: clear, partly, cloudy, fog, rain, snow, storm.
    function kind(code) {
        if (code === 0)
            return "clear";
        if (code <= 2)
            return "partly";
        if (code === 3)
            return "cloudy";
        if (code <= 48)
            return "fog";
        if (code <= 67 || (code >= 80 && code <= 82))
            return "rain";
        if (code <= 77 || code === 85 || code === 86)
            return "snow";
        return "storm";
    }

    function icon(code, day) {
        const k = kind(code);
        if (k === "clear")
            return day === false ? "moon" : "sun";
        return ({
                partly: "cloudSun",
                cloudy: "cloud",
                fog: "fog",
                rain: "rain",
                snow: "snow",
                storm: "storm"
            })[k];
    }

    function read(answer) {
        const c = answer.current;
        temperature = Math.round(c.temperature_2m);
        feels = Math.round(c.apparent_temperature);
        humidity = Math.round(c.relative_humidity_2m);
        wind = Math.round(c.wind_speed_10m);
        code = c.weather_code;
        isDay = c.is_day === 1;
        summary = temperature + "° " + describe(code);
        fetchedAt = Date.now();

        const h = answer.hourly;
        const hours = [];
        const hourAgo = Date.now() - 3600000;
        for (let i = 0; i < h.time.length && hours.length < 24; i++) {
            const time = new Date(h.time[i]).getTime();
            if (time >= hourAgo)
                hours.push({
                    time: time,
                    temp: Math.round(h.temperature_2m[i]),
                    code: h.weather_code[i],
                    rain: h.precipitation_probability ? (h.precipitation_probability[i] || 0) : 0
                });
        }
        hourly = hours;

        const d = answer.daily;
        daily = d.time.map((date, i) => ({
                    date: new Date(date + "T12:00").getTime(),
                    code: d.weather_code[i],
                    max: Math.round(d.temperature_2m_max[i]),
                    min: Math.round(d.temperature_2m_min[i]),
                    rain: d.precipitation_probability_max ? (d.precipitation_probability_max[i] || 0) : 0
                }));
        sunrise = new Date(d.sunrise[0]).getTime();
        sunset = new Date(d.sunset[0]).getTime();
    }

    Process {
        id: fetch

        command: ["curl", "-fsS", "--max-time", "8", "https://api.open-meteo.com/v1/forecast?latitude=" + Settings.weatherLat + "&longitude=" + Settings.weatherLon + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day&hourly=temperature_2m,weather_code,precipitation_probability&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max&forecast_days=6&timezone=auto&temperature_unit=" + Settings.get("weather.unit", "celsius")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.read(JSON.parse(text));
                } catch (e) {
                    if (Date.now() - root.fetchedAt > root.keepMs)
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
        onTriggered: if (root.enabled) fetch.running = true
    }

    // A new place or unit asks again at once instead of waiting for the half hour.
    readonly property string query: Settings.weatherLat + "," + Settings.weatherLon + "," + Settings.get("weather.unit", "celsius")
    onQueryChanged: placeChanged.restart()

    Timer {
        id: placeChanged

        interval: 600
        onTriggered: if (root.enabled) fetch.running = true
    }

    Timer {
        interval: 1800000
        repeat: true
        running: root.enabled
        triggeredOnStart: true
        onTriggered: fetch.running = true
    }
}
