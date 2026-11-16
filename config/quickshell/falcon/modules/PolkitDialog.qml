import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// The password dialog of the shell's polkit agent: a glass card in the middle of a dimmed
// screen. Typed characters show as Material shapes, and a wrong password shakes the field.
PanelWindow {
    id: root

    readonly property var flow: Polkit.flow
    readonly property bool closing: !Polkit.active
    property real reveal: 0
    // Kept while the card closes, after the request is gone.
    property string message: ""
    property string prompt: ""
    property bool secret: true
    property string error: ""
    property bool waiting: false

    function submit() {
        if (!flow || !flow.isResponseRequired || waiting)
            return;
        waiting = true;
        error = "";
        Polkit.submit(field.text);
    }

    // The finger, beside the password: falcon-fingerd watches the sensor, and a match gives a
    // secret that the PAM line of polkit-1 takes instead of the password. Only for this user:
    // another identity (root) is asked for its own password.
    property string finger: ""    // "", "ready", "miss", "match"
    readonly property bool ownIdentity: {
        const id = flow ? flow.selectedIdentity : null;
        const text = id ? String(id.string || id.displayName || "") : "";
        const me = Quickshell.env("USER");
        return text === "" || text === "unix-user:" + me || text === me;
    }
    readonly property bool fingerWanted: !closing && !!flow && Fingerprint.polkitOn && ownIdentity

    onFingerWantedChanged: fingerScan.running = fingerWanted

    function fingerAnswer(secret) {
        if (!flow || !flow.isResponseRequired || waiting) {
            pendingSecret = secret;
            return;
        }
        waiting = true;
        error = "";
        field.text = "";
        Polkit.submit(secret);
    }
    property string pendingSecret: ""

    Process {
        id: fingerScan

        command: [Ui.binDir + "falcon-fingerprint", "scan"]
        stdout: SplitParser {
            onRead: line => {
                let e;
                try {
                    e = JSON.parse(line);
                } catch (err) {
                    return;
                }
                if (e.state === "scanning")
                    root.finger = root.finger === "miss" ? "miss" : "ready";
                else if (e.state === "nomatch") {
                    root.finger = "miss";
                    shakeAnimation.restart();
                    fingerCalm.restart();
                } else if (e.state === "match" && e.secret) {
                    root.finger = "match";
                    root.fingerAnswer(e.secret);
                }
            }
        }
        onExited: {
            if (root.finger !== "match")
                root.finger = "";
            // One match per scan: start again for a request that asks once more.
            if (root.fingerWanted)
                fingerRestart.restart();
        }
    }
    Timer {
        id: fingerRestart

        interval: 1200
        onTriggered: fingerScan.running = root.fingerWanted
    }
    Timer {
        id: fingerCalm

        interval: 1600
        onTriggered: {
            if (root.finger === "miss")
                root.finger = "ready";
        }
    }

    function cleanPrompt(text) {
        const t = (text || "").trim();
        return t.endsWith(":") ? t.slice(0, -1) : t;
    }

    onFlowChanged: {
        if (!flow)
            return;
        message = flow.message;
        error = "";
        waiting = false;
        field.text = "";
        finger = "";
        pendingSecret = "";
    }

    onClosingChanged: {
        revealAnimation.stop();
        if (closing) {
            revealAnimation.to = 0;
            revealAnimation.duration = 220;
            revealAnimation.easing.type = Easing.InCubic;
        } else {
            field.forceActiveFocus();
            revealAnimation.to = 1;
            revealAnimation.duration = 420;
            revealAnimation.easing.type = Easing.OutCubic;
        }
        revealAnimation.start();
    }

    Connections {
        target: root.flow

        function onIsResponseRequiredChanged() {
            if (!root.flow.isResponseRequired)
                return;
            root.waiting = false;
            root.prompt = root.cleanPrompt(root.flow.inputPrompt);
            root.secret = !root.flow.responseVisible;
            field.forceActiveFocus();
            if (root.pendingSecret !== "") {
                const secret = root.pendingSecret;
                root.pendingSecret = "";
                root.fingerAnswer(secret);
            }
        }
        function onAuthenticationFailed() {
            root.waiting = false;
            if (root.finger === "match")
                root.finger = "ready";
            root.error = Tr.t("Wrong password");
            field.text = "";
            shakeAnimation.restart();
        }
        function onSupplementaryMessageChanged() {
            if (root.flow.supplementaryIsError && root.flow.supplementaryMessage !== "")
                root.error = root.flow.supplementaryMessage;
        }
    }

    NumberAnimation {
        id: revealAnimation

        target: root
        property: "reveal"
        onFinished: {
            if (root.closing)
                Polkit.alive = false;
        }
    }

    visible: Polkit.alive
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "falcon-polkit"
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    BackgroundEffect.blurRegion: Region {
        item: card
        radius: card.radius
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.5 * root.reveal
    }
    // Clicks outside do nothing: the request is answered only with its buttons or keys.
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        id: card

        property real shake: 0

        width: 420
        height: column.implicitHeight + 56
        Behavior on height {
            enabled: root.reveal > 0.99
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
        x: Math.round((parent.width - width) / 2) + shake
        y: Math.round((parent.height - height) / 2 + (1 - root.reveal) * 24)
        opacity: root.reveal
        radius: 30
        border.width: 1
        border.color: Theme.panelEdge
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.glassBase, Math.max(0.72, Theme.glassOpacity))
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Theme.glassBase, Math.max(0.62, Theme.glassOpacity - 0.1))
            }
        }

        SequentialAnimation {
            id: shakeAnimation

            NumberAnimation { target: card; property: "shake"; to: -14; duration: 50; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "shake"; to: 11; duration: 70; easing.type: Easing.InOutQuad }
            NumberAnimation { target: card; property: "shake"; to: -7; duration: 70; easing.type: Easing.InOutQuad }
            NumberAnimation { target: card; property: "shake"; to: 3; duration: 60; easing.type: Easing.InOutQuad }
            NumberAnimation { target: card; property: "shake"; to: 0; duration: 60; easing.type: Easing.OutQuad }
        }

        Column {
            id: column

            x: 28
            y: 28
            width: parent.width - 56
            spacing: 14

            Item {
                width: parent.width
                height: 64

                MaterialShape {
                    anchors.centerIn: parent
                    width: 64
                    height: 64
                    kind: "cookie9"
                    color: Theme.accent
                    rotation: (1 - root.reveal) * -90
                }
                Icon {
                    anchors.centerIn: parent
                    name: "lock"
                    size: 26
                    color: Theme.accentText
                }
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Tr.t("Authentication required")
                size: 20
                font.weight: Font.DemiBold
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                text: root.message
                color: Theme.muted
                size: 13
            }
            Item {
                width: 1
                height: 2
            }
            Rectangle {
                width: parent.width
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
                    echoMode: root.secret ? TextInput.Password : TextInput.Normal
                    color: root.secret ? "transparent" : Theme.text
                    selectionColor: root.secret ? "transparent" : Qt.alpha(Theme.accent, 0.4)
                    selectedTextColor: root.secret ? "transparent" : Theme.text
                    cursorDelegate: root.secret ? hiddenCursor : null
                    font.family: Theme.sans
                    font.pixelSize: 14
                    enabled: !root.waiting
                    focus: true
                    onAccepted: root.submit()
                    onTextChanged: {
                        if (text !== "")
                            root.error = "";
                    }
                    Keys.onEscapePressed: Polkit.cancel()

                    Component {
                        id: hiddenCursor

                        Item {}
                    }
                }
                PasswordShapes {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.secret
                    count: field.length
                    color: root.error !== "" ? Theme.error : Theme.accent
                    dim: root.waiting
                }
                Label {
                    anchors.centerIn: parent
                    opacity: field.text === "" ? 1 : 0
                    scale: field.text === "" ? 1 : 0.92
                    visible: opacity > 0
                    text: root.waiting ? Tr.t("Checking…") : (root.prompt !== "" && !/^password$/i.test(root.prompt) ? root.prompt : Tr.t("Password"))
                    color: Theme.muted
                    size: 14

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.error
                color: Theme.error
                size: 13
                visible: text !== ""
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                visible: root.finger !== ""

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.finger === "match" ? "check" : "fingerprint"
                    size: 18
                    color: root.finger === "miss" ? Theme.error : Theme.accent

                    SequentialAnimation on opacity {
                        running: root.finger === "ready"
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.45; duration: 1100; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
                    }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.finger === "miss" ? Tr.t("Finger not recognized") : root.finger === "match" ? Tr.t("Finger recognized") : Tr.t("Touch the sensor or type the password")
                    color: root.finger === "miss" ? Theme.error : Theme.muted
                    size: 13
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 8

                Repeater {
                    model: [
                        { id: "cancel", text: Tr.t("Cancel") },
                        { id: "ok", text: Tr.t("Authenticate") }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool main: modelData.id === "ok"

                        width: Math.max(110, label.implicitWidth + 36)
                        height: 40
                        radius: 20
                        color: main ? Theme.accent : Qt.alpha(Theme.text, mouse.containsMouse ? 0.14 : 0.08)
                        opacity: main && (field.text === "" || root.waiting) ? 0.55 : 1

                        Label {
                            id: label

                            anchors.centerIn: parent
                            text: modelData.text
                            color: parent.main ? Theme.accentText : Theme.text
                            size: 14
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: mouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.main)
                                    root.submit();
                                else
                                    Polkit.cancel();
                            }
                        }
                    }
                }
            }
        }
    }
}
