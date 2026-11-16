import QtQuick
import qs.components
import qs.services

// Waiting system updates (falcon-updates check): how many, the first package names, and a button
// that opens the update in a terminal. Says when a reboot finishes an update. Forms: wide, compact.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool compact: form === "compact"
    readonly property bool none: Updates.count === 0
    readonly property color tint: Updates.rebootNeeded ? Theme.warn : none ? Theme.good : Theme.accent

    WidgetCaption {
        x: 20
        y: 16
        icon: "update"
        text: Tr.t("Updates")
        tint: root.tint
    }
    Row {
        x: 20
        y: root.compact ? 44 : 48
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.none
            text: Updates.count
            font.family: Theme.display
            font.pixelSize: root.compact ? 34 : 44
            font.weight: Font.DemiBold
            color: Theme.text
        }
        Rectangle {
            visible: root.none
            anchors.verticalCenter: parent.verticalCenter
            width: root.compact ? 40 : 48
            height: width
            radius: width / 2
            color: Qt.alpha(root.tint, 0.18)

            Icon {
                anchors.centerIn: parent
                name: Updates.rebootNeeded ? "reboot" : "check"
                size: parent.width * 0.45
                color: root.tint
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Label {
                text: Updates.rebootNeeded ? Tr.t("Reboot to finish the update") : root.none ? Tr.t("System is up to date") : Tr.t("packages waiting")
                size: 13
                font.weight: Font.Medium
            }
            Label {
                text: Updates.failed ? Tr.t("Last check failed") : Updates.lastGood > 0 ? Tr.t("Checked") + " " + Qt.formatTime(new Date(Updates.lastGood), "hh:mm") : ""
                size: 11
                color: Updates.failed ? Theme.error : Theme.muted
            }
        }
    }
    Flow {
        visible: !root.compact && !root.none
        x: 20
        y: 110
        width: root.width - 40
        height: 30
        clip: true
        spacing: 6

        Repeater {
            model: Updates.packages.slice(0, 8)

            Rectangle {
                required property string modelData

                width: pkg.implicitWidth + 16
                height: 24
                radius: 12
                color: Qt.alpha(Theme.text, 0.08)

                Label {
                    id: pkg

                    anchors.centerIn: parent
                    text: parent.modelData
                    size: 11
                    font.family: Theme.mono
                }
            }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        spacing: 6

        WidgetButton {
            height: 34
            icon: "refresh"
            onClicked: Updates.check()
        }
        WidgetButton {
            visible: !root.none || Updates.rebootNeeded
            height: 34
            main: true
            icon: Updates.rebootNeeded && root.none ? "reboot" : "update"
            text: root.compact ? "" : Updates.rebootNeeded && root.none ? Tr.t("Reboot") : Tr.t("Update")
            onClicked: Updates.clicked()
        }
    }
}
