pragma Singleton

import QtQuick
import Quickshell

// Prayer times for today at the weather's place, computed here (no network) with the PrayTimes
// method: Fajr and Isha by the sun's depth below the horizon, Asr by the shadow (2 for Hanafi).
// The defaults follow the Muslim Board of Uzbekistan: 15° and 15°, Hanafi Asr.
Singleton {
    id: root

    readonly property bool enabled: Settings.get("widgets.prayer.enabled", true)
    readonly property real fajrAngle: Number(Settings.get("widgets.prayer.fajr", 15)) || 15
    readonly property real ishaAngle: Number(Settings.get("widgets.prayer.isha", 15)) || 15
    readonly property bool hanafi: Settings.get("widgets.prayer.asr", "hanafi") === "hanafi"
    readonly property real lat: Settings.weatherLat
    readonly property real lon: Settings.weatherLon

    readonly property var names: ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
    // Today's times as Date objects, in the order of names.
    property var times: []
    property date now: new Date()
    // The next one still to come: { name, time }; after Isha, tomorrow's Fajr.
    readonly property var next: {
        const t = now.getTime();
        for (let i = 0; i < times.length; i++) {
            if (times[i].getTime() > t)
                return { name: names[i], time: times[i] };
        }
        if (times.length === 0)
            return null;
        return { name: names[0], time: new Date(times[0].getTime() + 86400000) };
    }

    function rad(d) {
        return d * Math.PI / 180;
    }
    function deg(r) {
        return r * 180 / Math.PI;
    }
    function fix(a, b) {
        a = a - b * Math.floor(a / b);
        return a < 0 ? a + b : a;
    }

    function sun(jd) {
        const D = jd - 2451545.0;
        const g = fix(357.529 + 0.98560028 * D, 360);
        const q = fix(280.459 + 0.98564736 * D, 360);
        const L = fix(q + 1.915 * Math.sin(rad(g)) + 0.020 * Math.sin(rad(2 * g)), 360);
        const e = 23.439 - 0.00000036 * D;
        const RA = fix(deg(Math.atan2(Math.cos(rad(e)) * Math.sin(rad(L)), Math.cos(rad(L)))) / 15, 24);
        return {
            decl: deg(Math.asin(Math.sin(rad(e)) * Math.sin(rad(L)))),
            eqt: q / 15 - RA
        };
    }

    function compute() {
        const d = new Date();
        const y = d.getFullYear(), m = d.getMonth() + 1, day = d.getDate();
        let Y = y, M = m;
        if (M <= 2) {
            Y -= 1;
            M += 12;
        }
        const A = Math.floor(Y / 100);
        const B = 2 - A + Math.floor(A / 4);
        const jdate = Math.floor(365.25 * (Y + 4716)) + Math.floor(30.6001 * (M + 1)) + day + B - 1524.5 - lon / (15 * 24);
        const zone = -d.getTimezoneOffset() / 60;

        function midDay(t) {
            return fix(12 - sun(jdate + t).eqt, 24);
        }
        function angleTime(angle, t, before) {
            const s = sun(jdate + t);
            const noon = midDay(t);
            const c = (-Math.sin(rad(angle)) - Math.sin(rad(s.decl)) * Math.sin(rad(lat))) / (Math.cos(rad(s.decl)) * Math.cos(rad(lat)));
            const T = deg(Math.acos(Math.max(-1, Math.min(1, c)))) / 15;
            return noon + (before ? -T : T);
        }
        function asr(t) {
            const s = sun(jdate + t);
            const a = -deg(Math.atan(1 / ((hanafi ? 2 : 1) + Math.tan(rad(Math.abs(lat - s.decl))))));
            return angleTime(a, t, false);
        }
        // A first guess of each hour as a share of the day, then the real hour.
        const hours = [
            angleTime(fajrAngle, 5 / 24, true),
            angleTime(0.833, 6 / 24, true),
            midDay(12 / 24),
            asr(13 / 24),
            angleTime(0.833, 18 / 24, false),
            angleTime(ishaAngle, 18 / 24, false)
        ];
        // Dhuhr a few minutes after noon, Maghrib a few after sunset, as the calendars print them.
        hours[2] += 3 / 60;
        hours[4] += 3 / 60;
        times = hours.map(h => {
            const local = fix(h + zone - lon / 15, 24);
            const mins = Math.round(local * 60);
            return new Date(y, m - 1, day, Math.floor(mins / 60), mins % 60);
        });
    }

    onLatChanged: compute()
    onLonChanged: compute()
    onFajrAngleChanged: compute()
    onIshaAngleChanged: compute()
    onHanafiChanged: compute()
    Component.onCompleted: compute()

    Timer {
        interval: 30000
        running: root.enabled
        repeat: true
        onTriggered: {
            const d = new Date();
            if (d.getDate() !== root.now.getDate())
                root.compute();
            root.now = d;
        }
    }
}
