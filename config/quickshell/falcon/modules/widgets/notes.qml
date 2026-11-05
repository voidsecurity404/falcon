import QtQuick
import Quickshell.Io
import qs.components
import qs.services

// A quick note on the desktop. Saved shortly after typing stops.
Item {
    id: root

    FileView {
        id: file

        path: Widgets.notePath
        printErrors: false
        atomicWrites: true
        // Ikki nusxa bor: birida yozilgani ikkinchisida ham ko'rinadi.
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
        onTriggered: file.setText(editor.text)
    }
    Component.onDestruction: {
        if (saver.running)
            file.setText(editor.text);
    }

    HoverHandler {
        onHoveredChanged: Widgets.noteHovered = hovered
    }

    Label {
        x: 18
        y: 14
        text: Tr.t("Notes")
        color: Theme.muted
        size: 12
    }
    Flickable {
        x: 18
        y: 36
        width: parent.width - 36
        height: parent.height - 50
        contentHeight: editor.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
            id: editor

            width: parent.width
            wrapMode: TextEdit.Wrap
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            font.family: Theme.sans
            font.pixelSize: 14
            onTextChanged: {
                if (activeFocus)
                    saver.restart();
            }
            onActiveFocusChanged: Widgets.noteFocused = activeFocus

            Label {
                visible: editor.text === ""
                text: Tr.t("Write something…")
                color: Qt.alpha(Theme.text, 0.35)
                size: 14
            }
        }
    }
}
