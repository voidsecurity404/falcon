import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// A notification at the top right, under the right island. It drops in, stays for the notification
// time, then shrinks and flies into the bell, which rings when it lands. A click runs it, a right
// click sends it away at once. Animates its own x, y, width and height, never a scale, because the
// blur region follows those.
Rectangle {
    id: root

    // Where the card rests and where the bell is, in the layer's coordinates.
    property real restX: 0
    property real restY: 0
    property point bell: Qt.point(restX + cardWidth, restY - 20)
    property bool bellSeen: true
    // False while the bell's menu is open, or in focus mode for a message not meant for it.
    property bool allowed: true

    readonly property int cardWidth: 360
    readonly property real restHeight: Math.max(64, textColumn.implicitHeight + 28)
    // The message on screen, kept while it flies away.
    property var item: null
    // 0 above its place and see-through, 1 resting, then 2 inside the bell.
    property real phase: 0
    readonly property bool flying: phase > 1
    readonly property real fly: Math.max(0, phase - 1)
    readonly property real ease: fly * fly

    function lerp(a, b, t) {
        return a + (b - a) * t;
    }

    function sync() {
        const next = allowed ? Toasts.current : null;
        if (next === item)
            return;
        if (item && !flying) {
            leave();
            return;
        }
        if (!item && next) {
            item = next;
            arrive.restart();
        }
    }

    function leave() {
        arrive.stop();
        away.to = 2;
        away.duration = bellSeen ? 560 : 260;
        away.restart();
    }

    onAllowedChanged: sync()

    Connections {
        target: Toasts
        function onCurrentChanged() {
            root.sync();
        }
    }

    NumberAnimation {
        id: arrive

        target: root
        property: "phase"
        from: 0
        to: 1
        duration: 320
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: away

        target: root
        property: "phase"
        easing.type: Easing.Linear
        onFinished: {
            if (root.bellSeen)
                Ui.bellRings += 1;
            root.item = null;
            root.phase = 0;
            root.sync();
        }
    }

    visible: !!item
    x: flying ? lerp(restX, bell.x - width / 2, ease) : restX
    y: flying ? lerp(restY, bell.y - height / 2, ease) : restY - (1 - phase) * 14
    width: flying && bellSeen ? lerp(cardWidth, 18, ease) : cardWidth
    height: flying && bellSeen ? lerp(restHeight, 18, ease) : restHeight
    radius: flying ? lerp(18, 9, ease) : 18
    opacity: flying ? (bellSeen ? 1 - Math.max(0, fly - 0.75) * 4 : 1 - fly) : phase
    clip: true
    border.width: 1
    border.color: Theme.panelEdge
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.alpha(Theme.glassBase, Math.max(0.72, Theme.glassOpacity))
        }
        GradientStop {
            position: 1
            color: Qt.alpha(Theme.glassBase, Math.max(0.6, Theme.glassOpacity))
        }
    }

    // The contents keep their size and fade early while the card shrinks.
    Item {
        width: root.cardWidth
        height: root.restHeight
        opacity: root.flying ? Math.max(0, 1 - root.fly * 3) : 1

        Rectangle {
            id: badge

            x: 14
            y: 14
            width: 36
            height: 36
            radius: 11
            color: Theme.accent

            Icon {
                anchors.centerIn: parent
                visible: picture.status !== Image.Ready
                name: root.item ? root.item.icon || "bell" : "bell"
                color: Theme.accentText
                size: 18
            }
            // A picture sent with a notification, such as a chat avatar, replaces the icon.
            ClippingRectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                visible: picture.status === Image.Ready

                Image {
                    id: picture

                    anchors.fill: parent
                    source: root.item && root.item.image ? root.item.image : ""
                    sourceSize: Qt.size(72, 72)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }
        }

        Column {
            id: textColumn

            x: 62
            y: 14
            width: root.cardWidth - 62 - 16
            spacing: 3

            Label {
                width: parent.width
                text: root.item ? root.item.title : ""
                font.weight: Font.DemiBold
                size: 14
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: root.item ? root.item.sub || "" : ""
                color: Theme.muted
                size: 12
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.flying
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Toasts.advance();
            else
                Toasts.activate();
        }
    }
}
