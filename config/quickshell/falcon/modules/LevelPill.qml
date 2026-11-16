import QtQuick
import qs.components
import qs.services

// Volume and brightness levels: a small pill under the bar's middle island while a level changes.
Rectangle {
    id: root

    // The last level stays while the pill fades out.
    property var shown: null
    readonly property var level: Toasts.osd
    property real reveal: level ? 1 : 0
    property real restY: 0
    readonly property bool isBadge: !!shown && shown.text === true
    // Starts KeyState, which reports Caps Lock and layout changes into this pill.
    readonly property bool keysWatched: KeyState.enabled

    onLevelChanged: {
        if (level)
            shown = level;
    }

    Behavior on reveal {
        NumberAnimation {
            duration: root.level ? 200 : 260
            easing.type: Easing.OutCubic
        }
    }

    visible: reveal > 0.01
    opacity: reveal
    y: restY - (1 - reveal) * 10
    width: isBadge ? badgeRow.implicitWidth + 36 : 250
    height: 40

    Behavior on width {
        enabled: root.reveal > 0.5
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    radius: 14
    border.width: 1
    border.color: Theme.panelEdge
    color: Qt.alpha(Theme.glassBase, Math.max(0.72, Theme.glassOpacity))

    Row {
        anchors.centerIn: parent
        spacing: 12
        visible: !root.isBadge

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.shown ? root.shown.icon : "volume"
            size: 17
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            height: 6
            radius: 3
            color: Qt.alpha(Theme.text, 0.15)

            Rectangle {
                width: parent.width * (root.shown ? Math.max(0, Math.min(1, root.shown.value)) : 0)
                height: parent.height
                radius: 3
                color: Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            text: root.shown ? Math.round(root.shown.value * 100) + "%" : ""
            size: 12
            font.weight: Font.DemiBold
        }
    }

    // Caps Lock and the layout: an icon, the name and, for a layout, its code in a chip.
    Row {
        id: badgeRow

        anchors.centerIn: parent
        spacing: 10
        visible: root.isBadge

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 9
            color: root.shown && root.shown.on ? Theme.accent : Qt.alpha(Theme.text, 0.12)

            Icon {
                anchors.centerIn: parent
                name: root.shown && root.isBadge ? root.shown.icon : "keyboard"
                size: 15
                color: root.shown && root.shown.on ? Theme.accentText : Theme.text
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.isBadge ? root.shown.title : ""
            size: 14
            font.weight: Font.DemiBold
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.isBadge && root.shown.code !== ""
            width: codeLabel.implicitWidth + 14
            height: 22
            radius: 7
            color: Qt.alpha(Theme.accent, 0.18)

            Label {
                id: codeLabel

                anchors.centerIn: parent
                text: root.isBadge ? root.shown.code : ""
                color: Theme.accent
                size: 11
                font.family: Theme.mono
                font.weight: Font.DemiBold
            }
        }
    }
}
