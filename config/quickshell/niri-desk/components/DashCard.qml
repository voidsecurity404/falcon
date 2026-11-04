import QtQuick
import qs.services

// Dashboard card. Rises and fades in each time its page appears, delay staggers the cards.
Rectangle {
    id: root

    property int delay: 0
    property bool clickable: false

    signal clicked

    function reveal() {
        rise.stop();
        opacity = 0;
        shift.y = 16;
        rise.start();
    }

    radius: 18
    color: Qt.alpha(Theme.text, area.containsMouse && clickable ? 0.08 : 0.045)
    border.width: 1
    border.color: Qt.alpha(Theme.text, 0.06)
    transform: Translate {
        id: shift
    }

    Component.onCompleted: reveal()
    onVisibleChanged: {
        if (visible)
            reveal();
    }

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    SequentialAnimation {
        id: rise

        PauseAnimation {
            duration: root.delay
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: shift
                property: "y"
                to: 0
                duration: 460
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.3, 0.36, 1, 1, 1]
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
