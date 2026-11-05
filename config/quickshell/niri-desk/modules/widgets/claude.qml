import QtQuick
import qs.components
import qs.services

// Forms: wide, compact (only the two meters).
Item {
    id: root

    property string form: "wide"

    Column {
        x: 18
        y: root.form === "compact" ? (parent.height - height) / 2 : 14
        width: parent.width - 36
        spacing: 10

        Label {
            visible: root.form !== "compact"
            text: Tr.t("Claude limits")
            color: Theme.muted
            size: 12
        }
        Repeater {
            model: [
                {
                    title: Tr.t("5 hours"),
                    value: ClaudeUsage.fiveHour,
                    reset: ClaudeUsage.fiveHourReset
                },
                {
                    title: Tr.t("Week"),
                    value: ClaudeUsage.weekly,
                    reset: ClaudeUsage.weeklyReset
                }
            ]

            delegate: Column {
                id: meter

                required property var modelData

                width: parent.width
                spacing: 4

                Item {
                    width: parent.width
                    height: 18

                    Label {
                        text: meter.modelData.title
                        size: 13
                    }
                    Label {
                        anchors.right: parent.right
                        text: ClaudeUsage.hasData ? Math.round(meter.modelData.value) + "%" : "—"
                        size: 13
                        font.weight: Font.Medium
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 3
                    color: Qt.alpha(Theme.text, 0.12)

                    Rectangle {
                        width: Math.max(height, parent.width * meter.modelData.value / 100)
                        height: parent.height
                        radius: 3
                        opacity: meter.modelData.value > 0 ? 1 : 0
                        color: meter.modelData.value >= 90 ? Theme.error : Theme.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
                Label {
                    visible: root.form !== "compact" && meter.modelData.reset !== ""
                    text: meter.modelData.reset
                    color: Theme.muted
                    size: 10
                }
            }
        }
    }
}
