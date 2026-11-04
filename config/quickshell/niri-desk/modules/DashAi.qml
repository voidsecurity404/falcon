import QtQuick
import Quickshell
import qs.components
import qs.services

// AI chat: suhbat shu vkladkada, javob yozilayotganda ko'rinib boradi.
Item {
    id: root

    onVisibleChanged: {
        if (visible) {
            Ai.load();
            input.forceActiveFocus();
        }
    }
    Component.onCompleted: {
        if (visible) {
            Ai.load();
            input.forceActiveFocus();
        }
    }

    // A centered column of glass bubbles over the aurora.
    readonly property int column: 860

    Flickable {
        id: chat

        anchors.horizontalCenter: parent.horizontalCenter
        width: root.column
        height: parent.height - composer.height - 16
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        function toEnd() {
            contentY = Math.max(0, contentHeight - height);
        }

        Connections {
            target: Ai
            function onChanged() {
                Qt.callLater(chat.toEnd);
            }
        }

        Column {
            id: list

            width: parent.width
            spacing: 12

            Label {
                visible: Ai.messages.length === 0
                width: parent.width
                topPadding: 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                text: Tr.t("Type your question below. Enter sends, Shift+Enter adds a line. The chat is sent to Claude over the internet.")
                color: Qt.alpha(Theme.text, 0.75)
                size: 15
            }

            Repeater {
                model: Ai.messages

                delegate: Item {
                    id: bubble

                    required property var modelData

                    readonly property bool mine: modelData.role === "user"
                    readonly property bool failed: modelData.role === "error"

                    width: list.width
                    height: back.height

                    TextMetrics {
                        id: natural

                        font: body.font
                        text: bubble.modelData.text
                    }

                    Rectangle {
                        id: back

                        x: bubble.mine ? parent.width - width : 0
                        width: Math.min(parent.width * 0.78, natural.advanceWidth + 36)
                        height: body.implicitHeight + 24
                        topLeftRadius: 20
                        topRightRadius: 20
                        bottomLeftRadius: bubble.mine ? 20 : 6
                        bottomRightRadius: bubble.mine ? 6 : 20
                        color: bubble.mine ? Qt.alpha(Theme.text, 0.92) : bubble.failed ? Qt.alpha(Theme.error, 0.2) : Qt.alpha(Theme.text, 0.13)
                        border.width: bubble.mine ? 0 : 1
                        border.color: Qt.alpha(Theme.text, 0.2)

                        TextEdit {
                            id: body

                            x: 16
                            y: 12
                            width: parent.width - 2 * x
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            text: bubble.modelData.text
                            color: bubble.mine ? Theme.pill : bubble.failed ? Theme.error : Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            font.family: Theme.sans
                            font.pixelSize: Math.round(15 * Theme.fontScale)
                            Keys.onEscapePressed: Ui.popup = ""
                        }
                    }
                }
            }

            Label {
                visible: Ai.busy && (Ai.messages.length === 0 || Ai.messages[Ai.messages.length - 1].role !== "assistant")
                text: Tr.t("Waiting for a reply…")
                color: Qt.alpha(Theme.text, 0.75)
            }
        }
    }

    Rectangle {
        id: composer

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.column
        height: Math.min(112, Math.max(50, input.implicitHeight + 24))
        radius: 25
        color: Qt.alpha(Theme.text, 0.13)
        border.width: 1
        border.color: Qt.alpha(Theme.text, input.activeFocus ? 0.45 : 0.27)

        Flickable {
            x: 22
            y: 12
            width: parent.width - 22 - send.width - 18
            height: parent.height - 24
            contentHeight: input.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: input

                width: parent.width
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.family: Theme.sans
                font.pixelSize: Math.round(15 * Theme.fontScale)
                Keys.onEscapePressed: Ui.popup = ""
                Keys.onTabPressed: Ui.nextDashTab(1)
                Keys.onBacktabPressed: Ui.nextDashTab(-1)
                Keys.onReturnPressed: event => {
                    if (event.modifiers & Qt.ShiftModifier) {
                        event.accepted = false;
                    } else if (Ai.send(input.text)) {
                        input.text = "";
                    }
                }
                Keys.onEnterPressed: event => {
                    if (Ai.send(input.text))
                        input.text = "";
                }
            }
        }

        Label {
            x: 22
            y: 12
            visible: input.text === ""
            text: Tr.t("Ask Claude…")
            size: 15
            color: Qt.alpha(Theme.text, 0.65)
        }

        // Sends, or stops a reply that is still being written.
        Rectangle {
            id: send

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: sendLabel.implicitWidth + 36
            height: 38
            radius: 19
            color: Theme.text
            scale: sendArea.pressed ? 0.94 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 110
                }
            }

            Label {
                id: sendLabel

                anchors.centerIn: parent
                text: Ai.busy ? Tr.t("Stop") : Tr.t("Send")
                color: Theme.pill
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: sendArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Ai.busy)
                        Ai.stop();
                    else if (Ai.send(input.text))
                        input.text = "";
                    input.forceActiveFocus();
                }
            }
        }
    }

    // Clears the conversation.
    Rectangle {
        anchors.left: composer.right
        anchors.leftMargin: 10
        anchors.verticalCenter: composer.verticalCenter
        width: 40
        height: 40
        radius: 20
        visible: Ai.messages.length > 0 && !Ai.busy
        color: Qt.alpha(Theme.text, clearArea.containsMouse ? 0.24 : 0.13)

        Icon {
            anchors.centerIn: parent
            name: "close"
            size: 15
        }
        MouseArea {
            id: clearArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Ai.clear()
        }
    }
}
