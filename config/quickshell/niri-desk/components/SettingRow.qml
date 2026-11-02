import QtQuick
import qs.services

// Sozlamalar oynasidagi bitta qator: turiga qarab tugma, slider, tanlov yoki matn maydoni.
Item {
    id: root

    property var item: ({})

    readonly property var value: Settings.get(item.key, item.fallback)

    implicitHeight: 46

    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: 300

        Label {
            width: parent.width
            text: root.item.label || ""
        }
        Label {
            width: parent.width
            visible: !!root.item.hint
            text: root.item.hint || ""
            color: Theme.muted
            size: 12
        }
    }

    // Tugma
    Rectangle {
        visible: root.item.type === "toggle"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        height: 24
        radius: 12
        color: root.value === true ? Theme.accent : Qt.alpha(Theme.text, 0.14)

        Rectangle {
            x: root.value === true ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            color: root.value === true ? Theme.accentText : Theme.text

            Behavior on x {
                NumberAnimation {
                    duration: 120
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Settings.set(root.item.key, root.value !== true)
        }
    }

    // Slider
    Row {
        visible: root.item.type === "slider"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        SliderBar {
            anchors.verticalCenter: parent.verticalCenter
            width: 200
            value: root.item.type === "slider" ? (Number(root.value) - root.item.min) / (root.item.max - root.item.min) : 0
            onMoved: fraction => {
                const raw = root.item.min + fraction * (root.item.max - root.item.min);
                const stepped = Math.round(raw / root.item.step) * root.item.step;
                Settings.set(root.item.key, Math.round(stepped * 1000) / 1000);
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            horizontalAlignment: Text.AlignRight
            text: root.item.type === "slider" ? String(Math.round(Number(root.value) * 100) / 100) : ""
            color: Theme.muted
            size: 13
        }
    }

    // Tanlov
    Row {
        visible: root.item.type === "choice"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            model: root.item.type === "choice" ? root.item.options.length : 0

            delegate: Rectangle {
                id: option

                required property int index

                readonly property var optionValue: root.item.options[index]
                readonly property bool selected: root.value === optionValue
                readonly property string name: root.item.names ? root.item.names[index] : String(optionValue).replace("scheme-", "")

                width: nameLabel.implicitWidth + 14
                height: 28
                radius: 7
                color: selected ? Qt.alpha(Theme.accent, 0.24) : Qt.alpha(Theme.text, optionArea.containsMouse ? 0.13 : 0.06)

                Label {
                    id: nameLabel

                    anchors.centerIn: parent
                    text: option.name
                    color: option.selected ? Theme.accent : Theme.text
                    size: root.item.options.length > 4 ? 11 : 13
                }
                MouseArea {
                    id: optionArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.set(root.item.key, option.optionValue)
                }
            }
        }
    }

    // Matn yoki son: Enter yoki fokusdan chiqqanda saqlanadi
    Rectangle {
        visible: root.item.type === "text" || root.item.type === "number"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 300
        height: 32
        radius: 8
        color: Qt.alpha(Theme.text, 0.07)
        border.width: input.activeFocus ? 1 : 0
        border.color: Theme.accent

        TextInput {
            id: input

            anchors.fill: parent
            leftPadding: 10
            rightPadding: 10
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: 13
            selectByMouse: true
            text: root.value === undefined ? "" : String(root.value)

            function commit() {
                if (root.item.type !== "text" && root.item.type !== "number")
                    return;
                const next = root.item.type === "number" ? Number(text) : text;
                if (root.item.type === "number" && isNaN(next))
                    return;
                if (next !== root.value)
                    Settings.set(root.item.key, next);
            }

            onAccepted: commit()
            onEditingFinished: commit()
            Keys.onEscapePressed: Ui.settingsOpen = false
        }
    }
}
