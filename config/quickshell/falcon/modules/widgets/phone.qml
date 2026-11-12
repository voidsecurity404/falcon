import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// The phone through KDE Connect: its battery in a small drawn phone, the newest notification and
// actions: find it, send the clipboard, open its files, open the phone window. Forms: wide, square.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool square: form === "square"
    readonly property var dev: Phone.device
    readonly property bool on: Phone.connected
    readonly property int charge: Phone.battery ? Phone.battery.charge : 0
    readonly property bool charging: !!Phone.battery && Phone.battery.charging
    readonly property color level: !on ? Theme.muted : charging ? Theme.good : charge <= 15 ? Theme.error : Theme.accent
    readonly property var latest: Phone.history.length ? Phone.history[0] : null

    function ago(entry) {
        if (!entry || !entry.time)
            return "";
        const m = Math.floor((Date.now() - entry.time) / 60000);
        return m < 1 ? Tr.t("now") : m < 60 ? m + " " + Tr.t("min") : Qt.formatTime(new Date(entry.time), "hh:mm");
    }

    // A small phone with the charge rising inside its screen.
    Item {
        id: handset

        x: root.square ? 22 : 24
        y: root.square ? 22 : 24
        width: root.square ? 58 : 78
        height: root.square ? 108 : root.height - 48

        Rectangle {
            anchors.fill: parent
            radius: width * 0.24
            color: Qt.alpha(Theme.pill, 0.6)
            border.width: 2
            border.color: Qt.alpha(root.level, 0.6)
        }
        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: parent.width * 0.2
            color: Qt.alpha(root.level, 0.08)

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: root.on ? parent.height * root.charge / 100 : 0
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: root.level
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(root.level, 0.45)
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 700
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 2

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.charging || !root.on
                    name: root.on ? "bolt" : "phone"
                    filled: root.on
                    size: 16
                    color: Theme.text
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.on
                    text: root.charge + "%"
                    size: root.square ? 12 : 14
                    font.weight: Font.Bold
                }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 9
            width: 8
            height: 8
            radius: 4
            color: Qt.alpha(Theme.pill, 0.9)
        }
    }

    Column {
        id: head

        x: handset.x + handset.width + 18
        y: root.square ? 30 : 26
        width: root.width - x - 18
        spacing: 5

        Label {
            width: parent.width
            text: root.dev ? root.dev.name : Tr.t("Phone")
            size: 17
            font.family: Theme.display
            font.weight: Font.DemiBold
        }
        Row {
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: root.on ? Theme.good : Theme.error
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: !Phone.installed ? Tr.t("KDE Connect is not installed") : !root.on ? Tr.t("Not connected") : root.dev && root.dev.usb ? Tr.t("Connected by USB") : Tr.t("Connected over Wi-Fi")
                size: 12
                color: Theme.muted
            }
        }
    }

    // The newest notification from the phone.
    Rectangle {
        id: latestCard

        visible: !!root.latest
        x: root.square ? 18 : head.x
        y: root.square ? handset.y + handset.height + 14 : head.y + head.height + 14
        width: root.width - x - 18
        height: 52
        radius: 16
        color: Qt.alpha(Theme.text, latestHot.hovered ? 0.12 : 0.07)

        Rectangle {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 11
            color: Qt.alpha(Theme.accent, 0.18)

            Image {
                anchors.fill: parent
                anchors.margins: 4
                source: root.latest && root.latest.icon ? "file://" + root.latest.icon : ""
                sourceSize.width: 64
                asynchronous: true
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                visible: !(root.latest && root.latest.icon)
                name: "bell"
                size: 15
                color: Theme.accent
            }
        }
        Column {
            x: 50
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 10
            spacing: 1

            Row {
                width: parent.width
                spacing: 6

                Label {
                    width: Math.min(implicitWidth, parent.width - when.implicitWidth - 6)
                    text: root.latest ? root.latest.title : ""
                    size: 13
                    font.weight: Font.DemiBold
                }
                Label {
                    id: when

                    text: root.ago(root.latest)
                    size: 11
                    color: Theme.muted
                }
            }
            Label {
                width: parent.width
                text: root.latest ? root.latest.text.replace(/\s*\n+\s*/g, " · ") : ""
                maximumLineCount: 1
                size: 12
                color: Theme.muted
            }
        }
        Rectangle {
            visible: Phone.unread > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: -4
            width: Math.max(20, unreadText.implicitWidth + 10)
            height: 20
            radius: 10
            color: Theme.accent

            Label {
                id: unreadText

                anchors.centerIn: parent
                text: Phone.unread
                size: 11
                font.weight: Font.Bold
                color: Theme.accentText
            }
        }
        WidgetHot {
            id: latestHot

            anchors.fill: parent
            onClicked: {
                Ui.notificationsTab = 1;
                Ui.popup = "notifications";
            }
        }
    }

    Row {
        x: root.square ? (root.width - width) / 2 : head.x
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        spacing: 8

        WidgetButton {
            height: 40
            icon: "bell"
            visible: root.on
            onClicked: Phone.ring()
        }
        WidgetButton {
            height: 40
            icon: "copy"
            visible: root.on
            onClicked: Phone.sendClipboard()
        }
        WidgetButton {
            height: 40
            icon: "folder"
            visible: root.on
            onClicked: Phone.browse()
        }
        WidgetButton {
            height: 40
            main: true
            icon: "phone"
            text: root.square ? "" : Tr.t("Open")
            onClicked: Ui.popup = "phone"
        }
    }
}
