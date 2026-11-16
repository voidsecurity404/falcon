import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Tasks kept in ~/.config/falcon/todo.json: add, tick off, remove, clear the done ones.
// Forms: tall, wide.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "tall"
    readonly property bool typing: field.activeFocus
    property var tasks: []
    readonly property int doneCount: tasks.filter(t => t.done).length
    readonly property real progress: tasks.length ? doneCount / tasks.length : 0

    function store(next) {
        tasks = next;
        file.setText(JSON.stringify(next, null, 1) + "\n");
    }
    // "@18:00", "@tomorrow 9:00", "@30m" at the end sets a deadline, see TaskReminders.parse.
    function add(text) {
        const p = TaskReminders.parse(text, Date.now());
        if (p.text === "")
            return;
        const task = { text: p.text, done: false };
        if (p.due > 0)
            task.due = p.due;
        store([task].concat(tasks));
    }
    // Ticks each half minute, so a passed deadline turns red.
    property real nowMs: Date.now()
    Timer {
        interval: 30000
        running: root.tasks.some(t => t.due && !t.done)
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }
    // Open tasks first, sooner deadlines before later and none, the done ones under them.
    readonly property var ordered: tasks.map((t, i) => ({ text: t.text, done: t.done === true, due: Number(t.due) || 0, index: i })).sort((a, b) => (a.done - b.done) || ((a.due || 9e15) - (b.due || 9e15)) || (a.index - b.index))

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

    WidgetCaption {
        x: 20
        y: 18
        icon: "check"
        text: Tr.t("Tasks")
    }
    WidgetButton {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 13
        height: 30
        visible: root.doneCount > 0
        text: Tr.t("Clear done")
        onClicked: root.store(root.tasks.filter(t => !t.done))
    }
    // Progress
    Item {
        x: 20
        y: 50
        width: parent.width - 40
        height: 20
        visible: root.tasks.length > 0

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 58
            height: 6
            radius: 3
            color: Qt.alpha(Theme.accent, 0.15)

            Rectangle {
                width: Math.max(6, parent.width * root.progress)
                height: parent.height
                radius: 3
                color: root.progress === 1 ? Theme.good : Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: 450
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        Label {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.doneCount + " / " + root.tasks.length
            size: 12
            font.weight: Font.DemiBold
            color: root.progress === 1 ? Theme.good : Theme.text
        }
    }
    Column {
        anchors.centerIn: parent
        visible: root.tasks.length === 0
        spacing: 6

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "check"
            size: 30
            color: Qt.alpha(Theme.accent, 0.6)
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("Nothing to do yet")
            color: Theme.muted
            size: 13
        }
    }

    ListView {
        id: list

        x: 12
        y: 78
        width: parent.width - 24
        height: parent.height - y - 60
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: root.ordered
        // The face draws this list but cannot scroll; it follows the clickable copy.
        onContentYChanged: {
            if (enabled)
                Widgets.share(root.widgetId, "scroll", contentY);
        }

        Binding on contentY {
            when: !list.enabled
            value: Widgets.sharedValue(root.widgetId, "scroll", 0)
        }

        delegate: Item {
            id: row

            required property var modelData

            width: ListView.view.width
            height: 38

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Qt.alpha(Theme.text, rowHot.hovered ? 0.08 : 0)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
            WidgetHot {
                id: rowHot

                anchors.fill: parent
                onClicked: root.store(root.tasks.map((t, i) => i === row.modelData.index ? Object.assign({}, t, { done: !t.done }) : t))
            }
            Rectangle {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 11
                color: row.modelData.done ? Theme.accent : "transparent"
                border.width: 2
                border.color: row.modelData.done ? Theme.accent : Qt.alpha(Theme.text, rowHot.hovered ? 0.6 : 0.35)

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    visible: row.modelData.done
                    name: "check"
                    size: 13
                    color: Theme.accentText
                }
            }
            Label {
                id: dueLabel

                readonly property bool late: row.modelData.due > 0 && !row.modelData.done && row.modelData.due < root.nowMs

                visible: row.modelData.due > 0
                anchors.right: parent.right
                anchors.rightMargin: rowHot.hovered || removeHot.hovered ? 38 : 10
                anchors.verticalCenter: parent.verticalCenter
                text: TaskReminders.label(row.modelData.due, root.nowMs)
                size: 11
                font.weight: Font.DemiBold
                color: late ? Theme.error : row.modelData.done ? Theme.muted : Theme.accent
            }
            Label {
                x: 42
                width: parent.width - x - (dueLabel.visible ? dueLabel.implicitWidth + 16 + dueLabel.anchors.rightMargin : 38)
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.text
                color: row.modelData.done ? Theme.muted : Theme.text
                font.strikeout: row.modelData.done
                size: 14
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: 13
                opacity: rowHot.hovered || removeHot.hovered ? 1 : 0
                color: removeHot.hovered ? Theme.error : Qt.alpha(Theme.text, 0.08)

                Icon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 11
                    color: removeHot.hovered ? Theme.pill : Theme.muted
                }
                WidgetHot {
                    id: removeHot

                    anchors.fill: parent
                    onClicked: root.store(root.tasks.filter((t, i) => i !== row.modelData.index))
                }
            }
        }
    }

    Rectangle {
        x: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: parent.width - 28
        height: 40
        radius: 14
        color: Qt.alpha(Theme.text, field.activeFocus ? 0.1 : 0.06)
        border.width: 1
        border.color: field.activeFocus ? Theme.accent : Qt.alpha(Theme.text, 0.06)

        Rectangle {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 14
            color: Qt.alpha(Theme.accent, 0.18)

            Icon {
                anchors.centerIn: parent
                name: "plus"
                size: 14
                color: Theme.accent
            }
        }
        TextInput {
            id: field

            x: 44
            width: parent.width - x - 12
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
                text: Tr.t("New task") + "   @18:00"
                color: Theme.muted
                size: 14
            }
        }
    }
}
