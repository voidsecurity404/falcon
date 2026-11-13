import QtQuick
import qs.components
import qs.services

// Opens from the Claude part of the bar: the same glass menu as the others.
Flyout {
    id: root

    component Meter: Column {
        id: meter

        property string title: ""
        property real value: 0
        property string reset: ""

        width: parent.width
        spacing: 7

        Item {
            width: parent.width
            height: 24

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: meter.title
                size: 13
                color: Theme.muted
            }
            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(meter.value) + "%"
                size: 20
                font.weight: Font.Medium
                color: meter.value >= 90 ? Theme.error : Theme.text
            }
        }
        Rectangle {
            width: parent.width
            height: 8
            radius: 4
            color: Qt.alpha(Theme.text, 0.1)

            Rectangle {
                width: root.shown ? Math.max(height, parent.width * meter.value / 100) : height
                height: parent.height
                radius: 4
                color: meter.value >= 90 ? Theme.error : Theme.accent
                opacity: meter.value > 0 ? 1 : 0

                Behavior on width {
                    NumberAnimation {
                        duration: 620
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        Label {
            visible: meter.reset !== ""
            text: meter.reset
            size: 12
            color: Theme.muted
        }
    }

    panelWidth: 320
    padding: 18

    Column {
        id: content

        width: parent.width
        spacing: 18

        Label {
            text: Tr.t("Claude limits")
            size: 15
            font.weight: Font.Medium
        }
        Label {
            width: parent.width
            visible: !ClaudeUsage.hasData
            text: Tr.t("No data yet. Open Claude Code, the limits appear after its first reply")
            color: Theme.muted
            size: 13
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Meter {
            visible: ClaudeUsage.hasData
            title: Tr.t("5 hours")
            value: ClaudeUsage.fiveHour
            reset: ClaudeUsage.fiveHourReset
        }
        Meter {
            visible: ClaudeUsage.hasData
            title: Tr.t("Week")
            value: ClaudeUsage.weekly
            reset: ClaudeUsage.weeklyReset
        }
        Label {
            visible: ClaudeUsage.hasData && ClaudeUsage.statusText !== ""
            text: ClaudeUsage.statusText
            color: Qt.alpha(Theme.text, 0.4)
            size: 11
        }
    }
}
