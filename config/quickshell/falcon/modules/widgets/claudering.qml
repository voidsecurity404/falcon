import QtQuick
import qs.components
import qs.services

// Claude's limits as two rings. Forms: wide (with the time left), compact.
Item {
    id: root

    property string form: "wide"
    readonly property bool wide: form === "wide"
    readonly property var limits: [
        { title: Tr.t("5 hours"), value: ClaudeUsage.fiveHour, reset: ClaudeUsage.fiveHourReset },
        { title: Tr.t("Week"), value: ClaudeUsage.weekly, reset: ClaudeUsage.weeklyReset }
    ]

    Label {
        visible: root.wide
        x: 20
        y: 12
        text: Tr.t("Claude limits")
        color: Theme.muted
        size: 12
    }
    Row {
        x: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.wide ? 16 : (parent.height - 68) / 2
        spacing: 12

        Repeater {
            model: root.limits

            delegate: Row {
                id: limit

                required property var modelData
                required property int index

                spacing: 10

                Ring {
                    width: root.wide ? 84 : 68
                    height: width
                    thickness: root.wide ? 9 : 8
                    value: limit.modelData.value / 100
                    color: limit.modelData.value >= 90 ? Theme.error : Theme.hueShift(Theme.accent, limit.index * 0.14)

                    Label {
                        anchors.centerIn: parent
                        text: ClaudeUsage.hasData ? Math.round(limit.modelData.value) + "%" : "—"
                        size: root.wide ? 16 : 14
                        font.weight: Font.DemiBold
                    }
                }
                Column {
                    visible: root.wide || root.form === "compact"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62

                    Label {
                        width: parent.width
                        text: limit.modelData.title
                        size: 12
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
