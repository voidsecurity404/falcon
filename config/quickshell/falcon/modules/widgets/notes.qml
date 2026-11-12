import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// A note written right on the desktop over faint ruled lines, saved shortly after typing stops.
// Forms: wide, tall.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool typing: editor.activeFocus
    readonly property real lineHeight: metrics.lineSpacing
    property bool saved: true
    readonly property int words: editor.text.trim() === "" ? 0 : editor.text.trim().split(/\s+/).length

    FileView {
        id: file

        path: Widgets.notePath
        printErrors: false
        atomicWrites: true
        // Two copies of this widget stand on the desktop: what one writes the other shows.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (!editor.activeFocus)
                editor.text = text();
        }
    }
    Timer {
        id: saver

        interval: 600
        onTriggered: {
            file.setText(editor.text);
            root.saved = true;
        }
    }
    Component.onDestruction: {
        if (saver.running)
            file.setText(editor.text);
    }
    HoverHandler {
        onHoveredChanged: Widgets.noteHovered = hovered
    }
    FontMetrics {
        id: metrics

        font: editor.font
    }

    WidgetCaption {
        x: 20
        y: 18
        icon: "note"
        text: Tr.t("Notes")
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 13
        spacing: 6

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.words > 0 ? Tr.t("{n} words").replace("{n}", root.words) : ""
            size: 11
            color: Theme.muted
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 4
            color: root.saved ? Theme.good : Theme.accent
            opacity: root.saved ? 0.7 : 1
        }
        WidgetButton {
            height: 30
            icon: "copy"
            visible: editor.text !== ""
            onClicked: {
                Quickshell.clipboardText = editor.text;
                Toasts.show(Tr.t("Note copied"), "", "copy");
            }
        }
    }

    // Ruled lines under the text.
    Item {
        id: paper

        x: 20
        y: 56
        width: parent.width - 40
        height: parent.height - y - 16
        clip: true

        Repeater {
            model: Math.ceil(paper.height / root.lineHeight)

            Rectangle {
                required property int index

                y: (index + 1) * root.lineHeight - flick.contentY % root.lineHeight + 2
                width: paper.width
                height: 1
                color: Qt.alpha(Theme.text, 0.08)
            }
        }
        Rectangle {
            x: -2
            width: 2
            height: paper.height
            radius: 1
            color: Qt.alpha(Theme.accent, 0.5)
        }
        Flickable {
            id: flick

            x: 10
            width: paper.width - 10
            height: paper.height
            contentHeight: editor.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // The face draws this note but cannot scroll; it follows the clickable copy.
            onContentYChanged: {
                if (enabled)
                    Widgets.share(root.widgetId, "scroll", contentY);
            }

            Binding on contentY {
                when: !flick.enabled
                value: Widgets.sharedValue(root.widgetId, "scroll", 0)
            }

            TextEdit {
                id: editor

                width: parent.width
                wrapMode: TextEdit.Wrap
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.family: Theme.sans
                font.pixelSize: 15
                textFormat: TextEdit.PlainText
                onTextChanged: {
                    if (activeFocus) {
                        root.saved = false;
                        saver.restart();
                    }
                }
                onActiveFocusChanged: Widgets.noteFocused = activeFocus
                onCursorRectangleChanged: {
                    if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                        flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
                    else if (cursorRectangle.y < flick.contentY)
                        flick.contentY = cursorRectangle.y;
                }
                Keys.onEscapePressed: focus = false

                Label {
                    visible: editor.text === ""
                    text: Tr.t("Write something…")
                    color: Theme.muted
                    size: 15
                }
            }
        }
    }
}
