import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// The temperature on a sky of the weather outside, day or night. Forms: wide, tall, compact.
Item {
    id: root

    property string form: "wide"
    readonly property bool tall: form === "tall"
    readonly property bool compact: form === "compact"
    readonly property string kind: Weather.kind(Weather.code)
    readonly property var colors: {
        if (!Weather.isDay)
            return ({
                    clear: ["#0a1233", "#2a3468"],
                    partly: ["#10183a", "#343d68"],
                    cloudy: ["#1a2030", "#3b4356"],
                    fog: ["#22272f", "#474d56"],
                    rain: ["#111a2a", "#2d3b50"],
                    snow: ["#222c42", "#55637e"],
                    storm: ["#120f28", "#3a3163"]
                })[kind];
        return ({
                clear: ["#1f6fd6", "#79c3f7"],
                partly: ["#3a7cc9", "#a0c8e6"],
                cloudy: ["#566a82", "#94a6b8"],
                fog: ["#6f7a86", "#b0b8c0"],
                rain: ["#34475f", "#61758c"],
                snow: ["#7f9dc0", "#d0dfee"],
                storm: ["#2a2750", "#5a5286"]
            })[kind];
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: root.colors[0]
                }
                GradientStop {
                    position: 1
                    color: root.colors[1]
                }
            }
        }

        // The light of the sun or moon, in soft rings from a corner.
        Repeater {
            model: root.kind === "clear" || root.kind === "partly" ? [150, 104, 62] : []

            delegate: Rectangle {
                required property int modelData

                x: root.width - 40 - modelData / 2
                y: 34 - modelData / 2
                width: modelData
                height: modelData
                radius: modelData / 2
                color: Qt.alpha(Weather.isDay ? "#fff4c2" : "#dfe6ff", Weather.isDay ? 0.2 : 0.09)
            }
        }
        Icon {
            x: root.width - width - (root.compact ? 18 : 20)
            y: root.compact ? (root.height - height) / 2 : 18
            name: Weather.icon(Weather.code, Weather.isDay)
            size: root.compact ? 34 : 42
            color: "white"
        }
        Column {
            x: 20
            y: root.tall ? root.height - height - 16 : (root.height - height) / 2
            width: root.width - x - (root.tall ? 16 : 76)
            spacing: root.compact ? 0 : 2

            Label {
                text: Weather.hasData ? Weather.temperature + "°" : "—"
                color: "white"
                size: root.compact ? 34 : 56
                font.family: Theme.display
                font.weight: Font.Medium
            }
            Label {
                width: parent.width
                text: Weather.hasData ? Tr.capitalized(Weather.describe(Weather.code)) : Tr.t("No weather data")
                color: "white"
                size: root.compact ? 12 : 15
                font.weight: Font.Medium
                wrapMode: root.tall ? Text.WordWrap : Text.NoWrap
                maximumLineCount: 2
            }
            Label {
                visible: !root.compact && Weather.hasData
                width: parent.width
                text: Tr.t("Feels like {t}°").replace("{t}", Weather.feels)
                color: Qt.alpha("#ffffff", 0.78)
                size: 12
            }
        }
    }
}
