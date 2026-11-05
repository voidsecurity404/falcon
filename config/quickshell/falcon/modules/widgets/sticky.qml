import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.components
import qs.services

// A paper note on the desktop, slightly tinted by the wallpaper. Saved shortly after typing stops.
Item {
    id: root

    property string form: "wide"
    readonly property bool typing: editor.activeFocus
    readonly property color paper: Qt.tint("#fbeeb4", Qt.alpha(Theme.accent, 0.14))
    readonly property color ink: "#3b3320"

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

    Rectangle {
        anchors.fill: parent
        radius: 16
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.lighter(root.paper, 1.03)
            }
            GradientStop {
                position: 1
                color: Qt.darker(root.paper, 1.06)
            }
        }
    }
    // A strip of tape at the top.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: 66
        height: 12
        radius: 3
        rotation: -1.5
        color: Qt.alpha(root.ink, 0.13)
    }
    Flickable {
        x: 20
        y: 28
        width: parent.width - 40
        height: parent.height - 42
        contentHeight: editor.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
            id: editor

            width: parent.width
            wrapMode: TextEdit.Wrap
            color: root.ink
            selectionColor: root.ink
            selectedTextColor: root.paper
            font.family: Theme.sans
            font.pixelSize: 16
            font.weight: Font.Medium
            onTextChanged: {
                if (activeFocus)
                    saver.restart();
            }
            onActiveFocusChanged: Widgets.noteFocused = activeFocus

            Label {
                visible: editor.text === ""
                text: Tr.t("Write something…")
                color: Qt.alpha(root.ink, 0.45)
                size: 16
            }
        }
    }
}
