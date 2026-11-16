import QtQuick
import qs.components
import qs.services

// Top of the Fingerprint page: the sensor, the fingers added, adding one with a live ring of
// progress, and the one time setup for the login screen and the password dialog.
Column {
    id: root

    property bool choosing: false
    property string armed: ""

    readonly property bool busy: Fingerprint.enrolling !== ""
    readonly property real progress: Fingerprint.enrollStages > 0 ? Fingerprint.enrollDone / Fingerprint.enrollStages : 0
    readonly property bool success: Fingerprint.justAdded !== "" && !busy

    spacing: 12

    onVisibleChanged: {
        if (visible)
            Fingerprint.refresh();
        else {
            choosing = false;
            armed = "";
        }
    }

    Timer {
        id: disarm

        interval: 3500
        onTriggered: root.armed = ""
    }
    Timer {
        id: clearSuccess

        interval: 2600
        onTriggered: Fingerprint.justAdded = ""
    }
    Connections {
        target: Fingerprint

        function onJustAddedChanged() {
            if (Fingerprint.justAdded !== "")
                clearSuccess.restart();
        }
    }

    // The sensor card.
    Rectangle {
        width: root.width
        height: Math.max(176, info.implicitHeight + 40)
        radius: 18
        color: Qt.alpha(root.success ? Theme.accent : Theme.text, root.success ? 0.14 : 0.05)

        Behavior on color {
            ColorAnimation {
                duration: 300
            }
        }

        Item {
            id: badge

            x: 22
            anchors.verticalCenter: parent.verticalCenter
            width: 132
            height: 132

            // A soft pulse while it waits for a touch.
            Rectangle {
                anchors.centerIn: parent
                width: 104
                height: 104
                radius: width / 2
                color: Theme.accent
                opacity: 0
                visible: root.busy

                SequentialAnimation on scale {
                    running: root.busy
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.8; to: 1.25; duration: 1300; easing.type: Easing.OutCubic }
                }
                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.28; to: 0; duration: 1300; easing.type: Easing.OutCubic }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 104
                height: 104
                radius: width / 2
                color: root.busy || root.success ? Qt.alpha(Theme.accent, 0.2) : Qt.alpha(Theme.text, 0.07)

                Behavior on color {
                    ColorAnimation {
                        duration: 250
                    }
                }
            }
            Ring {
                anchors.fill: parent
                thickness: 7
                value: root.success ? 1 : root.progress
                visible: root.busy || root.success
                color: Fingerprint.enrollError !== "" ? Theme.error : Theme.accent
            }
            Icon {
                anchors.centerIn: parent
                name: root.success ? "check" : "fingerprint"
                size: 54
                color: Fingerprint.enrollError !== "" ? Theme.error : root.busy || root.success || Fingerprint.hasPrints ? Theme.accent : Theme.muted
                scale: root.success ? 1.08 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                    }
                }
            }
        }

        Column {
            id: info

            anchors.left: badge.right
            anchors.leftMargin: 22
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Label {
                width: parent.width
                text: {
                    if (!Fingerprint.known)
                        return Tr.t("Looking for the sensor…");
                    if (!Fingerprint.hasSensor)
                        return Tr.t("No fingerprint sensor found");
                    if (root.busy)
                        return Tr.t("Adding: {finger}").replace("{finger}", Fingerprint.nameOf(Fingerprint.enrolling));
                    if (root.success)
                        return Tr.t("Added: {finger}").replace("{finger}", Fingerprint.nameOf(Fingerprint.justAdded));
                    return Fingerprint.device;
                }
                size: 17
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Fingerprint.enrollError !== "" ? Theme.error : Theme.muted
                size: 13
                text: {
                    if (Fingerprint.enrollError !== "")
                        return Fingerprint.enrollError;
                    if (root.busy) {
                        if (Fingerprint.enrollNote !== "")
                            return Fingerprint.enrollNote;
                        if (Fingerprint.enrollDone === 0)
                            return Tr.t("Touch the sensor, lift, and touch again. It may ask for your password first.");
                        return Tr.t("Again: {done} of {all}. Move the finger a little each time.").replace("{done}", Fingerprint.enrollDone).replace("{all}", Fingerprint.enrollStages);
                    }
                    if (!Fingerprint.hasSensor)
                        return Tr.t("This computer has no sensor fprintd can use.");
                    if (!Fingerprint.hasPrints)
                        return Tr.t("Add a finger to unlock, log in and confirm with a touch. The password always works too.");
                    return Fingerprint.fingers.length === 1 ? Tr.t("1 finger added. A second one helps when the first is wet or hurt.") : Tr.t("{n} fingers added").replace("{n}", Fingerprint.fingers.length);
                }
            }
            Row {
                spacing: 8
                visible: Fingerprint.hasSensor
                topPadding: 4

                PillButton {
                    main: !root.busy
                    text: root.busy ? Tr.t("Cancel") : Tr.t("Add a finger")
                    icon: root.busy ? "" : "plus"
                    enabled: !Fingerprint.removing
                    onClicked: {
                        if (root.busy)
                            Fingerprint.cancelEnroll();
                        else
                            root.choosing = !root.choosing;
                    }
                }
            }
        }
    }

    // Which finger to add.
    Rectangle {
        width: root.width
        height: choice.implicitHeight + 32
        radius: 18
        color: Qt.alpha(Theme.text, 0.05)
        visible: root.choosing && !root.busy
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Column {
            id: choice

            x: 18
            y: 16
            width: parent.width - 36
            spacing: 10

            Label {
                text: Tr.t("Which finger?")
                size: 14
                font.weight: Font.DemiBold
            }
            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: Fingerprint.allFingers.filter(f => Fingerprint.fingers.indexOf(f) < 0)

                    delegate: PillButton {
                        required property string modelData

                        text: Fingerprint.nameOf(modelData)
                        onClicked: {
                            root.choosing = false;
                            Fingerprint.enroll(modelData);
                        }
                    }
                }
            }
        }
    }

    // Fingers added.
    Rectangle {
        width: root.width
        height: added.implicitHeight + 32
        radius: 18
        color: Qt.alpha(Theme.text, 0.05)
        visible: Fingerprint.hasPrints

        Column {
            id: added

            x: 18
            y: 16
            width: parent.width - 36
            spacing: 10

            Label {
                text: Tr.t("Fingers")
                size: 14
                font.weight: Font.DemiBold
            }
            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: Fingerprint.fingers

                    delegate: Rectangle {
                        id: chip

                        required property string modelData
                        readonly property bool isArmed: root.armed === modelData

                        width: chipRow.implicitWidth + 24
                        height: 38
                        radius: 19
                        color: isArmed ? Qt.alpha(Theme.error, 0.18) : Qt.alpha(Theme.accent, 0.14)

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: 8

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "fingerprint"
                                size: 16
                                color: chip.isArmed ? Theme.error : Theme.accent
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.isArmed ? Tr.t("Remove? Press again") : Fingerprint.nameOf(chip.modelData)
                                color: chip.isArmed ? Theme.error : Theme.text
                                size: 13
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22
                                radius: 11
                                color: removeArea.containsMouse ? Qt.alpha(Theme.error, 0.25) : "transparent"

                                Icon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 12
                                    color: chip.isArmed ? Theme.error : Theme.muted
                                }
                                MouseArea {
                                    id: removeArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !Fingerprint.removing && !root.busy
                                    onClicked: {
                                        if (chip.isArmed) {
                                            root.armed = "";
                                            Fingerprint.remove(chip.modelData);
                                        } else {
                                            root.armed = chip.modelData;
                                            disarm.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // The one time setup for the login screen and the password dialog.
    Rectangle {
        width: root.width
        height: setupBody.implicitHeight + 28
        radius: 18
        visible: Fingerprint.hasSensor && Fingerprint.known
        color: Qt.alpha(Fingerprint.needsSetup ? Theme.accent : Theme.text, Fingerprint.needsSetup ? 0.14 : 0.05)

        Row {
            id: setupBody

            x: 16
            y: 14
            width: parent.width - 32
            spacing: 14

            Rectangle {
                width: 38
                height: 38
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Fingerprint.needsSetup ? Theme.accent : Qt.alpha(Theme.good, 0.2)

                Icon {
                    anchors.centerIn: parent
                    name: Fingerprint.needsSetup ? "lock" : "check"
                    size: 18
                    color: Fingerprint.needsSetup ? Theme.accentText : Theme.good
                }
            }
            Column {
                width: setupBody.width - 52 - (setupButton.visible ? setupButton.width + 14 : 0)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Label {
                    width: parent.width
                    text: Fingerprint.needsSetup ? Tr.t("Login screen and password dialogs") : Tr.t("Ready everywhere")
                    size: 14
                    font.weight: Font.DemiBold
                }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Theme.muted
                    size: 12
                    text: Fingerprint.needsSetup ? Tr.t("The lock screen already takes a finger. The login screen and password dialogs need a one time setup with your password.") : Tr.t("Lock screen, login screen and password dialogs take a finger or the password, whichever comes first.")
                }
            }
            PillButton {
                id: setupButton

                anchors.verticalCenter: parent.verticalCenter
                visible: Fingerprint.needsSetup
                main: true
                text: Tr.t("Set up")
                onClicked: Fingerprint.runSetup()
            }
        }
    }

    component PillButton: Rectangle {
        id: pill

        property string text
        property string icon: ""
        property bool main: false
        signal clicked

        width: pillRow.implicitWidth + 30
        height: 36
        radius: 18
        opacity: enabled ? 1 : 0.5
        color: main ? (pillArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : Qt.alpha(Theme.text, pillArea.containsMouse ? 0.14 : 0.08)

        Row {
            id: pillRow

            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.icon !== ""
                name: pill.icon
                size: 15
                color: pill.main ? Theme.accentText : Theme.text
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.text
                color: pill.main ? Theme.accentText : Theme.text
                size: 13
                font.weight: Font.Medium
            }
        }
        MouseArea {
            id: pillArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: pill.enabled
            onClicked: pill.clicked()
        }
    }
}
