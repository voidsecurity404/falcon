import QtQuick
import qs.components
import qs.services

// Top of the hand control page: on and off, the one time download, the camera with the hand drawn
// over it, the gestures, and calibration.
Column {
    id: root

    spacing: 16

    readonly property bool live: HandMouse.running && HandMouse.started
    readonly property var zone: Settings.get("handmouse.zone", ({}))
    readonly property bool toHand: Settings.get("handmouse.mode", "absolute") === "absolute"
    readonly property bool calibrationUsed: HandMouse.calibratedAt !== "" && Settings.get("handmouse.useCalibration", true)
    readonly property string shortcut: Settings.get("binds.handmouse", "")

    // The camera view is sent only while this page is on screen.
    Binding {
        target: HandMouse
        property: "previewWanted"
        value: root.visible && Ui.settingsOpen && HandMouse.enabled
    }

    component Button: Rectangle {
        id: button

        property string text
        property bool primary: false
        signal clicked

        width: buttonLabel.implicitWidth + 30
        height: 34
        radius: 11
        color: primary ? (buttonArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : (buttonArea.containsMouse ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.accent, 0.18))
        scale: buttonArea.pressed ? 0.96 : 1

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 110
            }
        }

        Label {
            id: buttonLabel

            anchors.centerIn: parent
            text: button.text
            size: 13
            font.weight: Font.Medium
            color: button.primary ? Theme.accentText : Theme.accent
        }
        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    Rectangle {
        width: root.width
        height: body.implicitHeight + 36
        radius: 18
        color: Qt.alpha(Theme.text, 0.045)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.06)

        Column {
            id: body

            x: 18
            y: 18
            width: parent.width - 36
            spacing: 16

            // Title, state and the switch
            Item {
                width: parent.width
                height: 46

                Rectangle {
                    id: badge

                    width: 46
                    height: 46
                    radius: 15
                    color: Qt.alpha(Theme.accent, HandMouse.enabled ? 0.28 : 0.14)

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "hand"
                        size: 23
                        color: Theme.accent
                    }
                }
                Column {
                    anchors.left: badge.right
                    anchors.leftMargin: 14
                    anchors.right: control.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Label {
                        text: Tr.t("Hand control")
                        size: 15
                        font.weight: Font.DemiBold
                    }
                    Label {
                        width: parent.width
                        elide: Text.ElideRight
                        text: HandMouse.stateText + (root.shortcut !== "" && HandMouse.ready ? "  ·  " + root.shortcut : "")
                        color: HandMouse.problem !== "" ? Theme.error : Theme.muted
                        size: 13
                    }
                }

                Item {
                    id: control

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: HandMouse.ready ? toggle.width : install.width
                    height: 36

                    Button {
                        id: install

                        visible: !HandMouse.ready && HandMouse.checked
                        anchors.verticalCenter: parent.verticalCenter
                        primary: true
                        opacity: HandMouse.installing ? 0.6 : 1
                        text: HandMouse.installing ? Tr.t("Installing…") : Tr.t("Download")
                        onClicked: HandMouse.install()
                    }

                    Rectangle {
                        id: toggle

                        visible: HandMouse.ready
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 26
                        radius: 13
                        color: HandMouse.enabled ? Theme.accent : Qt.alpha(Theme.text, 0.14)

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        Rectangle {
                            x: HandMouse.enabled ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: toggleArea.pressed ? 24 : 20
                            height: 20
                            radius: 10
                            color: HandMouse.enabled ? Theme.accentText : Theme.text

                            Behavior on x {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.3, 1.5, 0.4, 1, 1, 1]
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                        MouseArea {
                            id: toggleArea

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: HandMouse.toggle()
                        }
                    }
                }
            }

            // What the download is, or what is missing on this computer.
            Label {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                size: 13
                color: HandMouse.installError !== "" || !HandMouse.uinput || (HandMouse.checked && HandMouse.cameras.length === 0) ? Theme.error : Theme.muted
                text: {
                    if (HandMouse.installError !== "")
                        return Tr.t("The download failed: {error}").replace("{error}", HandMouse.installError);
                    if (HandMouse.installing) {
                        switch (HandMouse.installStep) {
                        case "python":
                            return Tr.t("Preparing Python…");
                        case "packages":
                            return Tr.t("Downloading MediaPipe and OpenCV, about 500 MB…");
                        case "model":
                            return Tr.t("Downloading the hand model…");
                        case "check":
                            return Tr.t("Checking…");
                        }
                        return "";
                    }
                    if (HandMouse.checked && HandMouse.cameras.length === 0)
                        return Tr.t("No camera was found.");
                    if (!HandMouse.uinput)
                        return Tr.t("The virtual mouse needs write access to /dev/uinput, which this system does not give.");
                    if (!HandMouse.ready && HandMouse.checked)
                        return Tr.t("The webcam watches one hand and the pointer follows it. It needs MediaPipe, OpenCV and a hand model, about 550 MB, downloaded once. Pictures stay on this computer.");
                    return "";
                }
            }

            // Camera with the hand, and the gestures beside it
            Row {
                visible: HandMouse.ready
                spacing: 20

                Rectangle {
                    id: view

                    width: 320
                    height: 240
                    radius: 14
                    color: Qt.alpha(Theme.text, 0.06)
                    clip: true

                    Image {
                        id: frame

                        anchors.fill: parent
                        visible: root.live && HandMouse.previewImage !== ""
                        source: visible ? "file://" + HandMouse.previewImage : ""
                        cache: false
                        asynchronous: false
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }

                    // The part of the picture that covers the screen.
                    Rectangle {
                        visible: frame.visible && root.toHand && !root.calibrationUsed
                        x: view.width * Number(root.zone.left ?? 0.2)
                        y: view.height * Number(root.zone.top ?? 0.15)
                        width: view.width * (Number(root.zone.right ?? 0.8) - Number(root.zone.left ?? 0.2))
                        height: view.height * (Number(root.zone.bottom ?? 0.75) - Number(root.zone.top ?? 0.15))
                        radius: 6
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.alpha("white", 0.55)
                    }

                    Canvas {
                        id: skeleton

                        readonly property var bones: [[0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [5, 6], [6, 7], [7, 8], [5, 9], [9, 10], [10, 11], [11, 12], [9, 13], [13, 14], [14, 15], [15, 16], [13, 17], [17, 18], [18, 19], [19, 20], [0, 17]]
                        readonly property var points: HandMouse.previewPoints

                        anchors.fill: parent
                        visible: frame.visible
                        onPointsChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const p = points;
                            if (!p || p.length < 21)
                                return;
                            ctx.lineWidth = 2.5;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = Qt.alpha(Theme.accent, 0.95);
                            ctx.beginPath();
                            for (const b of bones) {
                                ctx.moveTo(p[b[0]][0] * width, p[b[0]][1] * height);
                                ctx.lineTo(p[b[1]][0] * width, p[b[1]][1] * height);
                            }
                            ctx.stroke();
                            ctx.fillStyle = "white";
                            for (let i = 0; i < 21; i++) {
                                ctx.beginPath();
                                ctx.arc(p[i][0] * width, p[i][1] * height, i === 4 || i === 8 || i === 12 ? 4 : 2.6, 0, Math.PI * 2);
                                ctx.fill();
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: !frame.visible
                        spacing: 10
                        width: parent.width - 40

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "camera"
                            size: 26
                            color: Theme.muted
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: HandMouse.enabled ? Tr.t("Starting the camera…") : Tr.t("Turn hand control on to see the camera")
                            color: Theme.muted
                            size: 12
                        }
                    }

                    // Speed, at the bottom of the picture
                    Rectangle {
                        visible: frame.visible
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: speed.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: Qt.alpha("black", 0.5)

                        Label {
                            id: speed

                            anchors.centerIn: parent
                            text: Tr.t("{fps} fps · {ms} ms · CPU {cpu}%").replace("{fps}", Math.round(HandMouse.fps)).replace("{ms}", Math.round(HandMouse.latency)).replace("{cpu}", HandMouse.cpu) + (HandMouse.gpu ? " · GPU" : "")
                            color: "white"
                            size: 11
                        }
                    }
                }

                Column {
                    width: body.width - view.width - 20
                    spacing: 9

                    Label {
                        text: Tr.t("Gestures")
                        color: Theme.muted
                        size: 12
                        font.weight: Font.Medium
                    }
                    Repeater {
                        model: [
                            [Tr.t("Move the hand"), Tr.t("the pointer follows")],
                            [Tr.t("Tap thumb to index finger"), Tr.t("click, twice for a double click")],
                            [Tr.t("Hold thumb on index finger"), Tr.t("drag")],
                            [Tr.t("Tap thumb to middle finger"), Tr.t("right click")],
                            [Tr.t("Two fingers up, move up or down"), Tr.t("scroll")],
                            [Tr.t("Fist"), Tr.t("hold the pointer still")],
                            [Tr.t("Spread palm, hold still"), Tr.t("pause or resume")]
                        ].slice(0, Settings.get("handmouse.gestures.palmToggle", false) ? 7 : 6)

                        delegate: Label {
                            required property var modelData

                            width: parent.width
                            wrapMode: Text.WordWrap
                            size: 13
                            textFormat: Text.StyledText
                            text: "<b>" + modelData[0] + "</b> — " + modelData[1]
                        }
                    }
                }
            }

            // Calibration, which only the mode that goes to the hand uses.
            Item {
                visible: HandMouse.ready && root.toHand
                width: parent.width
                height: 36

                Label {
                    anchors.left: parent.left
                    anchors.right: calButtons.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    size: 13
                    color: Theme.muted
                    text: HandMouse.calibratedAt !== "" ? Tr.t("Calibrated on {date}").replace("{date}", HandMouse.calibratedAt) : Tr.t("Calibrate to reach the corners of the screen with less stretching")
                }
                Row {
                    id: calButtons

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Button {
                        visible: HandMouse.calibratedAt !== ""
                        text: Tr.t("Forget")
                        onClicked: HandMouse.forgetCalibration()
                    }
                    Button {
                        text: Tr.t("Calibrate")
                        primary: true
                        onClicked: HandMouse.calibrate()
                    }
                }
            }
        }
    }
}
