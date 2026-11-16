import QtQuick
import qs.components
import qs.services

// Claude Code's usage limits: the five-hour session and the week as rings, with when each resets.
// Fetched every five minutes while shown. A press opens the bar's Claude panel. Forms: wide, compact.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    // Set by WidgetHost: only the face, which lives while it is seen, asks for fresh numbers.
    property string role: ""
    property bool watching: false
    onRoleChanged: {
        if (role === "face" && !watching) {
            watching = true;
            ClaudeUsage.watch(1);
        }
    }
    Component.onDestruction: if (watching) ClaudeUsage.watch(-1)
    readonly property bool compact: form === "compact"

    function colorOf(v) {
        return v >= 90 ? Theme.error : v >= 70 ? Theme.warn : Theme.accent;
    }


    WidgetCaption {
        x: 20
        y: 16
        icon: "claude"
        text: Tr.t("Claude limits")
        tint: Theme.hueShift(Theme.accent, 0.06)
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: root.compact ? 16 : 20
        y: root.compact ? 19 : 20
        width: root.compact ? 130 : implicitWidth
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: ClaudeUsage.updatedText
        size: root.compact ? 10 : 11
        color: Theme.muted
    }
    Label {
        anchors.centerIn: parent
        visible: !ClaudeUsage.hasData
        text: Tr.t("No numbers yet")
        size: 13
        color: Theme.muted
    }
    Row {
        visible: ClaudeUsage.hasData
        x: 20
        y: root.compact ? 48 : 52
        spacing: root.compact ? 10 : 16

        Repeater {
            model: [
                { title: Tr.t("Session"), value: ClaudeUsage.fiveHour, reset: ClaudeUsage.fiveHourReset },
                { title: Tr.t("Week"), value: ClaudeUsage.weekly, reset: ClaudeUsage.weeklyReset }
            ]

            Row {
                id: lim

                required property var modelData

                spacing: root.compact ? 8 : 12

                Item {
                    width: root.compact ? 54 : 84
                    height: width

                    Ring {
                        anchors.fill: parent
                        thickness: root.compact ? 6 : 9
                        value: lim.modelData.value / 100
                        color: root.colorOf(lim.modelData.value)
                    }
                    Label {
                        anchors.centerIn: parent
                        text: Math.round(lim.modelData.value) + "%"
                        size: root.compact ? 13 : 19
                        font.weight: Font.Bold
                    }
                }
                Column {
                    visible: !root.compact
                    anchors.verticalCenter: parent.verticalCenter
                    width: 112
                    spacing: 3

                    Label {
                        text: lim.modelData.title
                        size: 14
                        font.weight: Font.DemiBold
                    }
                    Label {
                        width: parent.width
                        text: lim.modelData.reset
                        size: 11
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                    }
                }
                // Compact: the title and when it resets, beside the ring.
                Column {
                    visible: root.compact
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    spacing: 1

                    Label {
                        text: lim.modelData.title
                        size: 12
                        font.weight: Font.DemiBold
                    }
                    Label {
                        width: parent.width
                        text: lim.modelData.reset
                        size: 10
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    WidgetHot {
        anchors.fill: parent
        onClicked: Ui.popup = "claude"
    }
}
