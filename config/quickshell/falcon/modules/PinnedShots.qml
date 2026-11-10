import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Pinned pictures from services/Pins.qml, each a card above the windows on the Top layer
// (namespace falcon-pin). It starts exactly where the area was cut, so the picture seems to lift
// off the screen. Drag moves it, the wheel resizes it around the pointer, Ctrl with the wheel
// changes its opacity, a middle click closes it. Copy, save and close show on hover.
Scope {
    Variants {
        model: Pins.items

        PanelWindow {
            id: pin

            required property var modelData
            // Room for the shadow around the card. Only the card takes input.
            readonly property int pad: 26
            readonly property var area: screen
            property real px: 0
            property real py: 0
            property real zoom: 1
            property real cardOpacity: 1
            readonly property real cardW: Math.round(modelData.w * zoom)
            readonly property real cardH: Math.round(modelData.h * zoom)
            property bool lifted: false

            // Keeps at least part of the card on its screen.
            function place(x, y) {
                const keep = 48;
                px = Math.max(area.x - cardW + keep, Math.min(area.x + area.width - keep, x));
                py = Math.max(area.y, Math.min(area.y + area.height - keep, y));
            }

            function zoomAt(factor, atX, atY) {
                const before = zoom;
                const shortest = Math.min(modelData.w, modelData.h);
                // From about 60 px on the short side up to three times the size or the screen.
                const low = Math.min(1, 60 / shortest);
                const high = Math.max(1, Math.min(3, area.width * 0.95 / modelData.w, area.height * 0.95 / modelData.h));
                zoom = Math.max(low, Math.min(high, zoom * factor));
                const k = zoom / before;
                place(px + atX - atX * k, py + atY - atY * k);
                sizeHint.restart();
            }

            screen: Quickshell.screens.find(s => modelData.x >= s.x && modelData.x < s.x + s.width && modelData.y >= s.y && modelData.y < s.y + s.height) || Quickshell.screens[0]
            anchors {
                top: true
                left: true
            }
            margins {
                left: Math.round(px - area.x - pad)
                top: Math.round(py - area.y - pad)
            }
            implicitWidth: cardW + pad * 2
            implicitHeight: cardH + pad * 2
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "falcon-pin"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                item: card
            }

            Component.onCompleted: {
                px = modelData.x;
                py = modelData.y;
                lifted = true;
            }

            Item {
                id: card

                x: pin.pad
                y: pin.pad
                width: pin.cardW
                height: pin.cardH
                opacity: pin.cardOpacity

                // The lift: the shadow grows in and the card swells a little and settles.
                RectangularShadow {
                    anchors.fill: parent
                    radius: 10
                    blur: 26
                    spread: 1
                    offset.y: 8
                    color: Qt.alpha("#000000", 0.5)
                    opacity: pin.lifted ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 320
                        }
                    }
                }
                ClippingRectangle {
                    id: frame

                    anchors.fill: parent
                    radius: 10
                    color: Theme.surface
                    scale: pin.lifted ? 1 : 1.035

                    Behavior on scale {
                        NumberAnimation {
                            duration: 420
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.2
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: "file://" + pin.modelData.path
                        fillMode: Image.Stretch
                        smooth: true
                        mipmap: true
                        cache: false
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(Theme.text, hover.hovered ? 0.35 : 0.18)
                    }
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    id: dragArea

                    property real pressX: 0
                    property real pressY: 0

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            Pins.remove(pin.modelData.id);
                            return;
                        }
                        pressX = mouse.x;
                        pressY = mouse.y;
                    }
                    onPositionChanged: mouse => {
                        if (pressed)
                            pin.place(pin.px + mouse.x - pressX, pin.py + mouse.y - pressY);
                    }
                    onDoubleClicked: pin.zoomAt(1 / pin.zoom, pin.cardW / 2, pin.cardH / 2)
                    onWheel: wheel => {
                        const up = wheel.angleDelta.y > 0;
                        if (wheel.modifiers & Qt.ControlModifier) {
                            pin.cardOpacity = Math.max(0.25, Math.min(1, pin.cardOpacity + (up ? 0.1 : -0.1)));
                            sizeHint.restart();
                            return;
                        }
                        pin.zoomAt(up ? 1.1 : 1 / 1.1, wheel.x, wheel.y);
                    }
                }

                // Size and opacity, for a moment after they change.
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    width: sizeLabel.implicitWidth + 16
                    height: 24
                    radius: 12
                    color: Qt.alpha(Theme.surface, 0.88)
                    opacity: sizeHint.running ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    Label {
                        id: sizeLabel

                        anchors.centerIn: parent
                        text: Math.round(pin.zoom * 100) + "%" + (pin.cardOpacity < 1 ? " · " + Tr.t("opacity") + " " + Math.round(pin.cardOpacity * 100) + "%" : "")
                        size: 11
                        font.weight: Font.Medium
                    }
                }
                Timer {
                    id: sizeHint

                    interval: 900
                }

                // Copy, save, close: on hover, in the top right corner.
                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 7
                    spacing: 5
                    opacity: hover.hovered && !dragArea.pressed ? 1 : 0
                    visible: opacity > 0 && pin.cardW >= 110 && pin.cardH >= 40

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }

                    Repeater {
                        model: [
                            { icon: "copy", run: () => Pins.copy(pin.modelData.id) },
                            { icon: "save", run: () => Pins.save(pin.modelData.id) },
                            { icon: "close", run: () => Pins.remove(pin.modelData.id) }
                        ]

                        delegate: Rectangle {
                            id: button

                            required property var modelData

                            width: 28
                            height: 28
                            radius: 14
                            color: buttonArea.containsMouse ? Theme.accent : Qt.alpha(Theme.surface, 0.9)
                            border.width: 1
                            border.color: Qt.alpha(Theme.text, 0.12)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: button.modelData.icon
                                size: 14
                                color: buttonArea.containsMouse ? Theme.accentText : Theme.text
                            }
                            MouseArea {
                                id: buttonArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: button.modelData.run()
                            }
                        }
                    }
                }
            }
        }
    }
}
