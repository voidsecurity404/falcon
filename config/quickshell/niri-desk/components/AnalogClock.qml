import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services

// A watch face: dial, date window, baton hands and a sweeping second hand with a lit trail.
Item {
    id: root

    readonly property real radius: Math.min(width, height) / 2
    readonly property real outer: radius - 6
    property real seconds: 0
    property int wholeSecond: 0
    property real minutes: 0
    property real hours: 0
    property string digital: ""
    property int day: 1
    property real intro: 0

    function tick() {
        const now = new Date();
        seconds = now.getSeconds() + now.getMilliseconds() / 1000;
        if (now.getSeconds() !== wholeSecond || digital === "") {
            wholeSecond = now.getSeconds();
            minutes = now.getMinutes() + wholeSecond / 60;
            hours = (now.getHours() % 12) + minutes / 60;
            digital = Ui.pad(now.getHours()) + ":" + Ui.pad(now.getMinutes());
            day = now.getDate();
        }
    }

    function replay() {
        tick();
        wake.restart();
    }

    Component.onCompleted: replay()
    onVisibleChanged: {
        if (visible)
            replay();
    }

    FrameAnimation {
        running: root.visible
        onTriggered: root.tick()
    }

    // The hands wind up to the current time each time the page appears.
    NumberAnimation {
        id: wake

        target: root
        property: "intro"
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.OutBack
        easing.overshoot: 0.9
    }

    Connections {
        target: Theme
        function onAccentChanged() {
            dial.requestPaint();
            trail.requestPaint();
        }
    }

    // Dial: a soft glow around it, a dark glass disc and a rim lit from above.
    Canvas {
        id: dial

        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.outer <= 0)
                return;
            const c = root.radius;
            const r = root.outer;
            const glow = ctx.createRadialGradient(c, c, r * 0.8, c, c, c);
            glow.addColorStop(0, Qt.alpha(Theme.accent, 0.2));
            glow.addColorStop(1, Qt.alpha(Theme.accent, 0));
            ctx.fillStyle = glow;
            ctx.fillRect(0, 0, width, height);

            const face = ctx.createRadialGradient(c, c * 0.72, 0, c, c, r);
            face.addColorStop(0, Qt.alpha(Qt.tint(Theme.pill, Qt.alpha(Theme.accent, 0.2)), 0.72));
            face.addColorStop(0.75, Qt.alpha(Qt.tint(Theme.pill, Qt.alpha(Theme.accent, 0.06)), 0.82));
            face.addColorStop(1, Qt.alpha(Theme.pill, 0.94));
            ctx.beginPath();
            ctx.arc(c, c, r, 0, Math.PI * 2);
            ctx.fillStyle = face;
            ctx.fill();

            const rim = ctx.createLinearGradient(0, c - r, 0, c + r);
            rim.addColorStop(0, Qt.alpha(Theme.text, 0.55));
            rim.addColorStop(0.45, Qt.alpha(Theme.text, 0.1));
            rim.addColorStop(1, Qt.alpha(Theme.accent, 0.4));
            ctx.beginPath();
            ctx.arc(c, c, r - 0.75, 0, Math.PI * 2);
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = rim;
            ctx.stroke();
        }
    }

    // Light that trails behind the second hand.
    Canvas {
        id: trail

        anchors.fill: parent
        rotation: root.seconds * 6 * root.intro
        antialiasing: true
        smooth: true
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.outer <= 0)
                return;
            const c = root.radius;
            const sweep = ctx.createConicalGradient(c, c, Math.PI / 2);
            sweep.addColorStop(0, Qt.alpha(Theme.accent, 0.32));
            sweep.addColorStop(0.3, Qt.alpha(Theme.accent, 0));
            sweep.addColorStop(1, Qt.alpha(Theme.accent, 0));
            ctx.beginPath();
            ctx.arc(c, c, root.outer - 2, 0, Math.PI * 2);
            ctx.fillStyle = sweep;
            ctx.fill();
        }
    }

    // Minute track: ticks come alive in turn, and the ones the second hand just passed stay lit.
    Repeater {
        model: 60

        delegate: Rectangle {
            required property int index

            readonly property bool major: index % 5 === 0
            readonly property int age: (root.wholeSecond - index + 60) % 60
            readonly property real glow: age < 16 ? 1 - age / 16 : 0

            x: root.radius - width / 2
            y: root.radius - root.outer + 9
            width: major ? 3.5 : 1.5
            height: major ? root.radius * 0.085 : root.radius * 0.04
            radius: width / 2
            antialiasing: true
            color: Qt.tint(major ? Theme.text : Theme.muted, Qt.alpha(Theme.accent, glow))
            opacity: Math.max(0, Math.min(1, root.intro * 70 - index * 0.8)) * (major ? 0.95 : 0.4 + glow * 0.6)
            transform: Rotation {
                origin.x: width / 2
                origin.y: root.radius - y
                angle: index * 6
            }
        }
    }

    // Hour numerals. The date window takes the place of the 3.
    Repeater {
        model: 12

        delegate: Label {
            required property int index

            readonly property real angle: (index + 1) * Math.PI / 6
            readonly property real orbit: root.radius * 0.68

            x: root.radius + Math.sin(angle) * orbit - width / 2
            y: root.radius - Math.cos(angle) * orbit - height / 2
            visible: index !== 2
            text: index + 1
            size: (index + 1) % 3 === 0 ? Math.round(root.radius * 0.17) : Math.round(root.radius * 0.095)
            font.weight: Font.Light
            color: (index + 1) % 3 === 0 ? Theme.text : Theme.muted
            opacity: root.intro > 0.2 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                }
            }
        }
    }

    Rectangle {
        x: root.radius + root.radius * 0.68 - width / 2
        y: root.radius - height / 2
        width: root.radius * 0.2
        height: root.radius * 0.145
        radius: 6
        color: Qt.alpha(Theme.accent, 0.16)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.55)

        Label {
            anchors.centerIn: parent
            text: Ui.pad(root.day)
            size: Math.round(root.radius * 0.085)
            font.weight: Font.Medium
            color: Theme.accent
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.radius + root.radius * 0.26
        text: root.digital
        size: Math.round(root.radius * 0.1)
        color: Theme.muted
        font.family: Theme.mono
        font.letterSpacing: 1
    }

    // Hour and minute hands. They move once a second, so their shadow is not redrawn every frame.
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.65
            shadowBlur: 0.55
            shadowVerticalOffset: 3
        }

        Hand {
            angle: root.hours * 30 * root.intro
            length: root.radius * 0.44
            tail: root.radius * 0.08
            thickness: root.radius * 0.046
        }
        Hand {
            angle: root.minutes * 6 * root.intro
            length: root.radius * 0.7
            tail: root.radius * 0.1
            thickness: root.radius * 0.032
        }
    }

    // Second hand, its counterweight and the cap over the center.
    Item {
        anchors.fill: parent
        rotation: root.seconds * 6 * root.intro
        antialiasing: true

        Rectangle {
            x: root.radius - width / 2
            y: root.radius * 0.1
            width: 2
            height: root.radius * 1.14
            radius: 1
            antialiasing: true
            color: Theme.accent
        }
        Rectangle {
            x: root.radius - width / 2
            y: root.radius + root.radius * 0.17
            width: 6
            height: root.radius * 0.11
            radius: 3
            antialiasing: true
            color: Theme.accent
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: 18
        height: 18
        radius: 9
        color: Theme.accent
        antialiasing: true

        Rectangle {
            anchors.centerIn: parent
            width: 6
            height: 6
            radius: 3
            color: Theme.pill
            antialiasing: true
        }
    }

    component Hand: Item {
        id: hand

        property real angle: 0
        property real length: 0
        property real tail: 0
        property real thickness: 0

        anchors.fill: parent
        rotation: angle
        antialiasing: true

        Rectangle {
            x: root.radius - width / 2
            y: root.radius - hand.length
            width: hand.thickness
            height: hand.length + hand.tail
            radius: width / 2
            antialiasing: true
            color: Theme.text
        }
        // Luminous strip along the hand.
        Rectangle {
            x: root.radius - width / 2
            y: root.radius - hand.length + hand.thickness * 0.5
            width: hand.thickness * 0.34
            height: hand.length * 0.62
            radius: width / 2
            antialiasing: true
            color: Theme.accent
        }
    }
}
