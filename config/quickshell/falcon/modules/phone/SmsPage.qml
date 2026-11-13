import QtQuick
import qs.components
import qs.services

// SMS through the phone: the conversations, one conversation as bubbles with a reply field,
// and a new message to any number.
PhonePage {
    id: root

    // "list", "thread", "new"
    property string mode: Phone.thread ? "thread" : composing ? "new" : "list"
    property bool composing: false
    readonly property var current: Phone.thread ? Phone.conversations.find(c => c.thread === Phone.thread.thread) || null : null

    title: mode === "thread" ? (current ? current.name || current.addresses.join(", ") : Tr.t("Messages")) : mode === "new" ? Tr.t("New message") : Tr.t("Messages")
    subtitle: mode === "thread" && current && current.name !== current.addresses.join(", ") ? current.addresses.join(", ") : ""

    function dateLabel(ms) {
        const d = new Date(ms);
        const now = new Date();
        if (d.toDateString() === now.toDateString())
            return Qt.formatTime(d, "hh:mm");
        return Qt.formatDate(d, "dd.MM");
    }

    // The phone answers within seconds, or not at all when KDE Connect there may not read SMS.
    property bool gaveUp: false

    Component.onCompleted: Phone.send("smsSync")

    Timer {
        interval: 15000
        running: root.mode === "list" && list.count === 0 && !root.gaveUp
        onTriggered: root.gaveUp = true
    }
    Component.onDestruction: Phone.closeThread()

    actions: [
        PhoneButton {
            visible: root.mode === "list"
            icon: "plus"
            implicitWidth: 38
            onClicked: {
                root.composing = true;
                Qt.callLater(() => numberField.focusField());
            }
        },
        PhoneButton {
            visible: root.mode !== "list"
            icon: "close"
            implicitWidth: 38
            onClicked: {
                root.composing = false;
                Phone.closeThread();
            }
        }
    ]

    // ---- conversations ----
    ListView {
        id: list

        anchors.fill: parent
        visible: root.mode === "list"
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: Phone.conversations

        Label {
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: list.count === 0
            text: root.gaveUp ? Tr.t("The phone sent no conversations. Allow SMS for KDE Connect on the phone, then open this page again.") : Tr.t("Loading conversations from the phone…")
            color: Theme.muted
            size: 12
        }

        delegate: Rectangle {
            id: conv

            required property var modelData

            width: ListView.view.width
            height: 64
            radius: 18
            color: Qt.alpha(Theme.text, convArea.containsMouse ? 0.09 : 0.04)

            Rectangle {
                id: avatar

                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 42
                radius: 21
                color: Qt.alpha(Theme.hueShift(Theme.accent, (conv.modelData.thread % 12) / 12), 0.35)

                Label {
                    anchors.centerIn: parent
                    text: (conv.modelData.name || "#").replace(/^[\s+(]+/, "").slice(0, 1).toUpperCase() || "#"
                    size: 16
                    font.weight: Font.DemiBold
                }
            }
            Column {
                anchors.left: avatar.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Item {
                    width: parent.width
                    height: convName.implicitHeight

                    Label {
                        id: convName

                        anchors.left: parent.left
                        anchors.right: convDate.left
                        anchors.rightMargin: 8
                        text: conv.modelData.name
                        size: 13
                        font.weight: conv.modelData.read ? Font.Normal : Font.Bold
                    }
                    Label {
                        id: convDate

                        anchors.right: parent.right
                        text: root.dateLabel(conv.modelData.date)
                        size: 11
                        color: Theme.muted
                    }
                }
                Label {
                    width: parent.width
                    text: (conv.modelData.sent ? Tr.t("You: ") : "") + conv.modelData.body.replace(/\s+/g, " ")
                    size: 12
                    color: conv.modelData.read ? Theme.muted : Theme.text
                }
            }
            MouseArea {
                id: convArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Phone.openThread(conv.modelData.thread);
                    Qt.callLater(() => replyField.focusField());
                }
            }
        }
    }

    // ---- one conversation ----
    Item {
        anchors.fill: parent
        visible: root.mode === "thread"

        ListView {
            id: bubbles

            anchors.top: parent.top
            anchors.bottom: replyRow.top
            anchors.bottomMargin: 8
            width: parent.width
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            verticalLayoutDirection: ListView.BottomToTop
            model: Phone.thread ? Phone.thread.messages.slice().reverse() : []

            Label {
                anchors.centerIn: parent
                visible: bubbles.count === 0
                text: Tr.t("Loading…")
                color: Theme.muted
                size: 12
            }

            delegate: Item {
                id: msg

                required property var modelData

                width: ListView.view.width
                height: bubble.height + 14

                Rectangle {
                    id: bubble

                    readonly property real maxWidth: msg.width * 0.78

                    x: msg.modelData.sent ? msg.width - width : 0
                    width: Math.min(maxWidth, Math.max(bodyText.implicitWidth, 40) + 24)
                    height: bodyText.implicitHeight + 18
                    radius: 18
                    color: msg.modelData.failed ? Qt.alpha(Theme.error, 0.3) : msg.modelData.sent ? Theme.accent : Qt.alpha(Theme.text, 0.09)

                    Label {
                        id: bodyText

                        x: 12
                        y: 9
                        width: bubble.maxWidth - 24
                        text: msg.modelData.body + (msg.modelData.attachments > 0 ? "  📎" : "")
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                        size: 13
                        color: msg.modelData.sent ? Theme.accentText : Theme.text
                    }
                }
                Label {
                    anchors.top: bubble.bottom
                    anchors.topMargin: 1
                    x: msg.modelData.sent ? msg.width - width - 6 : 6
                    text: root.dateLabel(msg.modelData.date) + (msg.modelData.failed ? " · " + Tr.t("not sent") : "")
                    size: 10
                    color: Theme.muted
                }
            }
        }

        Row {
            id: replyRow

            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 8

            PhoneField {
                id: replyField

                width: parent.width - 48
                placeholder: Tr.t("Message")
                onAccepted: replySend.clicked()
            }
            PhoneButton {
                id: replySend

                icon: "send"
                primary: true
                implicitWidth: 40
                implicitHeight: 40
                enabledButton: replyField.text.trim() !== ""
                onClicked: {
                    if (!Phone.thread || replyField.text.trim() === "")
                        return;
                    Phone.send("smsReply", {
                        thread: Phone.thread.thread,
                        text: replyField.text
                    });
                    replyField.text = "";
                }
            }
        }
    }

    // ---- new message ----
    Column {
        width: parent.width
        spacing: 10
        visible: root.mode === "new"

        PhoneField {
            id: numberField

            width: parent.width
            placeholder: Tr.t("Phone number")
            input.inputMethodHints: Qt.ImhDialableCharactersOnly
            onAccepted: newText.focusField()
        }
        PhoneField {
            id: newText

            width: parent.width
            placeholder: Tr.t("Message")
            onAccepted: newSend.clicked()
        }
        PhoneButton {
            id: newSend

            text: Tr.t("Send SMS")
            icon: "send"
            primary: true
            enabledButton: numberField.text.trim() !== "" && newText.text.trim() !== ""
            onClicked: {
                const numbers = numberField.text.split(/[,;]/).map(s => s.trim()).filter(s => s !== "");
                if (numbers.length === 0 || newText.text.trim() === "")
                    return;
                Phone.send("sms", {
                    addresses: numbers,
                    text: newText.text
                });
                Toasts.show(Tr.t("SMS sent"), numbers.join(", "), "message");
                numberField.text = "";
                newText.text = "";
                root.composing = false;
            }
        }
    }
}
