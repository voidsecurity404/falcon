import QtQuick
import qs.services

// Settings page of the text snippets.
Column {
    id: root

    spacing: 10

    Label {
        width: parent.width
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        text: Tr.t("{key} opens the list and Enter types the text into the window you were in. In the text, {date}, {time} and {clipboard} are filled in.").replace("{key}", Settings.get("binds.snippets", "Mod+Semicolon"))
        color: Theme.muted
        size: 13
    }

    Repeater {
        model: Snippets.items

        delegate: Rectangle {
            id: card

            required property var modelData
            required property int index

            width: root.width
            height: 112
            radius: 18
            color: Qt.alpha(Theme.text, 0.045)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.06)

            Rectangle {
                x: 14
                y: 12
                width: 180
                height: 34
                radius: 10
                color: Qt.alpha(Theme.text, 0.07)

                TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.family: Theme.sans
                    font.pixelSize: 13
                    text: card.modelData.trigger
                    onEditingFinished: Snippets.change(card.index, "trigger", text)

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.text === ""
                        text: Tr.t("Name")
                        color: Theme.muted
                        size: 13
                    }
                }
            }
            PillButton {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 12
                icon: "close"
                implicitWidth: 34
                onClicked: Snippets.remove(card.index)
            }
            Rectangle {
                x: 14
                y: 52
                width: parent.width - 28
                height: 48
                radius: 10
                color: Qt.alpha(Theme.text, 0.07)
                clip: true

                TextEdit {
                    anchors.fill: parent
                    anchors.margins: 8
                    anchors.leftMargin: 11
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.family: Theme.sans
                    font.pixelSize: 13
                    text: card.modelData.text
                    onActiveFocusChanged: {
                        if (!activeFocus)
                            Snippets.change(card.index, "text", text);
                    }

                    Label {
                        visible: parent.text === ""
                        text: Tr.t("Text")
                        color: Theme.muted
                        size: 13
                    }
                }
            }
        }
    }

    PillButton {
        text: Tr.t("Add a snippet")
        icon: "text"
        onClicked: Snippets.add()
    }
}
