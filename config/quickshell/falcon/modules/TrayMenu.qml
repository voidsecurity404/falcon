import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// Tray menyusi QML'da chiziladi. Tizim menyusi (item.display) dastur yopilganda shell'ni yiqitardi.
Rectangle {
    id: root

    property bool shown: false
    property var stack: []

    readonly property var entries: stack.length > 0 ? stack[stack.length - 1].opener.children : rootOpener.children

    function closeLevels() {
        for (const level of stack)
            level.opener.destroy();
        stack = [];
    }

    function push(entry) {
        stack = stack.concat([
            {
                title: entry.text,
                opener: openerComponent.createObject(root, {
                    menu: entry
                })
            }
        ]);
    }

    function pop() {
        const last = stack[stack.length - 1];
        stack = stack.slice(0, -1);
        last.opener.destroy();
    }

    width: 300
    height: column.implicitHeight + 16
    radius: 15
    color: Theme.pill
    visible: shown
    onShownChanged: {
        if (!shown)
            closeLevels();
    }

    Component {
        id: openerComponent

        QsMenuOpener {}
    }

    QsMenuOpener {
        id: rootOpener

        menu: root.shown && Ui.trayItem ? Ui.trayItem.menu : null
    }

    // Dastur yopilsa uning menyusi ham yopiladi.
    Connections {
        target: SystemTray.items
        function onValuesChanged() {
            if (Ui.popup === "tray" && SystemTray.items.values.indexOf(Ui.trayItem) < 0) {
                Ui.popup = "";
                Ui.trayItem = null;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: column

        x: 8
        y: 8
        width: parent.width - 16

        Rectangle {
            visible: root.stack.length > 0
            width: parent.width
            height: 30
            radius: 8
            color: backArea.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent"

            Label {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 10
                width: parent.width
                text: "‹  " + (root.stack.length > 0 ? root.stack[root.stack.length - 1].title : "")
                color: Theme.muted
                size: 13
            }
            MouseArea {
                id: backArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pop()
            }
        }

        Repeater {
            model: root.entries

            delegate: Item {
                id: entry

                required property var modelData

                width: column.width
                height: modelData.isSeparator ? 9 : 30

                Rectangle {
                    visible: entry.modelData.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.text, 0.1)
                }

                Rectangle {
                    visible: !entry.modelData.isSeparator
                    anchors.fill: parent
                    radius: 8
                    color: entryArea.containsMouse && entry.modelData.enabled ? Qt.alpha(Theme.text, 0.08) : "transparent"
                    opacity: entry.modelData.enabled ? 1 : 0.45

                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entry.modelData.checkState === Qt.Checked
                        name: "check"
                        size: 13
                        color: Theme.accent
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.right: arrow.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(entry.modelData.text || "").replace(/_/g, "")
                        size: 13
                    }
                    Label {
                        id: arrow

                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.hasChildren ? "›" : ""
                        color: Theme.muted
                    }
                    MouseArea {
                        id: entryArea

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: entry.modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                root.push(entry.modelData);
                            } else {
                                entry.modelData.triggered();
                                Ui.popup = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
