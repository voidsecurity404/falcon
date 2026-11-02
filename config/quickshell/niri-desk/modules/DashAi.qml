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

    Flickable {
        id: chat

        width: parent.width
        height: parent.height - composer.height - 10
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
            spacing: 10

            Label {
                visible: Ai.messages.length === 0
                width: parent.width
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                text: Tr.t("Type your question below. Enter sends, Shift+Enter adds a line. The chat is sent to Claude over the internet.")
                color: Theme.muted
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
                        width: bubble.mine ? Math.min(parent.width * 0.8, natural.advanceWidth + 28) : parent.width
                        height: body.implicitHeight + 16
                        radius: 11
                        color: bubble.mine ? Qt.alpha(Theme.accent, 0.18) : bubble.failed ? Qt.alpha(Theme.error, 0.16) : "transparent"

                        TextEdit {
                            id: body

                            x: bubble.mine || bubble.failed ? 12 : 0
                            y: 8
                            width: parent.width - 2 * x
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            text: bubble.modelData.text
                            color: bubble.failed ? Theme.error : Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            font.family: Theme.sans
                            font.pixelSize: Math.round(14 * Theme.fontScale)
                            Keys.onEscapePressed: Ui.popup = ""
                        }
                    }
                }
            }

            Label {
                visible: Ai.busy && (Ai.messages.length === 0 || Ai.messages[Ai.messages.length - 1].role !== "assistant")
                text: Tr.t("Waiting for a reply…")
                color: Theme.muted
            }
        }
    }

    Row {
        id: composer

        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 6

        Rectangle {
            width: parent.width - 104
            height: Math.min(96, input.implicitHeight + 18)
            radius: 11
            color: Qt.alpha(Theme.text, 0.07)
            border.width: input.activeFocus ? 1 : 0
            border.color: Theme.accent

            Flickable {
                x: 12
                y: 9
                width: parent.width - 24
                height: parent.height - 18
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
                    font.pixelSize: Math.round(14 * Theme.fontScale)
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
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: Tr.t("Ask Claude…")
                color: Qt.alpha(Theme.text, 0.4)
            }
        }

        Rectangle {
            width: 98
            height: 36
            radius: 11
            color: Qt.alpha(Theme.text, actionArea.containsMouse ? 0.14 : 0.08)

            Label {
                anchors.centerIn: parent
                text: Ai.busy ? Tr.t("Stop") : Tr.t("Clear")
                size: 13
            }
            MouseArea {
                id: actionArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ai.busy ? Ai.stop() : Ai.clear()
            }
        }
    }
}
