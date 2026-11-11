import QtQuick
import Quickshell
import qs.components
import qs.services

// The windows layout's clock flyout, after Windows 11's: the notifications in one card and the
// date, the month and a focus session in another, stacked over the bottom right corner. The
// cards slide in from the right edge one after the other.
Item {
    id: root

    property bool shown: false
    property real t: 0
    // The taskbar's top edge.
    property real baseY: 0
    property int focusMinutes: 30
    readonly property int cardWidth: 360

    onShownChanged: {
        slide.stop();
        slide.to = shown ? 1 : 0;
        slide.duration = shown ? 380 : 170;
        slide.easing.bezierCurve = shown ? [0.1, 0.9, 0.2, 1, 1, 1] : [0.7, 0, 1, 0.5, 1, 1];
        slide.start();
    }

    NumberAnimation {
        id: slide

        target: root
        property: "t"
        easing.type: Easing.BezierSpline
    }

    readonly property real lateT: Math.max(0, Math.min(1, t * 1.25 - 0.25))
    // The two cards, for the blur regions.
    property alias notes: notes
    property alias month: month

    width: cardWidth
    height: notes.height + month.height + 12
    y: baseY - height - 12
    visible: t > 0.001

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    component Card: Rectangle {
        radius: 10
        clip: true
        color: Qt.alpha(Theme.glassBase, Math.max(0.86, Theme.glassOpacity))
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.12)

        MouseArea {
            anchors.fill: parent
        }
    }

    Card {
        id: notes

        x: (1 - root.lateT) * (root.cardWidth + 20)
        width: root.cardWidth
        height: 340
        opacity: root.lateT

        NotificationList {
            clearMargin: 20
            anchors.fill: parent
            color: "transparent"
        }
    }

    Card {
        id: month

        x: (1 - root.t) * (root.cardWidth + 20)
        y: notes.height + 12
        width: root.cardWidth
        height: monthColumn.implicitHeight + 70
        opacity: root.t

        Column {
            id: monthColumn

            x: 18
            y: 16
            width: parent.width - 36
            spacing: 12

            Label {
                text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "dddd, d MMMM"))
                size: 14
                font.weight: Font.DemiBold
            }
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.alpha(Theme.text, 0.08)
            }
            Calendar {
                anchors.horizontalCenter: parent.horizontalCenter
                cellWidth: 44
                cellHeight: 30
            }
        }
        // A focus session: minutes down and up, then start. A running one shows its time.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 54
            color: Qt.alpha(Theme.glassBase, 0.6)

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.alpha(Theme.text, 0.08)
            }
            Row {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: !Countdown.active

                Repeater {
                    model: ["-", "+"]

                    delegate: Rectangle {
                        id: step

                        required property string modelData

                        width: 30
                        height: 30
                        radius: 4
                        color: Qt.alpha(Theme.text, stepArea.containsMouse ? 0.12 : 0.06)

                        Label {
                            anchors.centerIn: parent
                            text: step.modelData === "-" ? "−" : "+"
                            size: 15
                        }
                        MouseArea {
                            id: stepArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.focusMinutes = Math.max(5, Math.min(240, root.focusMinutes + (step.modelData === "-" ? -5 : 5)))
                        }
                    }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.focusMinutes + " " + Tr.t("min")
                    size: 13
                }
            }
            Label {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                visible: Countdown.active
                text: Countdown.text + (Countdown.paused ? "  ·  " + Tr.t("Paused") : "")
                size: 14
                font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: focusLabel.implicitWidth + 28
                height: 32
                radius: 4
                color: Countdown.active ? Qt.alpha(Theme.text, focusArea.containsMouse ? 0.14 : 0.08) : focusArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent

                Label {
                    id: focusLabel

                    anchors.centerIn: parent
                    text: Countdown.active ? Tr.t("Stop") : Tr.t("Focus")
                    size: 13
                    font.weight: Font.Medium
                    color: Countdown.active ? Theme.text : Theme.accentText
                }
                MouseArea {
                    id: focusArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Countdown.active)
                            Countdown.stop();
                        else
                            Countdown.start(root.focusMinutes * 60, Tr.t("Focus"));
                    }
                }
            }
        }
    }
}
