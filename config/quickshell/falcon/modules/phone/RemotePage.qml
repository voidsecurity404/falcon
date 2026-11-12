import QtQuick
import qs.components
import qs.services

// The phone as a remote screen: a touchpad that moves a pointer on the phone, its buttons, and
// typing into the phone from this keyboard. The phone needs KDE Connect's remote input service
// on (Android settings → Accessibility).
PhonePage {
    id: root

    property real pendingX: 0
    property real pendingY: 0
    property real scrollY: 0
    property bool typing: false

    title: Tr.t("Remote input")
    subtitle: Tr.t("Move, click and type on the phone")

    // Moves are gathered and sent at most 60 times a second.
    Timer {
        id: flush

        interval: 16
        repeat: true
        running: root.visible
        onTriggered: {
            if (root.pendingX !== 0 || root.pendingY !== 0) {
                Phone.send("mouse", {
                    dx: root.pendingX,
                    dy: root.pendingY
                });
                root.pendingX = 0;
                root.pendingY = 0;
            }
            if (Math.abs(root.scrollY) >= 1) {
                Phone.send("scroll", {
                    dy: root.scrollY
                });
                root.scrollY = 0;
            }
        }
    }

    Column {
        width: parent.width
        spacing: 12

        Rectangle {
            id: pad

            objectName: "phoneTouchpad"
            width: parent.width
            height: 300
            radius: 24
            color: Qt.alpha(Theme.text, padArea.pressed ? 0.1 : 0.06)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.1)

            Column {
                anchors.centerIn: parent
                spacing: 6
                opacity: padArea.pressed ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "touchpad"
                    size: 30
                    color: Qt.alpha(Theme.text, 0.35)
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("Drag to move · click to tap")
                    size: 11
                    color: Theme.muted
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("Wheel scrolls")
                    size: 11
                    color: Theme.muted
                }
            }

            // A soft dot under the pointer while dragging.
            Rectangle {
                id: dot

                width: 34
                height: 34
                radius: 17
                color: Qt.alpha(Theme.accent, 0.35)
                visible: padArea.pressed
                x: padArea.mouseX - 17
                y: padArea.mouseY - 17
            }

            MouseArea {
                id: padArea

                property point last: Qt.point(0, 0)
                property bool moved: false

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.CrossCursor
                onPressed: mouse => {
                    last = Qt.point(mouse.x, mouse.y);
                    moved = false;
                }
                onPositionChanged: mouse => {
                    const dx = mouse.x - last.x;
                    const dy = mouse.y - last.y;
                    if (Math.abs(dx) + Math.abs(dy) > 0) {
                        root.pendingX += dx * 1.6;
                        root.pendingY += dy * 1.6;
                        moved = moved || Math.hypot(dx, dy) > 2;
                    }
                    last = Qt.point(mouse.x, mouse.y);
                }
                onReleased: mouse => {
                    if (moved)
                        return;
                    Phone.send("click", {
                        button: mouse.button === Qt.RightButton ? "rightclick" : mouse.button === Qt.MiddleButton ? "middleclick" : "singleclick"
                    });
                }
                onDoubleClicked: Phone.send("click", {
                    button: "doubleclick"
                })
                onWheel: wheel => {
                    root.scrollY += -wheel.angleDelta.y / 12;
                }
            }
        }

        Row {
            width: parent.width
            spacing: 8

            PhoneButton {
                width: (parent.width - 16) / 3
                text: Tr.t("Back")
                icon: "back"
                onClicked: Phone.send("key", {
                    key: "Escape"
                })
            }
            PhoneButton {
                width: (parent.width - 16) / 3
                text: Tr.t("Tap")
                onClicked: Phone.send("click", {
                    button: "singleclick"
                })
            }
            PhoneButton {
                width: (parent.width - 16) / 3
                text: Tr.t("Hold")
                onClicked: Phone.send("click", {
                    button: "rightclick"
                })
            }
        }

        // Typing goes to the phone key by key while this has the focus.
        Rectangle {
            id: keys

            objectName: "phoneKeyboard"
            width: parent.width
            height: 54
            radius: 18
            color: keyCatcher.activeFocus ? Qt.alpha(Theme.accent, 0.2) : Qt.alpha(Theme.text, keysArea.containsMouse ? 0.09 : 0.06)
            border.width: 1
            border.color: keyCatcher.activeFocus ? Theme.accent : "transparent"

            Row {
                anchors.centerIn: parent
                spacing: 8

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "keyboard"
                    size: 18
                    color: keyCatcher.activeFocus ? Theme.accent : Theme.muted
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyCatcher.activeFocus ? Tr.t("Typing on the phone… Esc stops") : Tr.t("Click to type on the phone")
                    size: 12
                    color: keyCatcher.activeFocus ? Theme.text : Theme.muted
                }
            }
            MouseArea {
                id: keysArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: keyCatcher.forceActiveFocus()
            }
            Item {
                id: keyCatcher

                readonly property var special: ({
                        [Qt.Key_Backspace]: "Backspace",
                        [Qt.Key_Tab]: "Tab",
                        [Qt.Key_Left]: "Left",
                        [Qt.Key_Up]: "Up",
                        [Qt.Key_Right]: "Right",
                        [Qt.Key_Down]: "Down",
                        [Qt.Key_PageUp]: "PageUp",
                        [Qt.Key_PageDown]: "PageDown",
                        [Qt.Key_Home]: "Home",
                        [Qt.Key_End]: "End",
                        [Qt.Key_Return]: "Enter",
                        [Qt.Key_Enter]: "Enter",
                        [Qt.Key_Delete]: "Delete"
                    })

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        keys.forceActiveFocus();
                        event.accepted = true;
                        return;
                    }
                    const name = special[event.key];
                    if (name)
                        Phone.send("key", {
                            key: name
                        });
                    else if (event.text !== "" && event.text >= " ")
                        Phone.send("key", {
                            key: event.text
                        });
                    event.accepted = true;
                }
            }
        }
    }
}
