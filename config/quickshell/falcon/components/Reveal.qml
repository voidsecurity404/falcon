import QtQuick

// Rises and fades in when it appears. Put one element inside; delay staggers a group.
Item {
    id: root

    property int delay: 0
    property bool shown: true
    property bool animate: true
    // A shorter rise that settles without passing its place.
    property bool calm: false

    function play() {
        rise.stop();
        if (!animate) {
            opacity = 1;
            shift.y = 0;
            return;
        }
        opacity = 0;
        shift.y = calm ? 8 : 12;
        rise.start();
    }

    implicitHeight: childrenRect.height
    width: parent ? parent.width : 0
    transform: Translate {
        id: shift
    }

    onShownChanged: {
        if (shown)
            play();
    }
    Component.onCompleted: {
        if (shown)
            play();
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
                duration: root.calm ? 260 : 220
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: shift
                property: "y"
                to: 0
                duration: root.calm ? 360 : 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.calm ? [0.2, 0, 0, 1, 1, 1] : [0.22, 1.25, 0.36, 1, 1, 1]
            }
        }
    }
}
