import QtQuick
import QtQuick.Effects
import Quickshell.Io
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
    // A second place's time beside the date (widgets.clock.zone, an IANA name such as Europe/Moscow).
    readonly property string zone: String(Settings.get("widgets.clock.zone", "") || "").trim()
    readonly property string zoneName: {
        const n = String(Settings.get("widgets.clock.zoneName", "") || "").trim();
        return n !== "" ? n : zone.split("/").pop().replace(/_/g, " ");
    }
    // That zone's offset from UTC in minutes, asked from date(1) since QML has no time zone data.
    property int zoneOffset: 0
    property bool zoneKnown: false
    readonly property string zoneTime: {
        if (!zoneKnown)
            return "";
        const t = new Date(now.getTime() + (zoneOffset + now.getTimezoneOffset()) * 60000);
        const h = clock24 ? t.getHours() : (t.getHours() % 12 || 12);
        return (clock24 && h < 10 ? "0" : "") + h + ":" + (t.getMinutes() < 10 ? "0" : "") + t.getMinutes();
    }
    readonly property bool showPrayer: Prayer.enabled && !!Prayer.next

    function prayerClock(d) {
        const h = clock24 ? d.getHours() : (d.getHours() % 12 || 12);
        return (clock24 && h < 10 ? "0" : "") + h + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes();
    }

    onZoneChanged: askZone()
    Component.onCompleted: askZone()
    function askZone() {
        zoneKnown = false;
        if (zone === "")
            return;
        zoneProc.environment = ({ TZ: zone });
        zoneProc.running = true;
    }
    Process {
        id: zoneProc

        command: ["date", "+%z"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^([+-])(\d\d)(\d\d)$/);
                if (!m)
                    return;
                root.zoneOffset = (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3]));
                root.zoneKnown = true;
            }
        }
    }
    // Summer time can move the offset, so it is asked again now and then.
    Timer {
        interval: 600000
        running: root.zone !== ""
        repeat: true
        onTriggered: root.askZone()
    }

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
        Label {
            visible: root.zoneTime !== ""
            anchors.left: dateLine.right
            anchors.leftMargin: 10
            anchors.baseline: dateLine.baseline
            text: "·  " + root.zoneName + " " + root.zoneTime
            size: root.compact ? 13 : 16
            font.weight: Font.Medium
            color: root.second
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
            y: chips.y - (root.compact ? 9 : 18)
            width: root.width - 12
            height: root.compact ? 4 : 6

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(Theme.text, 0.18)
            }
            Rectangle {
                width: Math.max(6, parent.width * root.minuteShare)
                height: parent.height
                radius: height / 2
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

        // Every chip shows in every form; a narrow form wraps them onto a second line.
        Flow {
            id: chips

            x: 6
            y: root.compact ? root.height - height - 4 : root.height - height - 6
            width: root.width - 12
            spacing: root.compact ? 6 : 8

            component Chip: Rectangle {
                id: chip

                property string icon: ""
                property string text: ""
                property color tint: Theme.text

                width: chipRow.implicitWidth + (root.compact ? 14 : 22)
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
                text: Weather.temperature + "°" + (root.compact || root.stacked ? "" : "  " + Weather.describe(Weather.code))
                tint: Theme.accent
            }
            Chip {
                visible: root.showPrayer
                icon: "mosque"
                text: root.showPrayer ? Tr.t(Prayer.next.name) + " " + root.prayerClock(Prayer.next.time) : ""
                tint: root.second
            }
            Chip {
                visible: Countdown.active
                icon: Countdown.icon
                text: Countdown.text
                tint: root.second
            }
            Chip {
                visible: Sys.hasBattery
                icon: Sys.charging ? "charging" : "battery"
                text: Sys.batteryPercent + "%"
                tint: Sys.batteryPercent <= 20 && !Sys.charging ? Theme.error : Theme.good
            }
        }
    }
}
