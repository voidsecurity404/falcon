import QtQuick
import qs.components
import qs.services

// Commands both ways: the ones the phone offers to run from here, and the ones this computer
// offers to the phone (KDE Connect's Run command: they show in the phone app).
PhonePage {
    id: root

    readonly property var phoneCommands: Phone.device && Phone.device.phoneCommands ? Object.keys(Phone.device.phoneCommands).map(k => Object.assign({
                key: k
            }, Phone.device.phoneCommands[k])) : []
    readonly property var pcCommands: Phone.device && Phone.device.pcCommands ? Phone.device.pcCommands : ({})
    readonly property var pcList: Object.keys(pcCommands).map(k => ({
                key: k,
                name: pcCommands[k].name,
                command: pcCommands[k].command
            }))

    function save(next) {
        Phone.send("pcCommands", {
            commands: next
        });
    }

    title: Tr.t("Commands")
    subtitle: Tr.t("Run on the phone, or let the phone run them here")

    Flickable {
        anchors.fill: parent
        contentHeight: body.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body

            width: parent.width
            spacing: 10

            Label {
                visible: root.phoneCommands.length > 0
                text: Tr.t("On the phone")
                size: 12
                color: Theme.muted
            }
            Repeater {
                model: root.phoneCommands

                delegate: PhoneButton {
                    required property var modelData

                    width: body.width
                    implicitHeight: 46
                    text: modelData.name
                    icon: "terminal"
                    onClicked: Phone.send("phoneCommand", {
                        key: modelData.key
                    })
                }
            }

            Label {
                text: Tr.t("The phone can run on this computer")
                size: 12
                color: Theme.muted
            }
            Label {
                width: parent.width
                visible: root.pcList.length === 0
                text: Tr.t("Nothing yet. Add a command, then press it in the KDE Connect app on the phone (Run command).")
                wrapMode: Text.Wrap
                size: 12
                color: Qt.alpha(Theme.text, 0.5)
            }
            Repeater {
                model: root.pcList

                delegate: Rectangle {
                    id: cmd

                    required property var modelData

                    width: body.width
                    height: 56
                    radius: 16
                    color: Qt.alpha(Theme.text, 0.06)

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: removeButton.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            width: parent.width
                            text: cmd.modelData.name
                            size: 13
                            font.weight: Font.Medium
                        }
                        Label {
                            width: parent.width
                            text: cmd.modelData.command
                            font.family: Theme.mono
                            size: 11
                            color: Theme.muted
                        }
                    }
                    PhoneButton {
                        id: removeButton

                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        implicitWidth: 34
                        implicitHeight: 34
                        danger: true
                        onClicked: {
                            const next = Object.assign({}, root.pcCommands);
                            delete next[cmd.modelData.key];
                            root.save(next);
                        }
                    }
                }
            }

            Label {
                topPadding: 8
                text: Tr.t("Add a command")
                size: 12
                color: Theme.muted
            }
            PhoneField {
                id: nameField

                width: parent.width
                placeholder: Tr.t("Name, e.g. Lock the screen")
                onAccepted: commandField.focusField()
            }
            PhoneField {
                id: commandField

                width: parent.width
                placeholder: Tr.t("Command, e.g. loginctl lock-session")
                input.font.family: Theme.mono
                onAccepted: addButton.clicked()
            }
            PhoneButton {
                id: addButton

                text: Tr.t("Add")
                icon: "plus"
                primary: true
                enabledButton: nameField.text.trim() !== "" && commandField.text.trim() !== ""
                onClicked: {
                    if (nameField.text.trim() === "" || commandField.text.trim() === "")
                        return;
                    const next = Object.assign({}, root.pcCommands);
                    const key = "falcon" + Date.now().toString(36);
                    next[key] = {
                        name: nameField.text.trim(),
                        command: commandField.text.trim()
                    };
                    root.save(next);
                    nameField.text = "";
                    commandField.text = "";
                }
            }
        }
    }
}
