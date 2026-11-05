import QtQuick
import qs.components
import qs.services

// Top of the power page: says what the battery can do and what is left to set up.
Column {
    id: root

    spacing: 10

    Rectangle {
        width: root.width
        height: note.implicitHeight + 28
        radius: 18
        color: Qt.alpha(Power.needsSetup ? Theme.accent : Theme.text, Power.needsSetup ? 0.16 : 0.05)
        visible: !Sys.hasBattery || !Power.chargeSupported || Power.needsSetup || Power.aboveLimit

        Label {
            id: note

            x: 16
            y: 14
            width: parent.width - 32 - (setup.visible ? setup.width + 14 : 0)
            wrapMode: Text.WordWrap
            size: 13
            text: !Sys.hasBattery ? Tr.t("This computer has no battery, so nothing here applies.") : !Power.chargeSupported ? Tr.t("This battery has no charge limit. The firmware does not offer one.") : Power.needsSetup ? Tr.t("The charge limit needs a one time setup with your password. Your choice is kept until then.") : Tr.t("The battery is at {now}%. It stays above the limit until it is used, charging starts again below {limit}%.").replace("{now}", Sys.batteryPercent).replace("{limit}", Power.limitValue)
        }
        Rectangle {
            id: setup

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: Power.needsSetup
            width: setupText.implicitWidth + 28
            height: 36
            radius: 18
            color: setupArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent

            Label {
                id: setupText

                anchors.centerIn: parent
                text: Tr.t("Set up")
                color: Theme.accentText
                size: 13
                font.weight: Font.Medium
            }
            MouseArea {
                id: setupArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Power.runSetup()
            }
        }
    }
}
