// Falcon's way out of the login screen, laid over the sddm-astronaut theme by falcon-login.
//
// SDDM stops the greeter about 0.2 s after it gets the password, so an animation running then
// is cut in the middle and looks frozen. So Enter first plays the whole way out: the form sinks
// back and fades while the picture slowly swells and the screen fades to black. Only then does
// the password go to SDDM, and the greeter ends on a black screen, which is how niri starts and
// where the session's wallpaper and cover fade in. A wrong password fades everything back.
//
// Every moving property is driven by an Animator, which runs on the render thread, so the
// animated background or a busy start cannot stall it, and nothing is blurred, which was too
// slow for the X11 greeter on this GPU.
import QtQuick 2.15

Item {
    id: root

    // The theme's whole scene (background and form), the form and its Input column.
    property Item scene
    property Item form
    property Item input

    property var pending: null
    readonly property int outTime: 420

    function start(user, secret, session) {
        if (pending)
            return;
        pending = { user: user, secret: secret, session: session };
        comeBack.stop();
        goAway.restart();
    }

    anchors.fill: parent
    z: 1000

    Component.onCompleted: {
        if (input)
            input.falconHooked = true;
    }

    ParallelAnimation {
        id: goAway

        OpacityAnimator {
            target: root.form
            to: 0
            duration: root.outTime * 0.6
            easing.type: Easing.InCubic
        }
        ScaleAnimator {
            target: root.form
            to: 0.94
            duration: root.outTime * 0.6
            easing.type: Easing.InCubic
        }
        ScaleAnimator {
            target: root.scene
            to: 1.05
            duration: root.outTime
            easing.type: Easing.InOutSine
        }
        OpacityAnimator {
            target: black
            to: 1
            duration: root.outTime
            easing.type: Easing.InOutSine
        }

        onFinished: {
            const p = root.pending;
            if (p) {
                sddm.login(p.user, p.secret, p.session);
                slow.restart();
            }
        }
    }

    ParallelAnimation {
        id: comeBack

        OpacityAnimator {
            target: ring
            to: 0
            duration: 200
        }
        OpacityAnimator {
            target: black
            to: 0
            duration: 380
            easing.type: Easing.OutCubic
        }
        ScaleAnimator {
            target: root.scene
            to: 1
            duration: 420
            easing.type: Easing.OutCubic
        }
        OpacityAnimator {
            target: root.form
            to: 1
            duration: 420
            easing.type: Easing.OutCubic
        }
        ScaleAnimator {
            target: root.form
            to: 1
            duration: 460
            easing.type: Easing.OutBack
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

        // The greeter is stopped right after this, on the black screen.
        function onLoginSucceeded() {}
        function onLoginFailed() {
            root.pending = null;
            slow.stop();
            goAway.stop();
            comeBack.restart();
        }
    }

    Rectangle {
        id: black

        anchors.fill: parent
        color: "black"
        opacity: 0
    }

    // Only when the answer is slow (a wrong password waits about 2 s in PAM), so the black
    // screen never sits still.
    Timer {
        id: slow

        interval: 550
        onTriggered: ringIn.restart()
    }
    OpacityAnimator {
        id: ringIn

        target: ring
        to: 0.85
        duration: 300
    }
    Item {
        id: ring

        width: 44
        height: 44
        anchors.centerIn: parent
        opacity: 0

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: Qt.rgba(1, 1, 1, 0.16)
        }
        // A quarter of the ring, cut from a full circle by a clipping box.
        Item {
            width: parent.width / 2
            height: parent.height / 2
            clip: true

            Rectangle {
                width: ring.width
                height: ring.height
                radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: "white"
            }
        }

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: ring.opacity > 0 || ringIn.running
        }
    }
}
