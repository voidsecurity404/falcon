import QtQuick
import qs.components
import qs.services

// Files both ways: send files from here (chooser or dropped on the card), open the phone's
// storage in the file manager, send a piece of text or a link.
PhonePage {
    id: root

    title: Tr.t("Files")
    subtitle: Phone.device ? Phone.device.name : ""

    Column {
        width: parent.width
        spacing: 12

        // Drop files here, or click to choose them.
        Rectangle {
            id: dropCard

            width: parent.width
            height: 150
            radius: 22
            color: drop.containsDrag ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.text, sendArea.containsMouse ? 0.09 : 0.06)
            border.width: 1.5
            border.color: drop.containsDrag ? Theme.accent : Qt.alpha(Theme.text, 0.12)

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 54
                    height: 54
                    radius: 18
                    color: Theme.accent

                    Icon {
                        anchors.centerIn: parent
                        name: "upload"
                        size: 24
                        color: Theme.accentText
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("Send files to the phone")
                    size: 14
                    font.weight: Font.Medium
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("Click to choose, or drop them here")
                    size: 11
                    color: Theme.muted
                }
            }
            MouseArea {
                id: sendArea

                objectName: "phoneSendFiles"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Ui.popup = "";
                    Phone.pickFiles();
                }
            }
            DropArea {
                id: drop

                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: d => {
                    const paths = d.urls.map(u => String(u));
                    Phone.shareFiles(paths);
                }
            }
        }

        // The phone's storage, mounted over sshfs and opened in the file manager.
        Rectangle {
            width: parent.width
            height: 64
            radius: 20
            color: Qt.alpha(Theme.text, browseArea.containsMouse ? 0.1 : 0.06)
            visible: Phone.has("sftp")

            Rectangle {
                id: browseIcon

                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 14
                color: Qt.alpha(Theme.accent, 0.2)

                Icon {
                    anchors.centerIn: parent
                    name: "folder"
                    size: 20
                    color: Theme.accent
                }
            }
            Column {
                anchors.left: browseIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    text: Tr.t("Browse the phone")
                    size: 13
                    font.weight: Font.Medium
                }
                Label {
                    width: parent.width
                    text: Phone.device && Phone.device.sftp && Phone.device.sftp.mounted ? Tr.t("Open in the file manager") : Tr.t("Photos, downloads and the rest of its storage")
                    size: 11
                    color: Theme.muted
                }
            }
            MouseArea {
                id: browseArea

                objectName: "phoneBrowse"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Ui.popup = "";
                    Phone.browse();
                }
            }
        }

        // Text or a link: a link opens on the phone, text lands in its clipboard.
        Label {
            topPadding: 6
            text: Tr.t("Text or link")
            size: 12
            color: Theme.muted
        }
        PhoneField {
            id: textField

            width: parent.width
            placeholder: Tr.t("Type or paste, then Enter")
            onAccepted: send.clicked()
        }
        Row {
            spacing: 8

            PhoneButton {
                id: send

                text: /^(https?:\/\/|www\.)\S+$/i.test(textField.text.trim()) ? Tr.t("Open on the phone") : Tr.t("Send text")
                icon: "send"
                primary: true
                enabledButton: textField.text.trim() !== ""
                onClicked: {
                    const t = textField.text.trim();
                    if (t === "")
                        return;
                    if (/^(https?:\/\/|www\.)\S+$/i.test(t))
                        Phone.send("shareUrl", {
                            url: t.startsWith("www.") ? "https://" + t : t
                        });
                    else
                        Phone.shareText(t);
                    Toasts.show(Tr.t("Sent to the phone"), t, "send");
                    textField.text = "";
                }
            }
            PhoneButton {
                text: Tr.t("Clipboard")
                icon: "copy"
                visible: Phone.has("clipboard")
                onClicked: Phone.sendClipboard()
            }
        }
    }
}
