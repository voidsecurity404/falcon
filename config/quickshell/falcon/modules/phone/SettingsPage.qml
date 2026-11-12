import QtQuick
import qs.components
import qs.services

// The phone's connection: which phone, this computer's name, every KDE Connect feature on or
// off, and unpairing.
PhonePage {
    id: root

    readonly property var dev: Phone.device
    property bool unpairArmed: false
    readonly property var features: [
        {
            plugin: "notifications",
            name: Tr.t("Phone notifications here")
        },
        {
            plugin: "sendnotifications",
            name: Tr.t("This computer's notifications on the phone")
        },
        {
            plugin: "clipboard",
            name: Tr.t("Shared clipboard")
        },
        {
            plugin: "battery",
            name: Tr.t("Phone battery")
        },
        {
            plugin: "sms",
            name: Tr.t("Messages")
        },
        {
            plugin: "telephony",
            name: Tr.t("Calls shown here")
        },
        {
            plugin: "pausemusic",
            name: Tr.t("Pause music during calls")
        },
        {
            plugin: "mprisremote",
            name: Tr.t("Control the phone's player")
        },
        {
            plugin: "mpriscontrol",
            name: Tr.t("Phone controls this computer's player")
        },
        {
            plugin: "share",
            name: Tr.t("Send and receive files")
        },
        {
            plugin: "sftp",
            name: Tr.t("Browse the phone's files")
        },
        {
            plugin: "findmyphone",
            name: Tr.t("Ring the phone")
        },
        {
            plugin: "findthisdevice",
            name: Tr.t("Phone can ring this computer")
        },
        {
            plugin: "remotecontrol",
            name: Tr.t("Remote input to the phone")
        },
        {
            plugin: "mousepad",
            name: Tr.t("Phone as touchpad and keyboard here")
        },
        {
            plugin: "presenter",
            name: Tr.t("Phone as a presentation remote")
        },
        {
            plugin: "systemvolume",
            name: Tr.t("Phone controls this computer's volume")
        },
        {
            plugin: "runcommand",
            name: Tr.t("Commands from the phone")
        },
        {
            plugin: "contacts",
            name: Tr.t("Contact names")
        },
        {
            plugin: "ping",
            name: Tr.t("Ping")
        },
        {
            plugin: "lockdevice",
            name: Tr.t("Lock from the phone")
        }
    ].filter(f => dev && dev.supported.includes("kdeconnect_" + f.plugin))

    title: Tr.t("Settings")
    subtitle: dev ? dev.name : ""

    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.unpairArmed = false
    }

    Flickable {
        anchors.fill: parent
        contentHeight: body.height + 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body

            width: parent.width
            spacing: 8

            // The phone and how it is reached.
            Rectangle {
                width: parent.width
                height: info.height + 24
                radius: 18
                color: Qt.alpha(Theme.text, 0.06)
                visible: !!root.dev

                Column {
                    id: info

                    x: 14
                    y: 12
                    width: parent.width - 28
                    spacing: 3

                    Label {
                        text: root.dev ? root.dev.name : ""
                        size: 14
                        font.weight: Font.Medium
                    }
                    Label {
                        width: parent.width
                        text: !root.dev ? "" : !root.dev.reachable ? Tr.t("Out of reach") : root.dev.usb ? Tr.t("Connected by USB") : Tr.t("Connected over Wi-Fi") + (root.dev.addresses.length ? " · " + root.dev.addresses.join(", ") : "")
                        size: 11
                        color: Theme.muted
                    }
                    Label {
                        text: root.dev ? Tr.t("Security code") + ": " + root.dev.verificationKey : ""
                        font.family: Theme.mono
                        size: 11
                        color: Theme.muted
                    }
                }
            }

            // Other phones, when there are several.
            Repeater {
                model: Phone.devices.filter(d => d.paired && (!root.dev || d.id !== root.dev.id))

                delegate: PhoneButton {
                    required property var modelData

                    width: body.width
                    text: Tr.t("Switch to {name}").replace("{name}", modelData.name)
                    icon: "phone"
                    onClicked: Phone.chosenId = modelData.id
                }
            }

            Label {
                topPadding: 6
                text: Tr.t("This computer's name on the phone")
                size: 12
                color: Theme.muted
            }
            Row {
                width: parent.width
                spacing: 8

                PhoneField {
                    id: nameField

                    width: parent.width - 48
                    placeholder: Phone.pcName
                    onAccepted: renameButton.clicked()
                }
                PhoneButton {
                    id: renameButton

                    icon: "check"
                    implicitWidth: 40
                    implicitHeight: 40
                    primary: true
                    enabledButton: nameField.text.trim() !== ""
                    onClicked: {
                        if (nameField.text.trim() === "")
                            return;
                        Phone.send("rename", {
                            name: nameField.text.trim()
                        });
                        nameField.text = "";
                    }
                }
            }

            Label {
                topPadding: 6
                visible: root.features.length > 0
                text: Tr.t("Features")
                size: 12
                color: Theme.muted
            }
            Repeater {
                model: root.features

                delegate: Rectangle {
                    id: feature

                    required property var modelData
                    readonly property bool on: root.dev && root.dev.plugins.includes("kdeconnect_" + modelData.plugin)

                    width: body.width
                    height: 46
                    radius: 14
                    color: Qt.alpha(Theme.text, featureArea.containsMouse ? 0.08 : 0.04)

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: toggle.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: feature.modelData.name
                        size: 12
                    }
                    Rectangle {
                        id: toggle

                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 22
                        radius: 11
                        color: feature.on ? Theme.accent : Qt.alpha(Theme.text, 0.18)

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }
                        }

                        Rectangle {
                            x: feature.on ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: feature.on ? Theme.accentText : Theme.text

                            Behavior on x {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: featureArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Phone.send("plugin", {
                            plugin: "kdeconnect_" + feature.modelData.plugin,
                            enabled: !feature.on
                        })
                    }
                }
            }

            Item {
                width: 1
                height: 6
            }
            PhoneButton {
                width: parent.width
                visible: !!root.dev && root.dev.paired
                danger: true
                icon: "close"
                text: root.unpairArmed ? Tr.t("Press again to unpair") : Tr.t("Unpair this phone")
                onClicked: {
                    if (!root.unpairArmed) {
                        root.unpairArmed = true;
                        disarm.restart();
                        return;
                    }
                    root.unpairArmed = false;
                    Phone.send("unpair");
                    Ui.phonePage = "";
                }
            }
        }
    }
}
