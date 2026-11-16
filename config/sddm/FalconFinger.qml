// Falcon's fingerprint on the login screen, laid over the sddm-astronaut theme with FalconLeave.
//
// falcon-fingerd (root) watches the sensor while the greeter runs and shows its progress as the
// name of the one empty file in /run/falcon-finger/greeter/, "SEQ.STATE.USER", watched here with
// a FolderListModel (no polling, no file reading). A match leaves a one-time token in the
// daemon; the form then logs in as that finger's owner (whoever is shown) with an empty
// password, which the PAM line of /etc/pam.d/sddm accepts only with that token. Typing a
// password works as always and never waits for the finger. Without the daemon this stays hidden.
import QtQuick 2.15
import QtQuick.Shapes 1.15
import Qt.labs.folderlistmodel 2.15

Item {
    id: root

    property Item form
    property Item input
    property string state_: "off"   // off, scanning, nomatch, match
    property int lastSeq: -1
    property string user: ""
    readonly property bool ru: Qt.locale().name.indexOf("ru") === 0
    readonly property color tint: config.PasswordIconColor || config.HeaderTextColor || "#ffffff"
    readonly property color plain: config.HeaderTextColor || config.LoginFieldTextColor || "#ffffff"
    readonly property color bad: config.WarningColor || "#ff6b6b"

    function say(en, ru) {
        return root.ru ? ru : en;
    }

    function place() {
        if (!form || !input)
            return;
        // Under the password field (the patch gives Input an alias to it), else under the form.
        var field = input.falconPassword || input;
        var p = field.mapToItem(form, field.width / 2, field.height);
        x = Math.round(p.x - width / 2);
        y = Math.round(p.y + 10);
    }

    function read() {
        var best = null;
        for (var i = 0; i < files.count; i++) {
            var parts = String(files.get(i, "fileName")).split(".");
            var seq = parseInt(parts[0]);
            if (parts.length >= 3 && !isNaN(seq) && (best === null || seq > best.seq))
                best = { seq: seq, state: parts[1], user: parts.slice(2).join(".") };
        }
        if (best === null) {
            root.state_ = "off";
            return;
        }
        var fresh = best.seq !== root.lastSeq;
        root.lastSeq = best.seq;
        root.user = best.user;
        if (best.state === "nomatch" && fresh) {
            root.state_ = "nomatch";
            shake.restart();
            calm.restart();
        } else if (best.state === "match" && fresh) {
            root.state_ = "match";
            if (!(input && input.falconFingerLogin && input.falconFingerLogin(root.user)))
                calm.restart();
        } else if ((best.state === "scanning" || best.state === "retry") && root.state_ !== "nomatch") {
            root.state_ = "scanning";
        } else if (best.state === "off" || best.state === "error") {
            root.state_ = "off";
        }
    }

    FolderListModel {
        id: files

        folder: "file:///run/falcon-finger/greeter"
        showDirs: false
        showHidden: false
        onCountChanged: root.read()
        onStatusChanged: root.read()
    }
    // A rename of the one file keeps the count; this catches it.
    Connections {
        target: files

        function onDataChanged() {
            root.read();
        }
        function onRowsInserted() {
            root.read();
        }
    }

    parent: form
    width: row.implicitWidth
    height: 30
    opacity: state_ === "off" ? 0 : 1
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 300
        }
    }

    // Follows the form while the theme lays it out (sizes settle after the first frames).
    Timer {
        interval: 400
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.place()
    }
    Timer {
        id: calm

        interval: 1600
        onTriggered: {
            if (root.state_ === "nomatch" || root.state_ === "match")
                root.state_ = "scanning";
        }
    }

    Row {
        id: row

        property real shakeX: 0

        x: shakeX
        spacing: 9
        anchors.verticalCenter: parent.verticalCenter

        Shape {
            id: printShape

            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            opacity: 1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.state_ === "nomatch" ? root.bad : root.tint
                strokeWidth: 1.8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                scale: Qt.size(22 / 24, 22 / 24)

                PathSvg {
                    path: "M12 10a2 2 0 0 0-2 2c0 1.02-.1 2.51-.26 4 M14 13.12c0 2.38 0 6.38-1 8.88 M17.29 21.02c.12-.6.43-2.3.5-3.02 M2 12a10 10 0 0 1 18-6 M2 16h.01 M21.8 16c.2-2 .131-5.354 0-6 M5 19.5C5.5 18 6 15 6 12a6 6 0 0 1 .34-2 M8.65 22c.21-.66.45-1.32.57-2 M9 6.8a6 6 0 0 1 9 5.2v2"
                }
            }

            SequentialAnimation on opacity {
                running: root.state_ === "scanning"
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.4; duration: 1100; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.state_ === "nomatch" ? root.say("Finger not recognized", "Палец не распознан")
                : root.state_ === "match" ? root.say("Finger recognized", "Палец распознан")
                : root.say("Touch the sensor or type the password", "Приложите палец или введите пароль")
            color: root.state_ === "nomatch" ? root.bad : root.plain
            font.family: config.Font || "sans-serif"
            font.pointSize: Math.max(10, Number(config.FontSize || 12))
        }
    }

    SequentialAnimation {
        id: shake

        NumberAnimation { target: row; property: "shakeX"; to: -10; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: row; property: "shakeX"; to: 8; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: row; property: "shakeX"; to: -5; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: row; property: "shakeX"; to: 0; duration: 60; easing.type: Easing.OutQuad }
    }
}
