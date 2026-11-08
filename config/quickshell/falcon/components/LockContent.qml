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
            id: box

            property real shake: 0

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: shake
            width: 300
            height: 46
            radius: 14
            color: Qt.alpha(Theme.surface, 0.75)
            border.width: 1
            border.color: root.error !== "" ? Theme.error : field.activeFocus ? Theme.accent : Theme.panelEdge

            SequentialAnimation {
                id: shakeAnimation

                NumberAnimation { target: box; property: "shake"; to: -12; duration: 50; easing.type: Easing.OutQuad }
                NumberAnimation { target: box; property: "shake"; to: 10; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: box; property: "shake"; to: -6; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: box; property: "shake"; to: 3; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: box; property: "shake"; to: 0; duration: 60; easing.type: Easing.OutQuad }
            }
            Connections {
                target: root

                function onErrorChanged() {
                    if (root.error !== "")
                        shakeAnimation.restart();
                }
            }

            // The typed characters are hidden and each shown as a Material shape instead.
            TextInput {
                id: field

                anchors.fill: parent
                anchors.margins: 12
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorDelegate: Item {}
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
            Item {
                anchors.fill: parent
                anchors.margins: 12
                clip: true

                Row {
                    id: shapes

                    // Centered, and once it is too long the newest shapes stay in view.
                    x: Math.min((parent.width - width) / 2, parent.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    opacity: root.checking ? 0.45 : 1

                    Behavior on x {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    Repeater {
                        model: field.length

                        delegate: MaterialShape {
                            id: shape

                            required property int index

                            width: 16
                            height: 16
                            kind: kinds[index % kinds.length]
                            color: root.error !== "" ? Theme.error : Theme.accent
                            // Shapes pushed out past the left edge fade instead of being cut.
                            opacity: x + shapes.x < 0 ? 0 : 1
                            scale: 0
                            rotation: -50
                            Component.onCompleted: {
                                scale = 1;
                                rotation = 0;
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2.4
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                }
                            }
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 320
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
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
