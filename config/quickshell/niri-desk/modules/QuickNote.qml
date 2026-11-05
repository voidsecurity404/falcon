import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// Quick Note: rises from the bottom right corner, over any window. It is the same text as the
// notes widget on the desktop. Esc or a click outside closes and saves.
PanelWindow {
    id: root

    readonly property bool closing: Ui.popup !== "note"
    readonly property int edgeGap: Settings.bottom ? 56 : 16
    property real reveal: 0

    function flush() {
        if (saver.running || editor.text !== file.text()) {
            saver.stop();
            file.setText(editor.text);
        }
    }

    onClosingChanged: {
        if (closing) {
            flush();
            openAnim.stop();
            closeAnim.start();
        } else {
            closeAnim.stop();
            file.reload();
            editor.forceActiveFocus();
            editor.cursorPosition = editor.text.length;
            openAnim.start();
        }
    }

    visible: Ui.noteAlive
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
    WlrLayershell.namespace: "niri-desk-note"
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    mask: Region {
        item: catcher
    }
    BackgroundEffect.blurRegion: Region {
        item: card
        radius: card.radius
    }

    FileView {
        id: file

        path: Widgets.notePath
        blockLoading: true
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (!editor.activeFocus || root.closing)
                editor.text = text();
        }
    }
    Timer {
        id: saver

        interval: 500
        onTriggered: file.setText(editor.text)
    }
    NumberAnimation {
        id: openAnim

        target: root
        property: "reveal"
        to: 1
        duration: 320
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
    }
    SequentialAnimation {
        id: closeAnim

        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: 180
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: Ui.noteAlive = false
        }
    }

    MouseArea {
        id: catcher

        width: root.closing ? 0 : parent.width
        height: root.closing ? 0 : parent.height
        onClicked: Ui.popup = ""
    }

    Rectangle {
        id: card

        readonly property int fullHeight: 340

        x: parent.width - width - 16
        y: parent.height - root.edgeGap - fullHeight + (1 - root.reveal) * (fullHeight + root.edgeGap + 4)
        width: 440
        height: fullHeight
        radius: 22
        border.width: 1
        border.color: Theme.panelEdge
        color: Qt.alpha(Theme.surface, Math.max(0.7, Theme.panel.a))

        MouseArea {
            anchors.fill: parent
        }

        Icon {
            x: 18
            y: 17
            name: "note"
            size: 16
            color: Theme.accent
        }
        Label {
            x: 44
            y: 15
            text: Tr.t("Quick note")
            size: 13
            font.weight: Font.Medium
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 16
            text: Tr.t("Saved by itself")
            size: 12
            color: Theme.muted
        }
        Flickable {
            id: scroller

            x: 18
            y: 46
            width: parent.width - 36
            height: parent.height - 62
            contentHeight: editor.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: editor

                width: parent.width
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                selectByMouse: true
                font.family: Theme.sans
                font.pixelSize: 15
                Keys.onEscapePressed: Ui.popup = ""
                onTextChanged: {
                    if (activeFocus && !root.closing)
                        saver.restart();
                }
                onCursorRectangleChanged: {
                    if (cursorRectangle.y + cursorRectangle.height > scroller.contentY + scroller.height)
                        scroller.contentY = cursorRectangle.y + cursorRectangle.height - scroller.height;
                    else if (cursorRectangle.y < scroller.contentY)
                        scroller.contentY = cursorRectangle.y;
                }

                Label {
                    visible: editor.text === ""
                    text: Tr.t("Write something…")
                    color: Qt.alpha(Theme.text, 0.4)
                    size: 15
                }
            }
        }
    }
}
