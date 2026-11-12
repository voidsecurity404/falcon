import QtQuick
import qs.components
import qs.services
import "phone"

// The phone window: drops from the bar's phone part, shaped like a phone (body, screen with a
// camera hole, status line, home bar), and holds everything KDE Connect does with the phone.
// Ui.phonePage picks the screen; the home bar or Esc goes back.
Rectangle {
    id: root

    property bool shown: false
    property real reveal: 0
    property real maxHeight: 760
    readonly property int bodyWidth: 380
    readonly property int bodyHeight: Math.min(780, maxHeight)
    readonly property string page: Ui.phonePage
    // 1 when going deeper, -1 when going back, for the direction of the slide.
    property int direction: 1

    width: bodyWidth
    height: bodyHeight * (0.86 + 0.14 * reveal)
    radius: 52
    clip: true
    visible: reveal > 0
    opacity: Math.min(1, reveal * 2.2)
    color: "transparent"
    border.width: 1
    border.color: Qt.alpha(Theme.text, 0.16)
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.alpha(Theme.glassBase, Math.max(0.8, Theme.glassOpacity))
        }
        GradientStop {
            position: 1
            color: Qt.alpha(Theme.glassBase, Math.max(0.7, Theme.glassOpacity))
        }
    }

    onShownChanged: {
        revealAnimation.stop();
        revealAnimation.to = shown ? 1 : 0;
        revealAnimation.duration = shown ? 460 : 220;
        revealAnimation.easing.bezierCurve = shown ? [0.16, 1, 0.3, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1];
        revealAnimation.start();
        if (shown)
            Phone.send("refresh");
    }
    onRevealChanged: {
        if (reveal === 0)
            Ui.phonePage = "";
    }
    onPageChanged: {
        direction = page === "" ? -1 : 1;
        pageSwap.restart();
    }

    NumberAnimation {
        id: revealAnimation

        target: root
        property: "reveal"
        easing.type: Easing.BezierSpline
    }

    // Clicks inside must not reach the catcher behind, which closes the menu.
    MouseArea {
        anchors.fill: parent
    }

    // The screen inside the body: a slightly lighter glass with its own rounded edge.
    Rectangle {
        id: screen

        x: 7
        y: 7
        width: root.bodyWidth - 14
        height: root.bodyHeight - 14
        radius: 45
        color: Qt.alpha(Theme.text, 0.035)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.07)
        clip: true

        // Status line: the time, the camera hole, the phone's signal and battery.
        Item {
            id: statusLine

            width: parent.width
            height: 44

            Label {
                x: 30
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(clock.now, "hh:mm")
                size: 14
                font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: "#050505"
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.12)

                Rectangle {
                    anchors.centerIn: parent
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Qt.alpha(Theme.accent, 0.35)
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: Phone.connected

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: !!(Phone.device && Phone.device.cell && Phone.device.cell.strength >= 0)

                    Repeater {
                        model: 4

                        delegate: Rectangle {
                            required property int index

                            anchors.bottom: parent.bottom
                            width: 3
                            height: 4 + index * 2.5
                            radius: 1
                            color: Phone.device && Phone.device.cell && index < Phone.device.cell.strength ? Theme.text : Qt.alpha(Theme.text, 0.25)
                        }
                    }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!(Phone.device && Phone.device.usb)
                    text: "USB"
                    size: 10
                    font.weight: Font.Bold
                    color: Theme.muted
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!Phone.battery
                    text: Phone.battery ? Phone.battery.charge + "%" : ""
                    size: 12
                    font.weight: Font.Medium
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!Phone.battery
                    name: Phone.battery && Phone.battery.charging ? "charging" : "battery"
                    size: 18
                    color: Phone.battery && Phone.battery.charge <= 15 && !Phone.battery.charging ? Theme.error : Theme.text
                }
            }
        }

        // The page; it slides in from the side it comes from.
        Item {
            id: pageHolder

            x: 18
            y: statusLine.height + 2
            width: parent.width - 36
            height: parent.height - y - homeBar.height - 6

            Loader {
                id: pageLoader

                width: parent.width
                height: parent.height
                sourceComponent: ({
                        "": homePage,
                        files: filesPage,
                        sms: smsPage,
                        media: mediaPage,
                        remote: remotePage,
                        commands: commandsPage,
                        settings: settingsPage,
                        notifications: notificationsPage
                    })[root.shownPage] || homePage
            }
        }

        // The home bar: back to the home screen.
        Item {
            id: homeBar

            objectName: "phoneHome"
            anchors.bottom: parent.bottom
            width: parent.width
            height: 30

            Rectangle {
                anchors.centerIn: parent
                width: homeArea.containsMouse ? 150 : 128
                height: 5
                radius: 2.5
                color: Qt.alpha(Theme.text, homeArea.containsMouse ? 0.75 : 0.45)

                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
            MouseArea {
                id: homeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.phonePage = ""
            }
        }
    }

    // The page shown follows Ui.phonePage after the old one has slid out.
    property string shownPage: ""

    SequentialAnimation {
        id: pageSwap

        ParallelAnimation {
            NumberAnimation {
                target: pageHolder
                property: "opacity"
                to: 0
                duration: 110
            }
            NumberAnimation {
                target: pageHolder
                property: "x"
                to: 18 - 26 * root.direction
                duration: 110
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                root.shownPage = root.page;
                pageHolder.x = 18 + 34 * root.direction;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: pageHolder
                property: "opacity"
                to: 1
                duration: 220
            }
            NumberAnimation {
                target: pageHolder
                property: "x"
                to: 18
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }

    QtObject {
        id: clock

        property date now: new Date()
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: clock.now = new Date()
    }

    Component {
        id: homePage

        HomePage {}
    }
    Component {
        id: filesPage

        FilesPage {}
    }
    Component {
        id: smsPage

        SmsPage {}
    }
    Component {
        id: mediaPage

        MediaPage {}
    }
    Component {
        id: remotePage

        RemotePage {}
    }
    Component {
        id: commandsPage

        CommandsPage {}
    }
    Component {
        id: settingsPage

        SettingsPage {}
    }
    Component {
        id: notificationsPage

        NotificationsPage {}
    }
}
