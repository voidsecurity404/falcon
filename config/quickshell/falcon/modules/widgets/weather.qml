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
        y: root.compact ? 16 : 20
        width: root.large ? root.width - 44 : root.compact ? root.width - 44 : 190
        height: root.compact ? root.height - 32 : 150

        WidgetCaption {
            visible: !root.compact
            icon: "globe"
            text: Tr.t("Now")
        }
        Row {
            id: tempRow

            y: root.compact ? 0 : 32
            spacing: 12

            Item {
                visible: root.compact || root.large
                anchors.verticalCenter: parent.verticalCenter
                width: root.compact ? 48 : 64
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
                font.pixelSize: root.compact ? 44 : 62
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Column {
                visible: root.large || root.compact
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Label {
                    text: Tr.capitalized(Weather.describe(Weather.code))
                    size: root.compact ? 14 : 17
                    font.weight: Font.DemiBold
                    font.capitalization: Font.Capitalize
                }
                Label {
                    text: Tr.t("Feels like") + " " + Weather.feels + "°"
                    size: 12
                    color: Theme.muted
                }
                Label {
                    visible: !!root.today
                    text: root.today ? "↑ " + root.today.max + "°   ↓ " + root.today.min + "°" + (root.compact && root.today.rain > 0 ? "   ☂ " + root.today.rain + "%" : "") : ""
                    size: 12
                    color: Theme.muted
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
            visible: !root.compact
            y: root.large ? 112 : 136
            width: parent.width
            spacing: 6

            Repeater {
                model: [
                    { icon: "color", text: Weather.humidity + "%" },
                    { icon: "wave", text: Weather.wind + " " + Tr.t("km/h") },
                    { icon: "sun", text: root.clock(Weather.sunrise) },
                    { icon: "moon", text: root.clock(Weather.sunset) }
                ].slice(0, root.large ? 4 : 2)

                Rectangle {
                    required property var modelData

                    width: statRow.implicitWidth + 18
                    height: 28
                    radius: 14
                    color: Qt.alpha(Theme.text, 0.08)

                    Row {
                        id: statRow

                        anchors.centerIn: parent
                        spacing: 5

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.icon
                            size: 12
                            color: Theme.accent
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
        y: root.large ? 158 : 18
        width: root.width - x - 14
        height: root.large ? 132 : root.height - 30

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
        y: 304
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
}
