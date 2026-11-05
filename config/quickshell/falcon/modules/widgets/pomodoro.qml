import QtQuick
import qs.components
import qs.services

// Work and break rounds, the same timer as in the island. Forms: round, wide.
Item {
    id: root

    property string form: "round"
    readonly property bool wide: form === "wide"
    readonly property bool active: Countdown.active
    readonly property int workMinutes: Settings.get("timer.work", 25)
    readonly property string shown: active ? Countdown.text : workMinutes + ":00"
    readonly property color tone: Countdown.phase === "break" ? Theme.good : Theme.accent
    readonly property string caption: {
        if (!active)
            return Tr.t("Ready to focus");
        if (Countdown.paused)
            return Tr.t("On pause");
        if (Countdown.phase === "work")
            return Tr.t("Round {n}").replace("{n}", Countdown.round);
        return Countdown.label !== "" ? Countdown.label : Tr.t("Timer");
    }

    component Button: Rectangle {
        id: button

        property string icon: ""
        property bool main: false
        signal pressed

        width: main ? 44 : 36
        height: width
        radius: width / 2
        color: main ? root.tone : Qt.alpha(Theme.text, area.containsMouse ? 0.16 : 0.08)
        scale: area.pressed ? 0.9 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 110
            }
        }

        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: button.main ? 18 : 13
            color: button.main ? Theme.accentText : Theme.text
        }
        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.pressed()
        }
    }

    Ring {
        id: dial

        x: root.wide ? 14 : (parent.width - width) / 2
        y: root.wide ? (parent.height - height) / 2 : 14
        width: root.wide ? 88 : 156
        height: width
        thickness: root.wide ? 8 : 12
        color: root.tone
        value: root.active && Countdown.total > 0 ? Countdown.left / Countdown.total : 1

        Label {
            anchors.centerIn: parent
            text: root.shown
            size: root.wide ? 17 : 30
            font.family: Theme.display
            font.weight: Font.DemiBold
        }
    }
    Label {
        visible: !root.wide
        anchors.horizontalCenter: dial.horizontalCenter
        y: dial.y + dial.height + 4
        text: root.caption
        color: Theme.muted
        size: 12
    }
    Label {
        visible: root.wide
        x: dial.x + dial.width + 16
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 104
        text: root.caption
        size: 14
        font.weight: Font.Medium
        wrapMode: Text.WordWrap
        maximumLineCount: 2
    }
    Row {
        x: root.wide ? parent.width - width - 14 : (parent.width - width) / 2
        y: root.wide ? (parent.height - height) / 2 : parent.height - height - 8
        spacing: 8

        Button {
            anchors.verticalCenter: parent.verticalCenter
            main: true
            icon: root.active && !Countdown.paused ? "pause" : "play"
            onPressed: {
                if (root.active)
                    Countdown.togglePause();
                else
                    Countdown.pomodoro();
            }
        }
        Button {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.active
            icon: "close"
            onPressed: Countdown.stop()
        }
    }
}
