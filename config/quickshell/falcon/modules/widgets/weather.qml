import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import qs.components
import qs.services

// The weather now, the next day hour by hour with the chance of rain, and the coming days.
// Forms: large, wide, compact.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "large"
    readonly property bool large: form === "large"
    readonly property bool compact: form === "compact"
    readonly property string kind: Weather.kind(Weather.code)
    readonly property bool day: Weather.isDay
    readonly property var today: Weather.daily.length ? Weather.daily[0] : null
    readonly property color warm: Theme.hueShift(Theme.accent, 0.92)
    readonly property color rainColor: Qt.hsla(0.58, 0.75, 0.68, 1)
    // The sky behind the numbers, by the weather and the time of day.
    readonly property var sky: {
        if (!day)
            return ["#1b2450", "#0b1024"];
        return ({
                clear: ["#3f8fe0", "#1c4f9a"],
                partly: ["#4f8fc8", "#2a4f7d"],
                cloudy: ["#5c6f86", "#2f3b4b"],
                fog: ["#7d8794", "#434b57"],
                rain: ["#3f5878", "#1f2d42"],
                snow: ["#8fa8c8", "#4d6584"],
                storm: ["#3b3f5c", "#171a2b"]
            })[kind] || ["#3f8fe0", "#1c4f9a"];
    }
    readonly property var hours: large ? Weather.hourly.filter((h, i) => i % 2 === 0).slice(0, 12) : Weather.hourly.filter((h, i) => i % 3 === 0).slice(0, 8)

    // Ticks each minute, so the rain sentence counts down between requests.
    property real nowMs: Date.now()
    readonly property string rainSoon: Weather.nowcast(nowMs)
    readonly property color aqiColor: [Theme.good, Theme.warn, Theme.error, Theme.error][Math.max(0, Weather.aqiLevel(Weather.aqi))]
    readonly property color uvColor: Weather.uv < 3 ? Theme.good : Weather.uv < 6 ? Theme.warn : Theme.error
    // Where the sun is between sunrise and sunset, 0 to 1; below 0 or above 1 at night.
    readonly property real sunShare: Weather.sunset > Weather.sunrise ? (nowMs - Weather.sunrise) / (Weather.sunset - Weather.sunrise) : -1

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    function hourLabel(t) {
        const d = new Date(t);
        return (d.getHours() < 10 ? "0" : "") + d.getHours();
    }
    function clock(t) {
        return t > 0 ? Qt.formatTime(new Date(t), "hh:mm") : "--:--";
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            opacity: 0.42
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: root.sky[0]
                }
                GradientStop {
                    position: 1
                    color: root.sky[1]
                }
            }
        }
        // A large, faint copy of the icon as the backdrop's mark.
        Icon {
            visible: !root.form || root.form !== "wide"
            x: parent.width - width * 0.72
            y: -height * 0.22
            name: Weather.icon(Weather.code, root.day)
            size: root.compact ? 150 : 230
            color: Qt.alpha(Theme.text, 0.07)
        }
    }

    Label {
        anchors.centerIn: parent
        visible: !Weather.hasData
        text: Tr.t("Waiting for the weather")
        color: Theme.muted
        size: 14
    }

    // ---------------------------------------------------------------- now
    Item {
        id: now

        visible: Weather.hasData
        x: 22
        y: root.compact ? 12 : 20
        width: root.large ? root.width - 44 : root.compact ? root.width - 44 : 190
        height: root.compact ? 56 : 150

        WidgetCaption {
            visible: !root.compact
            icon: "globe"
            text: Tr.t("Now")
        }
        // Sunrise and sunset, which the large form draws as the sun's arc.
        Label {
            visible: !root.large && !root.compact && Weather.sunrise > 0
            anchors.right: parent.right
            y: 2
            text: "☀ " + root.clock(Weather.sunrise) + " – " + root.clock(Weather.sunset)
            size: 10
            color: Theme.muted
        }
        Row {
            id: tempRow

            y: root.compact ? 0 : 32
            spacing: 12

            Item {
                visible: root.compact || root.large
                anchors.verticalCenter: parent.verticalCenter
                width: root.compact ? 44 : 64
                height: width

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(root.kind === "clear" && root.day ? root.warm : Theme.accent, 0.2)
                }
                Icon {
                    anchors.centerIn: parent
                    name: Weather.icon(Weather.code, root.day)
                    size: parent.width * 0.55
                    color: root.kind === "clear" && root.day ? root.warm : Theme.text
                }
            }
            Text {
                text: Weather.temperature + "°"
                font.family: Theme.display
                font.pixelSize: root.compact ? 40 : 62
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Column {
                visible: root.large || root.compact
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Label {
                    text: Tr.capitalized(Weather.describe(Weather.code))
                    size: root.compact ? 13 : 17
                    font.weight: Font.DemiBold
                    font.capitalization: Font.Capitalize
                }
                Label {
                    text: Tr.t("Feels like") + " " + Weather.feels + "°"
                    size: root.compact ? 11 : 12
                    color: Theme.muted
                }
                Label {
                    visible: !!root.today
                    text: root.compact && root.rainSoon !== "" ? root.rainSoon : root.today ? "↑ " + root.today.max + "°   ↓ " + root.today.min + "°" + (root.compact && root.today.rain > 0 ? "   ☂ " + root.today.rain + "%" : "") : ""
                    color: root.compact && root.rainSoon !== "" ? root.rainColor : Theme.muted
                    size: root.compact ? 11 : 12
                }
            }
        }
        Label {
            visible: !root.large && !root.compact
            y: tempRow.y + tempRow.height - 4
            text: Tr.capitalized(Weather.describe(Weather.code)) + " · " + Tr.t("Feels like") + " " + Weather.feels + "°"
            width: parent.width
            size: 13
            font.weight: Font.Medium
        }
        // Humidity, wind, sunrise and sunset.
        Flow {
            visible: !root.compact && (root.large || root.rainSoon === "")
            y: root.large ? 112 : 124
            width: parent.width
            spacing: root.large ? 6 : 4

            Repeater {
                model: [
                    { icon: "color", text: Weather.humidity + "%", tint: Theme.accent },
                    { icon: "wave", text: Weather.wind + " " + Tr.t("km/h"), tint: Theme.accent },
                    { icon: "sun", text: Weather.uv < 0 ? "" : Tr.t("UV") + " " + Math.round(Weather.uv), tint: root.uvColor },
                    { icon: "leaf", text: Weather.aqi < 0 ? "" : Tr.t("Air") + " " + Weather.aqi, tint: root.aqiColor }
                ].filter(c => c.text !== "")

                Rectangle {
                    required property var modelData

                    width: statRow.implicitWidth + (root.large ? 18 : 14)
                    height: root.large ? 28 : 24
                    radius: height / 2
                    color: Qt.alpha(Theme.text, 0.08)

                    Row {
                        id: statRow

                        anchors.centerIn: parent
                        spacing: 5

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.icon
                            size: 12
                            color: modelData.tint
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            size: 12
                        }
                    }
                }
            }
        }

        // Rain or snow coming within two hours, in place of the chips in the wide form.
        Row {
            visible: !root.compact && !root.large && root.rainSoon !== ""
            y: 124
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "rain"
                size: 14
                color: root.rainColor
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 170
                text: root.rainSoon
                size: 12
                font.weight: Font.Medium
                color: root.rainColor
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
    }

    // ---------------------------------------------------------------- sun and rain (large)
    Item {
        id: sunBand

        visible: root.large && Weather.hasData
        x: 22
        y: 300
        width: root.width - 44
        height: 56

        // The sun's way across the sky today, the dot where it is now.
        Item {
            id: arc

            width: 150
            height: 40

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Qt.alpha(Theme.text, 0.25)
                    strokeWidth: 1.5
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 3]
                    fillColor: "transparent"
                    startX: 6
                    startY: arc.height - 2

                    PathArc {
                        x: arc.width - 6
                        y: arc.height - 2
                        radiusX: (arc.width - 12) / 2
                        radiusY: arc.height - 6
                    }
                }
                ShapePath {
                    strokeColor: Qt.alpha(Theme.text, 0.18)
                    strokeWidth: 1
                    fillColor: "transparent"
                    startX: 0
                    startY: arc.height - 2

                    PathLine {
                        x: arc.width
                        y: arc.height - 2
                    }
                }
            }
            Rectangle {
                readonly property real t: Math.max(0, Math.min(1, root.sunShare))
                readonly property bool up: root.sunShare >= 0 && root.sunShare <= 1
                readonly property real a: Math.PI * (1 - t)

                width: up ? 12 : 9
                height: width
                radius: width / 2
                x: arc.width / 2 + Math.cos(a) * (arc.width - 12) / 2 - width / 2
                y: arc.height - 2 - Math.sin(a) * (arc.height - 6) - height / 2
                color: up ? root.warm : Qt.alpha(Theme.text, 0.4)
                border.width: up ? 3 : 0
                border.color: Qt.alpha(root.warm, 0.35)
            }
        }
        Label {
            anchors.top: arc.bottom
            anchors.topMargin: 2
            x: 0
            text: "↑ " + root.clock(Weather.sunrise)
            size: 11
            color: Theme.muted
        }
        Label {
            anchors.top: arc.bottom
            anchors.topMargin: 2
            x: arc.width - implicitWidth
            text: "↓ " + root.clock(Weather.sunset)
            size: 11
            color: Theme.muted
        }
        Row {
            x: arc.width + 22
            width: parent.width - x
            anchors.verticalCenter: arc.verticalCenter
            anchors.verticalCenterOffset: 6
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.rainSoon !== "" ? "rain" : "sun"
                size: 16
                color: root.rainSoon !== "" ? root.rainColor : Qt.alpha(Theme.text, 0.6)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24
                text: root.rainSoon !== "" ? root.rainSoon : Tr.t("Dry for the next two hours")
                size: 12
                font.weight: Font.Medium
                color: root.rainSoon !== "" ? root.rainColor : Theme.muted
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
    }

    // ---------------------------------------------------------------- hour by hour
    Item {
        id: chart

        readonly property var temps: root.hours.map(h => h.temp)
        readonly property real hi: temps.length ? Math.max(...temps) : 1
        readonly property real lo: temps.length ? Math.min(...temps) : 0
        readonly property real step: root.hours.length > 1 ? width / root.hours.length : width
        readonly property real topPad: 22
        readonly property real band: height - 70

        visible: Weather.hasData && !root.compact && root.hours.length > 1
        x: root.large ? 14 : 224
        y: root.large ? 158 : 14
        width: root.width - x - 14
        height: root.large ? 132 : 122

        function px(i) {
            return step * (i + 0.5);
        }
        function py(t) {
            return topPad + (hi === lo ? band / 2 : (hi - t) / (hi - lo) * band);
        }

        Rectangle {
            visible: !root.large
            x: -12
            y: 4
            width: 1
            height: parent.height - 8
            color: Qt.alpha(Theme.text, 0.1)
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: chart.topPad
                    x2: 0
                    y2: chart.topPad + chart.band + 20
                    GradientStop {
                        position: 0
                        color: Qt.alpha(root.warm, 0.3)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(root.warm, 0)
                    }
                }

                PathPolyline {
                    path: {
                        const p = [Qt.point(chart.px(0), chart.topPad + chart.band + 20)];
                        root.hours.forEach((h, i) => p.push(Qt.point(chart.px(i), chart.py(h.temp))));
                        p.push(Qt.point(chart.px(root.hours.length - 1), chart.topPad + chart.band + 20));
                        return p;
                    }
                }
            }
            ShapePath {
                strokeColor: root.warm
                strokeWidth: 2.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.hours.map((h, i) => Qt.point(chart.px(i), chart.py(h.temp)))
                }
            }
        }
        Repeater {
            model: root.hours

            Item {
                id: hour

                required property var modelData
                required property int index

                x: chart.step * index
                width: chart.step
                height: chart.height

                Rectangle {
                    x: (parent.width - width) / 2
                    y: chart.py(hour.modelData.temp) - 4
                    width: 8
                    height: 8
                    radius: 4
                    color: hour.index === 0 ? root.warm : Theme.pill
                    border.width: 2
                    border.color: root.warm
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: chart.py(hour.modelData.temp) - 22
                    text: hour.modelData.temp + "°"
                    size: 11
                    font.weight: Font.DemiBold
                }
                // The chance of rain as a small bar.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: hourText.top
                    anchors.bottomMargin: 4
                    width: Math.min(14, parent.width - 8)
                    height: Math.max(2, 18 * hour.modelData.rain / 100)
                    radius: 3
                    color: Qt.alpha(root.rainColor, hour.modelData.rain > 0 ? 0.35 + hour.modelData.rain / 160 : 0.15)
                }
                Label {
                    id: hourText

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: root.hourLabel(hour.modelData.time)
                    size: 11
                    color: hour.index === 0 ? root.warm : Theme.muted
                    font.weight: hour.index === 0 ? Font.Bold : Font.Normal
                }
            }
        }
    }

    // ---------------------------------------------------------------- days
    Column {
        id: days

        readonly property var list: Weather.daily.slice(0, 5)
        readonly property real hi: list.length ? Math.max(...list.map(d => d.max)) : 1
        readonly property real lo: list.length ? Math.min(...list.map(d => d.min)) : 0

        visible: root.large && Weather.hasData
        x: 18
        y: 368
        width: root.width - 36
        spacing: 0

        Repeater {
            model: days.list

            Item {
                id: dayRow

                required property var modelData
                required property int index

                width: days.width
                height: 25

                Label {
                    width: 92
                    anchors.verticalCenter: parent.verticalCenter
                    text: dayRow.index === 0 ? Tr.t("Today") : Qt.locale().toString(new Date(dayRow.modelData.date), "dddd")
                    size: 13
                    font.weight: dayRow.index === 0 ? Font.DemiBold : Font.Normal
                    font.capitalization: Font.Capitalize
                }
                Icon {
                    x: 96
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon(dayRow.modelData.code, true)
                    size: 16
                }
                Label {
                    x: 120
                    width: 42
                    anchors.verticalCenter: parent.verticalCenter
                    text: dayRow.modelData.rain > 0 ? dayRow.modelData.rain + "%" : ""
                    size: 11
                    color: root.rainColor
                }
                Label {
                    x: 166
                    width: 34
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    text: dayRow.modelData.min + "°"
                    size: 13
                    color: Theme.muted
                }
                // The day's range on the scale of the whole week.
                Item {
                    x: 210
                    width: parent.width - x - 44
                    height: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: Qt.alpha(Theme.text, 0.1)
                    }
                    Rectangle {
                        readonly property real span: Math.max(1, days.hi - days.lo)

                        x: (dayRow.modelData.min - days.lo) / span * parent.width
                        width: Math.max(6, (dayRow.modelData.max - dayRow.modelData.min) / span * parent.width)
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: root.rainColor
                            }
                            GradientStop {
                                position: 1
                                color: root.warm
                            }
                        }
                    }
                }
                Label {
                    anchors.right: parent.right
                    width: 36
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    text: dayRow.modelData.max + "°"
                    size: 13
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // ---------------------------------------------------------------- small forms: the rest in brief
    // The coming days as a strip, under the hours in the wide form and at the bottom of the compact one.
    component DayStrip: Row {
        id: strip

        readonly property var list: Weather.daily.slice(0, 5)
        readonly property real cell: width / Math.max(1, list.length)

        Repeater {
            model: strip.list

            Column {
                id: dayCell

                required property var modelData
                required property int index

                width: strip.cell
                spacing: 1

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.locale().toString(new Date(dayCell.modelData.date), "ddd")
                        size: 10
                        color: dayCell.index === 0 ? root.warm : Theme.muted
                        font.weight: dayCell.index === 0 ? Font.DemiBold : Font.Normal
                        font.capitalization: Font.Capitalize
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Weather.icon(dayCell.modelData.code, true)
                        size: 12
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dayCell.modelData.max + "° <font color=\"" + Theme.muted + "\">" + dayCell.modelData.min + "°</font>"
                    textFormat: Text.StyledText
                    size: 11
                    font.weight: Font.DemiBold
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dayCell.modelData.rain > 0 ? "☂ " + dayCell.modelData.rain + "%" : " "
                    size: 9
                    color: root.rainColor
                }
            }
        }
    }

    DayStrip {
        visible: !root.large && !root.compact && Weather.hasData
        x: 222
        y: 146
        width: root.width - x - 12
    }

    // Compact: humidity, wind, UV, air and the sun on one line, then the hours and the days.
    Row {
        visible: root.compact && Weather.hasData
        x: 20
        y: 72
        spacing: 10

        Repeater {
            model: [
                { icon: "color", text: Weather.humidity + "%", tint: Theme.accent },
                { icon: "wave", text: Weather.wind + " " + Tr.t("km/h"), tint: Theme.accent },
                { icon: "sun", text: Weather.uv < 0 ? "" : Tr.t("UV") + " " + Math.round(Weather.uv), tint: root.uvColor },
                { icon: "leaf", text: Weather.aqi < 0 ? "" : Tr.t("Air") + " " + Weather.aqi, tint: root.aqiColor }
            ].filter(c => c.text !== "")

            Row {
                required property var modelData

                spacing: 3

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData.icon
                    size: 11
                    color: modelData.tint
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text
                    size: 10
                }
            }
        }
    }
    Row {
        id: compactHours

        readonly property real cell: width / Math.max(1, root.hours.length)

        visible: root.compact && Weather.hasData
        x: 14
        y: 92
        width: root.width - 28

        Repeater {
            model: root.compact ? root.hours : []

            Column {
                id: hourCell

                required property var modelData
                required property int index

                width: compactHours.cell

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: hourCell.modelData.temp + "°"
                    size: 10
                    font.weight: Font.DemiBold
                    color: hourCell.index === 0 ? root.warm : Theme.text
                }
                // The chance of rain as a thin bar.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 12
                    height: 3
                    radius: 1.5
                    color: Qt.alpha(root.rainColor, hourCell.modelData.rain > 0 ? 0.35 + hourCell.modelData.rain / 160 : 0.12)
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.hourLabel(hourCell.modelData.time)
                    size: 9
                    color: Theme.muted
                }
            }
        }
    }
    DayStrip {
        visible: root.compact && Weather.hasData
        x: 14
        y: 128
        width: root.width - 28
    }
}
