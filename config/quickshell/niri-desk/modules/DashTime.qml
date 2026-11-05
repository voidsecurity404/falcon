import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Screen Time: today's total as one number, seven days as columns, and today's apps as a ranked list.
Item {
    id: root

    readonly property var week: ScreenTime.week
    readonly property real weekTop: Math.max(3600, ...week.map(d => d.seconds))
    readonly property var apps: ScreenTime.apps.slice(0, 7)
    readonly property real appTop: apps.length > 0 ? apps[0].seconds : 1
    property int hovered: -1

    // Left: the headline and the week
    Item {
        id: left

        width: Math.round((parent.width - 32) * 0.46)
        height: parent.height

        Label {
            id: bigNumber

            text: ScreenTime.format(ScreenTime.todaySeconds)
            size: 46
            font.weight: Font.Light
        }
        Label {
            id: caption

            y: bigNumber.implicitHeight + 2
            text: ScreenTime.enabled ? Tr.t("Today at the screen. Daily average {t}").replace("{t}", ScreenTime.format(ScreenTime.weekAverage)) : Tr.t("Counting is off in Settings")
            size: 13
            color: Theme.muted
        }

        Item {
            id: chart

            y: caption.y + caption.implicitHeight + 26
            width: parent.width
            height: parent.height - y

            readonly property int labelHeight: 24
            readonly property int plotHeight: height - labelHeight - 24

            // Quiet guide at the top of the scale.
            Rectangle {
                y: 24
                width: parent.width
                height: 1
                color: Qt.alpha(Theme.text, 0.08)
            }
            Label {
                anchors.right: parent.right
                y: 4
                text: ScreenTime.format(root.weekTop)
                size: 11
                color: Theme.muted
                visible: root.hovered < 0
            }
            Label {
                x: 0
                y: 2
                visible: root.hovered >= 0
                text: root.hovered >= 0 ? root.week[root.hovered].full + "  ·  " + ScreenTime.format(root.week[root.hovered].seconds) : ""
                size: 12
            }
            Row {
                y: 24
                width: parent.width
                height: chart.plotHeight + chart.labelHeight

                Repeater {
                    model: root.week

                    delegate: Item {
                        id: day

                        required property var modelData
                        required property int index

                        width: parent.width / 7
                        height: parent.height

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: chart.plotHeight - height
                            width: 22
                            height: Math.max(day.modelData.seconds > 0 ? 4 : 0, chart.plotHeight * day.modelData.seconds / root.weekTop)
                            topLeftRadius: 4
                            topRightRadius: 4
                            color: day.modelData.today || root.hovered === day.index ? Theme.accent : Qt.alpha(Theme.accent, 0.45)

                            Behavior on height {
                                NumberAnimation {
                                    duration: 420
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }
                        Rectangle {
                            y: chart.plotHeight
                            width: parent.width
                            height: 1
                            color: Qt.alpha(Theme.text, 0.14)
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: chart.plotHeight + 6
                            text: day.modelData.label
                            size: 12
                            color: day.modelData.today ? Theme.text : Theme.muted
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onContainsMouseChanged: {
                                if (containsMouse)
                                    root.hovered = day.index;
                                else if (root.hovered === day.index)
                                    root.hovered = -1;
                            }
                        }
                    }
                }
            }
        }
    }

    // Right: apps of today
    Column {
        x: left.width + 32
        width: parent.width - x
        spacing: 7

        Label {
            text: Tr.t("Apps today")
            size: 13
            color: Theme.muted
            bottomPadding: 4
        }
        Repeater {
            model: root.apps

            delegate: Item {
                id: app

                required property var modelData

                width: parent.width
                height: 50

                IconImage {
                    id: appIcon

                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 30
                    source: Quickshell.iconPath(app.modelData.icon || "", true)
                    visible: status === Image.Ready
                }
                Icon {
                    anchors.centerIn: appIcon
                    visible: !appIcon.visible
                    name: "windows"
                    size: 22
                }
                Label {
                    x: 44
                    y: 5
                    width: parent.width - 44 - duration.implicitWidth - 12
                    text: app.modelData.name
                    size: 14
                    elide: Text.ElideRight
                }
                Label {
                    id: duration

                    anchors.right: parent.right
                    y: 5
                    text: ScreenTime.format(app.modelData.seconds)
                    size: 13
                    color: Theme.muted
                }
                Rectangle {
                    x: 44
                    y: 32
                    width: parent.width - 44
                    height: 6
                    radius: 3
                    color: Qt.alpha(Theme.text, 0.07)

                    Rectangle {
                        width: Math.max(6, parent.width * app.modelData.seconds / root.appTop)
                        height: parent.height
                        radius: 3
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: 420
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
        Label {
            visible: root.apps.length === 0
            text: Tr.t("Nothing counted yet today")
            color: Theme.muted
            size: 13
        }
    }
}
