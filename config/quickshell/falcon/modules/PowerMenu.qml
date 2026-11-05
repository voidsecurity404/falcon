import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// The big power menu in the middle of the screen, opened by the red button of the app menu.
// One value, reveal, drives everything, so closing plays the opening backward: a red circle
// appears, the card grows out of it, and the tiles fly out from the middle.
PanelWindow {
    id: root

    readonly property bool closing: Ui.popup !== "power"
    readonly property var items: Session.items
    readonly property int gap: 10
    readonly property int cardPadding: 22
    readonly property int headerHeight: 62
    readonly property int footerHeight: 46
    readonly property real tileWidth: Math.min(164, ((root.width || 1920) - 80 - cardPadding * 2 - gap * (items.length - 1)) / items.length)
    readonly property real tileHeight: 176
    readonly property real fullWidth: tileWidth * items.length + gap * (items.length - 1) + cardPadding * 2
    readonly property real fullHeight: headerHeight + tileHeight + footerHeight + cardPadding

    property real reveal: 0
    property int selected: 0
    // Dangerous actions need a second press, this holds the first one.
    property string armed: ""
    property real armedAt: 0
    // Time left to press again, 1 to 0, drawn on the tile.
    property real armLeft: 0
    // The pointer counts once it has really moved: a tile left under it stays unselected at first.
    property var pointerStart: null
    property bool pointerLive: false

    function clamp(v) {
        return Math.max(0, Math.min(1, v));
    }

    function outBack(t, s) {
        const u = t - 1;
        return 1 + (s + 1) * u * u * u + s * u * u;
    }

    // A tile's share of the reveal. The middle one goes first and the others follow outward.
    function tileProgress(index) {
        const delay = 0.2 + Math.abs(index - (items.length - 1) / 2) * 0.07;
        return clamp((reveal - delay) / 0.6);
    }

    function slotX(index) {
        return index * (tileWidth + gap);
    }

    function select(index) {
        if (index === selected)
            return;
        selected = index;
        disarm();
    }

    function disarm() {
        armed = "";
        armTimer.stop();
    }

    function press(index) {
        const item = items[index];
        if (!item)
            return;
        selected = index;
        if (item.confirm && armed !== item.id) {
            armed = item.id;
            armedAt = Date.now();
            armTimer.restart();
            return;
        }
        // A double click must not turn the computer off.
        if (item.confirm && Date.now() - armedAt < 350)
            return;
        disarm();
        Ui.popup = "";
        item.run();
    }

    function pointerMoved(point) {
        if (pointerLive)
            return true;
        if (!pointerStart)
            pointerStart = point;
        else if (Math.abs(pointerStart.x - point.x) + Math.abs(pointerStart.y - point.y) > 3)
            pointerLive = true;
        return pointerLive;
    }

    onClosingChanged: {
        revealAnimation.stop();
        if (closing) {
            disarm();
            revealAnimation.to = 0;
            revealAnimation.duration = 300;
            revealAnimation.easing.type = Easing.InCubic;
        } else {
            selected = 0;
            pointerStart = null;
            pointerLive = false;
            keys.forceActiveFocus();
            revealAnimation.to = 1;
            revealAnimation.duration = 720;
            revealAnimation.easing.type = Easing.Linear;
        }
        revealAnimation.start();
    }

    NumberAnimation {
        id: revealAnimation

        target: root
        property: "reveal"
        onFinished: {
            if (root.closing)
                Ui.powerAlive = false;
        }
    }
    NumberAnimation {
        id: armTimer

        target: root
        property: "armLeft"
        from: 1
        to: 0
        duration: 4000
        onFinished: root.armed = ""
    }

    visible: Ui.powerAlive
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "falcon-power"
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    mask: Region {
        item: catcher
    }
    BackgroundEffect.blurRegion: Region {
        item: card
        radius: card.radius
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.55 * root.clamp(root.reveal * 2.5)
    }

    MouseArea {
        id: catcher

        // Empty while closing, so clicks already reach what is behind.
        width: root.closing ? 0 : parent.width
        height: root.closing ? 0 : parent.height
        onClicked: Ui.popup = ""
    }

    Item {
        id: keys

        focus: true
        Keys.onEscapePressed: {
            if (root.armed !== "")
                root.disarm();
            else
                Ui.popup = "";
        }
        Keys.onLeftPressed: root.select((root.selected + root.items.length - 1) % root.items.length)
        Keys.onRightPressed: root.select((root.selected + 1) % root.items.length)
        Keys.onTabPressed: root.select((root.selected + 1) % root.items.length)
        // A held key must not arm and then run the action.
        Keys.onReturnPressed: event => {
            if (!event.isAutoRepeat)
                root.press(root.selected);
        }
        Keys.onEnterPressed: event => {
            if (!event.isAutoRepeat)
                root.press(root.selected);
        }
    }

    // Its own size animates, because the blur region follows that and not a scale.
    Rectangle {
        id: card

        readonly property real grow: root.outBack(root.clamp(root.reveal / 0.55), 0.9)

        width: 84 + (root.fullWidth - 84) * grow
        height: 84 + (root.fullHeight - 84) * grow
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        radius: Math.min(height / 2, 42 - 8 * root.clamp(grow))
        opacity: root.clamp(root.reveal * 8)
        border.width: 1
        border.color: Theme.panelEdge
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.panel
            }
            GradientStop {
                position: 1
                color: Theme.glassTop
            }
        }

        // Keeps clicks on the card from closing the menu.
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: content

            anchors.centerIn: parent
            width: root.fullWidth
            height: root.fullHeight

            Label {
                readonly property real show: root.clamp((root.reveal - 0.5) / 0.3)

                x: root.cardPadding + 4
                y: 20 + (1 - show) * 10
                width: parent.width - root.cardPadding * 2 - 8
                text: Tr.t("Power menu")
                size: 22
                font.weight: Font.DemiBold
                opacity: show
            }

            // Slides between the tiles.
            Rectangle {
                x: root.cardPadding + root.slotX(root.selected)
                y: root.headerHeight
                width: root.tileWidth
                height: root.tileHeight
                radius: 26
                color: root.armed !== "" ? Session.red : Qt.alpha(Theme.text, 0.1)
                opacity: root.tileProgress(root.selected)

                Behavior on x {
                    SpringAnimation {
                        spring: 5
                        damping: 0.42
                        epsilon: 0.2
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }

            Repeater {
                model: root.items

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index

                    readonly property real progress: root.tileProgress(index)
                    readonly property real out: root.outBack(progress, 1.4)
                    readonly property bool current: root.selected === index
                    readonly property bool isArmed: root.armed === modelData.id
                    readonly property real middleX: root.slotX((root.items.length - 1) / 2)

                    x: root.cardPadding + middleX + (root.slotX(index) - middleX) * out
                    y: root.headerHeight + (1 - progress) * 26
                    width: root.tileWidth
                    height: root.tileHeight
                    opacity: root.clamp(progress * 2)
                    scale: (0.55 + 0.45 * out) * (area.pressed ? 0.94 : 1)

                    Behavior on scale {
                        enabled: root.reveal >= 1

                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.4
                        }
                    }

                    Rectangle {
                        id: disc

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: tile.current ? 24 : 30
                        width: 76
                        height: 76
                        radius: tile.current ? 26 : 38
                        scale: tile.current ? 1.08 : 1
                        color: tile.isArmed ? "white" : tile.current ? Theme.accent : Qt.alpha(Theme.text, 0.08)

                        Behavior on y {
                            NumberAnimation {
                                duration: 320
                                easing.type: Easing.OutBack
                                easing.overshoot: 2
                            }
                        }
                        Behavior on radius {
                            NumberAnimation {
                                duration: 320
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.4
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 320
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.2
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: tile.modelData.icon
                            size: 32
                            color: tile.isArmed ? Session.red : tile.current ? Theme.accentText : Theme.text
                            // Each icon moves its own way when chosen.
                            rotation: !tile.current ? 0 : tile.modelData.id === "reboot" ? 360 : tile.modelData.id === "sleep" ? -24 : tile.modelData.id === "power" ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 620
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Label {
                        x: 10
                        width: parent.width - 20
                        y: 118
                        height: 40
                        text: tile.modelData.name
                        size: 14
                        font.weight: tile.current ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        color: tile.isArmed ? "white" : tile.current ? Theme.text : Qt.alpha(Theme.text, 0.72)
                    }

                    // Time left to press again.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 12
                        width: (parent.width - 44) * root.armLeft
                        height: 3
                        radius: 2
                        color: "white"
                        visible: tile.isArmed
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => {
                            if (root.pointerMoved(mapToItem(content, mouse.x, mouse.y)))
                                root.select(tile.index);
                        }
                        onClicked: root.press(tile.index)
                    }
                }
            }

            Label {
                readonly property real show: root.clamp((root.reveal - 0.65) / 0.3)

                x: root.cardPadding
                y: root.headerHeight + root.tileHeight + 14 - (1 - show) * 6
                width: parent.width - root.cardPadding * 2
                horizontalAlignment: Text.AlignHCenter
                text: root.armed !== "" ? Tr.t("Press once more to proceed") : Tr.t("Arrows choose, Enter confirms, Esc closes")
                size: 13
                color: root.armed !== "" ? Qt.lighter(Session.red, 1.35) : Theme.muted
                opacity: show
            }
        }

        // The red circle the card grows from. It turns once and melts into the card.
        Rectangle {
            readonly property real fade: root.clamp((root.reveal - 0.14) / 0.2)

            anchors.centerIn: parent
            width: 84
            height: 84
            radius: 42
            color: Session.red
            opacity: 1 - fade
            scale: 0.6 + 0.4 * root.outBack(root.clamp(root.reveal / 0.18), 1.6) + fade * 0.5
            visible: opacity > 0

            Icon {
                anchors.centerIn: parent
                name: "power"
                size: 34
                color: "white"
                rotation: root.reveal * 720
            }
        }
    }
}
