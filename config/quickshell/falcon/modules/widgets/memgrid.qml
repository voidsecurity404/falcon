import QtQuick
import qs.components
import qs.services

// Used memory as a field of blocks. Forms: wide, compact (one row).
Item {
    id: root

    property string form: "wide"
    readonly property bool compact: form === "compact"
    readonly property int across: compact ? 25 : 13
    readonly property int count: compact ? 25 : 52
    readonly property int filled: Math.round(Sys.ram / 100 * count)

    Item {
        x: 20
        y: root.compact ? 12 : 14
        width: parent.width - 40
        height: 30

        Label {
            id: used

            anchors.verticalCenter: parent.verticalCenter
            text: Sys.ramGb.toFixed(1)
            size: root.compact ? 22 : 26
            font.family: Theme.display
            font.weight: Font.Medium
        }
        Label {
            anchors.baseline: used.baseline
            anchors.left: used.right
            anchors.leftMargin: 6
            text: "/ " + Math.round(Sys.ramTotalGb) + " " + Tr.t("GB")
            color: Theme.muted
            size: 12
        }
        Label {
            anchors.right: parent.right
            anchors.baseline: used.baseline
            text: Tr.t("Memory")
            color: Theme.muted
            size: 12
        }
    }
    Grid {
        id: field

        readonly property real cell: (root.width - 40 - (root.across - 1) * 4) / root.across

        x: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.compact ? 16 : 18
        columns: root.across
        spacing: 4

        Repeater {
            model: root.count

            delegate: Rectangle {
                required property int index

                width: field.cell
                height: root.compact ? 14 : field.cell
                radius: 4
                color: index < root.filled ? (Sys.ram >= 90 ? Theme.error : Theme.accent) : Qt.alpha(Theme.text, 0.09)

                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }
            }
        }
    }
}
