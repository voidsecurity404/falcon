import QtQuick
import QtQuick.Effects
import qs.components
import qs.services

// A large clock right on the wallpaper: the date over it, a bar running through the minute under it,
// and the weather, a running timer and the battery as chips. Forms: wide, stacked, compact.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool stacked: form === "stacked"
    readonly property bool compact: form === "compact"
    readonly property bool clock24: Settings.get("panel.clock24", true)
    property date now: new Date()
    readonly property int hours: clock24 ? now.getHours() : (now.getHours() % 12 || 12)
    readonly property string hh: (clock24 && hours < 10 ? "0" : "") + hours
    readonly property string mm: (now.getMinutes() < 10 ? "0" : "") + now.getMinutes()
    readonly property real minuteShare: now.getSeconds() / 60
    readonly property color second: Theme.hueShift(Theme.accent, 0.08)

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Item {
        id: body

        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.5
            shadowBlur: 0.9
            shadowVerticalOffset: 3
            blurMax: 32
        }

        Label {
            id: dateLine

            x: 6
            y: root.compact ? 6 : 10
            text: {
                const t = Qt.locale().toString(root.now, root.compact ? "ddd, d MMMM" : "dddd, d MMMM");
                return t.charAt(0).toUpperCase() + t.slice(1);
            }
            size: root.compact ? 15 : 19
            font.weight: Font.Medium
            color: Theme.text
        }

        // Hours and minutes side by side, or the minutes under the hours.
        Row {
            id: timeRow

            visible: !root.stacked
            x: 0
            y: dateLine.y + dateLine.height - (root.compact ? 4 : 8)
            spacing: root.compact ? 6 : 10

            Text {
                text: root.hh
                font.family: Theme.display
                font.pixelSize: root.compact ? 62 : 116
                font.weight: Font.Bold
                color: Theme.text
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.compact ? 8 : 16

                Repeater {
                    model: 2

                    Rectangle {
                        width: root.compact ? 8 : 13
                        height: width
                        radius: width / 2
                        color: Theme.accent
                        opacity: root.now.getSeconds() % 2 === 0 ? 1 : 0.35

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                            }
                        }
                    }
                }
            }
            Text {
                text: root.mm
                font.family: Theme.display
                font.pixelSize: root.compact ? 62 : 116
                font.weight: Font.Light
                color: Theme.accent
            }
            Text {
                visible: !root.clock24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.compact ? 12 : 24
                text: root.now.getHours() < 12 ? "AM" : "PM"
                font.family: Theme.display
                font.pixelSize: root.compact ? 14 : 22
                color: Theme.muted
            }
        }
        Column {
            visible: root.stacked
            x: 0
            y: dateLine.y + dateLine.height - 6
            spacing: -30

            Text {
                text: root.hh
                font.family: Theme.display
                font.pixelSize: 118
                font.weight: Font.Bold
                color: Theme.text
            }
            Text {
                text: root.mm
                font.family: Theme.display
                font.pixelSize: 118
                font.weight: Font.Light
                color: Theme.accent
            }
        }

        // The running minute.
        Item {
            id: minute

            x: 6
            y: chips.y - 18
            width: root.width - 12
            height: 6
            visible: !root.compact

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Qt.alpha(Theme.text, 0.18)
            }
            Rectangle {
                width: Math.max(6, parent.width * root.minuteShare)
                height: parent.height
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Theme.accent
                    }
                    GradientStop {
                        position: 1
                        color: root.second
                    }
                }

                Behavior on width {
                    enabled: root.now.getSeconds() !== 0

                    NumberAnimation {
                        duration: 950
                    }
                }
            }
        }

        Row {
            id: chips

            x: 6
            y: root.compact ? root.height - height - 4 : root.height - height - 6
            spacing: 8

            component Chip: Rectangle {
                id: chip

                property string icon: ""
                property string text: ""
                property color tint: Theme.text

                width: chipRow.implicitWidth + 22
                height: root.compact ? 28 : 34
                radius: height / 2
                color: Qt.alpha(Theme.pill, 0.42)
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.12)

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: chip.icon
                        size: root.compact ? 13 : 15
                        color: chip.tint
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.text
                        size: root.compact ? 12 : 14
                        font.weight: Font.Medium
                    }
                }
            }

            Chip {
                visible: Weather.hasData
                icon: Weather.icon(Weather.code, Weather.isDay)
                text: Weather.temperature + "°  " + Weather.describe(Weather.code)
                tint: Theme.accent
            }
            Chip {
                visible: Countdown.active && !root.compact
                icon: Countdown.icon
                text: Countdown.text
                tint: root.second
            }
            Chip {
                visible: Sys.hasBattery && !root.stacked
                icon: Sys.charging ? "charging" : "battery"
                text: Sys.batteryPercent + "%"
                tint: Sys.batteryPercent <= 20 && !Sys.charging ? Theme.error : Theme.good
            }
        }
    }
}
