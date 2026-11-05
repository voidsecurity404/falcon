import QtQuick
import qs.components
import qs.services

// Forms: wide, tall (icon above the numbers), compact (icon beside them).
Item {
    id: root

    property string form: "wide"
    readonly property var parts: /^(-?\d+°)\s*(.*)$/.exec(Weather.summary || "")
    readonly property bool tall: form === "tall"
    readonly property bool compact: form === "compact"

    Icon {
        x: root.compact ? 18 : root.tall ? 20 : parent.width - width - 18
        y: root.compact ? (parent.height - height) / 2 : 18
        name: "sun"
        size: root.compact ? 26 : root.tall ? 30 : 22
        color: Theme.accent
    }
    Column {
        x: root.compact ? 58 : 20
        y: root.tall ? 64 : (parent.height - height) / 2
        width: parent.width - x - (root.compact ? 14 : 20)
        spacing: 0

        Label {
            text: root.parts ? root.parts[1] : "—"
            size: root.compact ? 30 : 46
            font.weight: Font.Light
            font.letterSpacing: -1
        }
        Label {
            width: parent.width
            leftPadding: 2
            text: root.parts ? Tr.capitalized(root.parts[2]) : Tr.t("No weather data")
            color: Theme.muted
            size: root.compact ? 12 : 14
            wrapMode: root.tall ? Text.WordWrap : Text.NoWrap
            maximumLineCount: root.tall ? 3 : 1
        }
    }
}
