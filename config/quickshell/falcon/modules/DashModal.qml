import QtQuick
import qs.components
import qs.services

// The studio layout's dashboard: the clock island lifts off the edge and grows into a card in
// the middle of the screen, over a dimmed desktop. Closing flies it back into the clock.
// Its own size and place animate, not a scale, because the blur region follows those.
Item {
    id: root

    property bool shown: false
    // The clock island's place on this window, where the card starts and ends.
    property rect from: Qt.rect(0, 0, 0, 0)
    property real t: 0
    readonly property int cardWidth: 1160
    readonly property int cardHeight: 580
    property alias card: card

    function lerp(a, b) {
        return a + (b - a) * t;
    }

    onShownChanged: {
        grow.stop();
        grow.to = shown ? 1 : 0;
        grow.duration = shown ? 620 : 300;
        grow.easing.bezierCurve = shown ? [0.2, 1.12, 0.3, 1, 1, 1] : [0.4, 0, 0.9, 0.4, 1, 1];
        grow.start();
    }

    NumberAnimation {
        id: grow

        target: root
        property: "t"
        easing.type: Easing.BezierSpline
    }

    // The desktop dims behind the card.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.38 * Math.max(0, Math.min(1, root.t))
        visible: root.t > 0
    }

    Rectangle {
        id: card

        visible: root.t > 0.001
        x: root.lerp(root.from.x, (root.width - root.cardWidth) / 2)
        y: root.lerp(root.from.y, (root.height - root.cardHeight) / 2)
        width: Math.max(1, root.lerp(root.from.width, root.cardWidth))
        height: Math.max(1, root.lerp(root.from.height, root.cardHeight))
        radius: root.lerp(20, 32)
        clip: true
        border.width: 1
        border.color: Theme.panelEdge
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.glassTop
            }
            GradientStop {
                position: 1
                color: Theme.panel
            }
        }

        // A press on the card does not reach the catcher behind it.
        MouseArea {
            anchors.fill: parent
        }

        Item {
            anchors.centerIn: parent
            width: root.cardWidth
            height: root.cardHeight
            opacity: Math.max(0, Math.min(1, (root.t - 0.4) / 0.6))

            Loader {
                anchors.fill: parent
                active: Settings.layout === "studio"
                asynchronous: true
                sourceComponent: Backdrop {
                    page: Ui.dashTab === 1 ? 1 : 0
                    art: Ui.dashTab === 1 ? Media.art : ""
                    playing: !!Media.player && Media.player.isPlaying
                    bottomRadius: 32
                }
            }
            Loader {
                anchors.fill: parent
                active: Settings.layout === "studio"
                asynchronous: true
                visible: root.shown || root.t > 0
                sourceComponent: Dashboard {}
            }
        }
    }
}
