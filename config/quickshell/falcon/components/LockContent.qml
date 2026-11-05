import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pam
import qs.services

// What the lock screen shows: the blurred wallpaper, the clock and the password field.
Item {
    id: root

    property bool preview: false
    property string error: ""
    property bool checking: false

    function submit() {
        if (preview) {
            Lock.preview = false;
            return;
        }
        if (field.text === "" || checking)
            return;
        checking = true;
        error = "";
        pam.start();
    }

    function focusField() {
        field.forceActiveFocus();
    }

    PamContext {
        id: pam

        config: "hyprlock"
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(field.text);
                field.text = "";
            }
        }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success)
                Lock.unlock();
            else
                root.error = Tr.t("Wrong password");
        }
        onError: {
            root.checking = false;
            root.error = Tr.t("Could not check the password");
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }
    Image {
        id: wallpaper

        // Larger than the screen, so the blur does not darken the edges.
        anchors.fill: parent
        anchors.margins: -60
        source: "file://" + Quickshell.env("HOME") + "/.local/state/falcon/wallpaper"
        sourceSize: Qt.size(960, 540)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.12
    }

    Column {
        anchors.centerIn: parent
        spacing: 12

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "hh:mm")
            size: 118
            font.weight: Font.Medium
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "dd.MM.yyyy")
            color: Theme.muted
            size: 22
        }
        Item {
            width: 1
            height: 28
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 46
            radius: 14
            color: Qt.alpha(Theme.surface, 0.75)
            border.width: 1
            border.color: root.error !== "" ? Theme.error : field.activeFocus ? Theme.accent : Theme.panelEdge

            TextInput {
                id: field

                anchors.fill: parent
                anchors.margins: 12
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: 14
                enabled: !root.checking
                focus: true
                onAccepted: root.submit()
                onTextChanged: {
                    if (text !== "")
                        root.error = "";
                }
                Keys.onEscapePressed: {
                    if (root.preview)
                        Lock.preview = false;
                    else
                        text = "";
                }
            }
            Label {
                anchors.centerIn: parent
                visible: field.text === ""
                text: root.checking ? Tr.t("Checking…") : Tr.t("Password")
                color: Theme.muted
                size: 14
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.error !== "" ? root.error : Niri.layoutLabel
            color: root.error !== "" ? Theme.error : Theme.muted
            size: 13
        }
    }
}
