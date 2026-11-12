// Falcon's way out of the login screen, laid over the sddm-astronaut theme by falcon-login.
// Without it, Enter left the screen frozen while the password was checked and the session
// started, then it went black at once.
//
// Enter starts `leave` at once: the form floats up and fades, the picture swells, blurs and
// dims, and a ring turns in the middle. The password goes to SDDM a moment later, while that
// plays. A wrong one plays it all back and the theme shows its error; a right one fades the
// screen to black, which is where the Falcon session's cover fades in from.
import QtQuick 2.15
import QtQuick.Effects

Item {
    id: root

    // The theme's whole scene (background and form), the form and its Input column.
    property Item scene
    property Item form
    property Item input
    property color accent: config.LoginButtonBackgroundColor || config.HighlightBackgroundColor || "#ffffff"

    // 0 resting, 1 form gone and waiting, 2 black.
    property real leave: 0
    property var pending: null
    readonly property real away: Math.min(1, leave)
    readonly property real dark: Math.max(0, leave - 1)

    function ease(t) {
        return 1 - Math.pow(1 - Math.max(0, Math.min(1, t)), 3);
    }

    function start(user, secret, session) {
        if (pending)
            return;
        pending = { user: user, secret: secret, session: session };
        back.stop();
        outward.restart();
        send.restart();
    }

    anchors.fill: parent
    z: 1000

    Component.onCompleted: {
        if (input)
            input.falconHooked = true;
    }

    // Only while leaving: the theme keeps its own look otherwise.
    Binding {
        target: root.scene
        property: "scale"
        value: 1 + 0.045 * root.ease(root.away)
        when: root.scene !== null && root.leave > 0
    }
    Binding {
        target: root.scene
        property: "layer.enabled"
        value: true
        when: root.scene !== null && root.leave > 0
    }
    Binding {
        target: root.scene
        property: "layer.effect"
        value: blurEffect
        when: root.scene !== null && root.leave > 0
    }
    Binding {
        target: root.form
        property: "opacity"
        value: 1 - root.ease(root.away * 1.4)
        when: root.form !== null && root.leave > 0
    }

    Component {
        id: blurEffect

        MultiEffect {
            blurEnabled: true
            blur: 0.8 * root.ease(root.away)
            blurMax: 48
            brightness: -0.18 * root.ease(root.away)
            saturation: -0.2 * root.ease(root.away)
        }
    }

    Connections {
        target: root.input
        ignoreUnknownSignals: true

        function onFalconLogin(user, secret, session) {
            root.start(user, secret, session);
        }
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            outward.stop();
            toBlack.from = root.leave;
            toBlack.start();
        }
        function onLoginFailed() {
            send.stop();
            outward.stop();
            root.pending = null;
            back.from = root.leave;
            back.start();
        }
    }

    // The form is mostly gone by then, so a quick answer still looks like one movement.
    Timer {
        id: send

        interval: 240
        onTriggered: {
            const p = root.pending;
            if (p)
                sddm.login(p.user, p.secret, p.session);
        }
    }

    NumberAnimation {
        id: outward

        target: root
        property: "leave"
        to: 1
        duration: 560
        easing.type: Easing.Linear
    }
    NumberAnimation {
        id: toBlack

        target: root
        property: "leave"
        to: 2
        duration: 420
        easing.type: Easing.InOutQuad
    }
    NumberAnimation {
        id: back

        target: root
        property: "leave"
        to: 0
        duration: 520
        easing.type: Easing.OutCubic
    }

    // The form lifting: drawn by moving the whole form, so the theme's layout is untouched.
    Binding {
        target: root.form
        property: "transform"
        value: lift
        when: root.form !== null
    }
    Translate {
        id: lift

        y: -36 * root.ease(root.away)
    }

    // A ring turning in the middle while the session is being opened.
    Item {
        id: ring

        width: 64
        height: 64
        anchors.centerIn: parent
        opacity: root.ease((root.away - 0.35) / 0.65) * (1 - root.dark)
        scale: 0.7 + 0.3 * root.ease((root.away - 0.35) / 0.65)
        visible: opacity > 0

        Canvas {
            id: arc

            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.lineCap = "round";
                c.lineWidth = 4;
                c.strokeStyle = Qt.rgba(1, 1, 1, 0.18);
                c.beginPath();
                c.arc(32, 32, 26, 0, Math.PI * 2);
                c.stroke();
                c.strokeStyle = root.accent;
                c.beginPath();
                c.arc(32, 32, 26, -Math.PI / 2, Math.PI * 0.35);
                c.stroke();
            }
        }

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: ring.visible
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.ease(root.dark)
        visible: opacity > 0
    }
}
