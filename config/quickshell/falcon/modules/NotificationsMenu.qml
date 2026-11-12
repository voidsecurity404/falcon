import QtQuick
import qs.components
import qs.services

// The bell's menu, in two tabs: this computer's notification history, and the notifications
// on the phone through KDE Connect. A swipe on a phone card dismisses it on the phone too.
Flyout {
    id: root

    readonly property int tab: Ui.notificationsTab
    readonly property var phoneRows: Phone.history.map(n => ({
                id: n.id,
                app: n.app || Tr.t("Phone"),
                title: n.title || n.app,
                sub: n.text,
                time: n.time,
                date: n.date,
                replyId: n.active ? n.replyId : ""
            }))
    readonly property string phoneEmpty: !Phone.installed ? Tr.t("KDE Connect is not installed") : Tr.t("No notifications from the phone yet")

    panelWidth: 380
    padding: 6

    Column {
        width: parent.width
        spacing: 6

        // Two tabs in one capsule; the accent piece slides between them.
        Rectangle {
            id: tabs

            width: parent.width
            height: 38
            radius: 19
            color: Qt.alpha(Theme.text, 0.05)

            Rectangle {
                id: piece

                y: 3
                height: parent.height - 6
                width: (parent.width - 6) / 2
                x: 3 + root.tab * width
                radius: height / 2
                color: Theme.accent

                Behavior on x {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }
            }

            Repeater {
                model: [
                    {
                        icon: "monitor",
                        name: Tr.t("Computer"),
                        count: Toasts.unread
                    },
                    {
                        icon: "phone",
                        name: Tr.t("Phone"),
                        count: Phone.unread
                    }
                ]

                delegate: Item {
                    id: tabItem

                    required property var modelData
                    required property int index
                    readonly property bool active: root.tab === index

                    objectName: index === 0 ? "tabComputer" : "tabPhone"
                    x: 3 + index * piece.width
                    y: 3
                    width: piece.width
                    height: piece.height

                    Row {
                        anchors.centerIn: parent
                        spacing: 7

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: tabItem.modelData.icon
                            size: 15
                            color: tabItem.active ? Theme.accentText : Theme.muted

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabItem.modelData.name
                            size: 13
                            font.weight: Font.Medium
                            color: tabItem.active ? Theme.accentText : Theme.text

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tabItem.modelData.count > 0 && !tabItem.active
                            width: Math.max(18, countLabel.implicitWidth + 10)
                            height: 18
                            radius: 9
                            color: Theme.accent

                            Label {
                                id: countLabel

                                anchors.centerIn: parent
                                text: tabItem.modelData.count > 99 ? "99+" : tabItem.modelData.count
                                size: 11
                                color: Theme.accentText
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.notificationsTab = tabItem.index
                    }
                }
            }
        }

        // Both lists side by side; the strip slides to the chosen one.
        Item {
            width: parent.width
            height: 440
            clip: true

            Item {
                id: strip

                width: parent.width * 2 + 12
                height: parent.height
                x: -root.tab * (parent.width + 12)

                Behavior on x {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                    }
                }

                NotificationList {
                    width: (strip.width - 12) / 2
                    height: strip.height
                    opacity: root.tab === 0 ? 1 : 0.3

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                        }
                    }
                }
                NotificationList {
                    x: (strip.width + 12) / 2
                    width: (strip.width - 12) / 2
                    height: strip.height
                    opacity: root.tab === 1 ? 1 : 0.3
                    title: Phone.device ? Phone.device.name : Tr.t("Phone")
                    items: root.phoneRows
                    emptyText: root.phoneEmpty
                    emptyIcon: "phone"
                    forgetIds: ids => Phone.forget(ids)
                    timeOf: row => Toasts.timeLabel(row)
                    replyTo: (row, text) => Phone.reply(row.replyId, text)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                        }
                    }
                }
            }
        }
    }
}
