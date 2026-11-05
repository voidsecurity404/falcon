import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Tasks kept in ~/.config/falcon/todo.json. Forms: wide, short.
Item {
    id: root

    property string form: "wide"
    readonly property bool typing: field.activeFocus
    property var tasks: []
    readonly property int doneCount: tasks.filter(t => t.done).length

    function store(next) {
        tasks = next;
        file.setText(JSON.stringify(next, null, 1) + "\n");
    }

    function add(text) {
        const clean = text.trim();
        if (clean !== "")
            store(tasks.concat([{ text: clean, done: false }]));
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/falcon/todo.json"
        printErrors: false
        atomicWrites: true
        // The same list stands in two copies of this widget.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text());
                root.tasks = Array.isArray(list) ? list.filter(t => t && typeof t.text === "string") : [];
            } catch (e) {
                root.tasks = [];
            }
        }
    }
    HoverHandler {
        onHoveredChanged: Widgets.noteHovered = hovered
    }

    Label {
        x: 20
        y: 14
        text: Tr.t("Tasks")
        size: 18
        font.family: Theme.display
        font.weight: Font.Bold
    }
    Ring {
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 14
        width: 26
        height: 26
        thickness: 4
        visible: root.tasks.length > 0
        value: root.tasks.length ? root.doneCount / root.tasks.length : 0
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: 52
        y: 19
        visible: root.tasks.length > 0
        text: root.doneCount + " / " + root.tasks.length
        color: Theme.muted
        size: 12
    }
    Label {
        anchors.centerIn: parent
        visible: root.tasks.length === 0
        text: Tr.t("Nothing to do yet")
        color: Theme.muted
        size: 13
    }
    ListView {
        x: 14
        y: 48
        width: parent.width - 28
        height: parent.height - y - 56
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: root.tasks

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 36

            HoverHandler {
                id: rowHover
            }
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.alpha(Theme.text, rowHover.hovered ? 0.07 : 0)
            }
            Rectangle {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: row.modelData.done ? Theme.accent : "transparent"
                border.width: 2
                border.color: row.modelData.done ? Theme.accent : Qt.alpha(Theme.text, 0.4)

                Icon {
                    anchors.centerIn: parent
                    visible: row.modelData.done === true
                    name: "check"
                    size: 12
                    color: Theme.accentText
                }
            }
            Label {
                x: 38
                width: parent.width - x - 32
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.text
                color: row.modelData.done ? Theme.muted : Theme.text
                font.strikeout: row.modelData.done === true
                size: 14
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.store(root.tasks.map((t, i) => i === row.index ? { text: t.text, done: !t.done } : t))
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: 12
                visible: rowHover.hovered
                color: removeArea.containsMouse ? Theme.error : "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 11
                    color: removeArea.containsMouse ? Theme.pill : Theme.muted
                }
                MouseArea {
                    id: removeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.store(root.tasks.filter((t, i) => i !== row.index))
                }
            }
        }
    }
    Rectangle {
        x: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: parent.width - 28
        height: 36
        radius: 12
        color: Qt.alpha(Theme.text, 0.07)
        border.width: field.activeFocus ? 1 : 0
        border.color: Theme.accent

        Icon {
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            name: "plus"
            size: 14
            color: Theme.muted
        }
        TextInput {
            id: field

            x: 34
            width: parent.width - x - 10
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            font.family: Theme.sans
            font.pixelSize: 14
            clip: true
            onAccepted: {
                root.add(text);
                text = "";
            }
            onActiveFocusChanged: Widgets.noteFocused = activeFocus
            Keys.onEscapePressed: focus = false

            Label {
                visible: field.text === ""
                text: Tr.t("New task")
                color: Theme.muted
                size: 14
            }
        }
    }
}
