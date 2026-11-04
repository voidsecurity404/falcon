import QtQuick
import qs.components
import qs.services

Item {
    readonly property var parts: /^(-?\d+°)\s*(.*)$/.exec(Weather.summary || "")

    Icon {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 18
        name: "sun"
        size: 22
        color: Theme.accent
    }
    Column {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Label {
            text: parent.parent.parts ? parent.parent.parts[1] : "—"
            size: 46
            font.weight: Font.Light
            font.letterSpacing: -1
        }
        Label {
            leftPadding: 2
            text: parent.parent.parts ? Tr.capitalized(parent.parent.parts[2]) : Tr.t("No weather data")
            color: Theme.muted
            size: 14
        }
    }
}
