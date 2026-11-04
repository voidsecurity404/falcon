import QtQuick
import Quickshell
import qs.components
import qs.services

// Notification history: the newest is on top and the list scrolls.
// A card can be dragged sideways to dismiss it. Clear sends all of them away, top one first.
Rectangle {
    id: root

    readonly property int sweepStep: 35
    readonly property int sweepTime: 280
    readonly property int sweepMax: 10

    property bool clearing: false
    property var clearingIds: []

    // Notifications of one app stay together. The app with the newest one comes first.
    readonly property var rows: {
        const groups = [];
        for (const item of Toasts.history) {
            let group = groups.find(g => g.app === item.app);
            if (!group) {
                group = {
                    app: item.app,
                    items: []
                };
                groups.push(group);
            }
            group.items.push(item);
        }
        return groups.reduce((all, g) => all.concat(g.items), []);
    }
    // For each notification id: the ids of its group, and whether it comes first there.
    readonly property var groupInfo: {
        const info = {};
        for (const item of rows) {
            const ids = rows.filter(r => r.app === item.app).map(r => r.id);
            info[item.id] = {
                ids: ids,
                first: ids[0] === item.id
            };
        }
        return info;
    }

    signal sweep(var ids, int first)

    function clearAll() {
        clearIds(rows.map(h => h.id), Math.max(0, list.indexAt(10, list.contentY + 4)));
    }

    function clearIds(ids, first) {
        if (clearing || ids.length === 0)
            return;
        clearing = true;
        clearingIds = ids;
        sweep(clearingIds, first);
        // Cards leave the model together, so the ones still flying do not jump.
        clearTimer.interval = Math.min(clearingIds.length, sweepMax + 1) * sweepStep + sweepTime;
        clearTimer.restart();
    }

    radius: 22
    color: Qt.alpha(Theme.text, 0.05)

    Timer {
        id: clearTimer

        onTriggered: {
            Toasts.forget(root.clearingIds);
            root.clearing = false;
        }
    }

    Label {
        x: 18
        height: 54
        verticalAlignment: Text.AlignVCenter
        text: Tr.t("Notifications")
        size: 15
        font.weight: Font.Medium
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: 62
        height: 54
        verticalAlignment: Text.AlignVCenter
        opacity: Toasts.history.length > 0 && !root.clearing ? 1 : 0
        visible: opacity > 0
        text: Tr.t("Clear")
        color: clearArea.containsMouse ? Theme.text : Theme.muted
        size: 13

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        MouseArea {
            id: clearArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearAll()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 10
        opacity: Toasts.history.length === 0 ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "bell"
            size: 30
            color: Qt.alpha(Theme.text, 0.3)
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("No notifications yet")
            color: Qt.alpha(Theme.text, 0.45)
            size: 13
        }
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.topMargin: 54
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 10
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.clearing

        // Cards keep their delegates across changes, matched by id.
        model: ScriptModel {
            values: root.rows
            objectProp: "id"
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 200
            }
        }
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                to: 1
                duration: 200
            }
        }

        delegate: Item {
            id: note

            required property var modelData
            required property int index

            property bool leaving: false
            property real lastSpeed: 0
            readonly property var group: root.groupInfo[modelData.id] || ({
                    ids: [],
                    first: false
                })
            readonly property int headerHeight: group.first ? 26 : 0

            // dir is -1 or 1. The card only flies here, the model removes it afterward.
            function leave(dir, delay, swiped) {
                if (leaving)
                    return;
                leaving = true;
                settle.stop();
                flyMove.to = dir * (width + 24);
                flyMove.duration = swiped ? 200 : root.sweepTime;
                flyMove.easing.type = swiped ? Easing.OutCubic : Easing.InCubic;
                flyPause.duration = delay;
                fly.swiped = swiped;
                fly.restart();
            }

            width: ListView.view.width
            height: card.height + headerHeight

            Item {
                visible: note.group.first
                width: parent.width
                height: note.headerHeight
                opacity: 1 - 0.9 * Math.min(1, Math.abs(card.x) / Math.max(1, card.width))

                Label {
                    x: 4
                    width: parent.width - 34
                    anchors.verticalCenter: parent.verticalCenter
                    text: (note.modelData.app || Tr.t("Other")) + (note.group.ids.length > 1 ? " · " + note.group.ids.length : "")
                    color: Theme.muted
                    size: 12
                    elide: Text.ElideRight
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    name: "close"
                    size: 12
                    color: groupClear.containsMouse ? Theme.text : Theme.muted
                }
                MouseArea {
                    id: groupClear

                    anchors.right: parent.right
                    width: 26
                    height: parent.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearIds(note.group.ids, note.index)
                }
            }

            Connections {
                target: root

                function onSweep(ids, first) {
                    if (ids.includes(note.modelData.id))
                        note.leave(1, Math.min(Math.max(0, note.index - first), root.sweepMax) * root.sweepStep, false);
                }
            }

            SequentialAnimation {
                id: fly

                property bool swiped: false

                PauseAnimation {
                    id: flyPause
                }
                NumberAnimation {
                    id: flyMove

                    target: card
                    property: "x"
                }
                ScriptAction {
                    script: {
                        if (fly.swiped)
                            Toasts.forget([note.modelData.id]);
                    }
                }
            }
            NumberAnimation {
                id: settle

                target: card
                property: "x"
                to: 0
                duration: 240
                easing.type: Easing.OutCubic
            }

            Rectangle {
                id: card

                y: note.headerHeight
                width: parent.width
                height: noteText.implicitHeight + 20
                radius: 14
                color: Qt.alpha(Theme.text, 0.06)
                opacity: 1 - 0.9 * Math.min(1, Math.abs(x) / Math.max(1, width))

                HoverHandler {
                    cursorShape: Qt.OpenHandCursor
                }
                DragHandler {
                    id: swipe

                    target: null
                    yAxis.enabled: false
                    enabled: !note.leaving && !root.clearing
                    cursorShape: Qt.ClosedHandCursor
                    onActiveChanged: {
                        if (active) {
                            settle.stop();
                            return;
                        }
                        if (note.leaving)
                            return;
                        const x = card.x;
                        const flung = Math.abs(note.lastSpeed) > 900 && note.lastSpeed * x > 0;
                        if (Math.abs(x) > card.width * 0.35 || flung)
                            note.leave(x < 0 ? -1 : 1, 0, true);
                        else
                            settle.restart();
                    }
                    onActiveTranslationChanged: {
                        if (active) {
                            card.x = activeTranslation.x;
                            note.lastSpeed = centroid.velocity.x;
                        }
                    }
                }

                Column {
                    id: noteText

                    x: 12
                    y: 10
                    width: parent.width - 24
                    spacing: 3

                    Item {
                        width: parent.width
                        height: noteTitle.implicitHeight

                        Label {
                            id: noteTitle

                            anchors.left: parent.left
                            anchors.right: noteTime.left
                            anchors.rightMargin: 8
                            text: note.modelData.title
                            size: 13
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Label {
                            id: noteTime

                            anchors.right: parent.right
                            text: Toasts.timeLabel(note.modelData)
                            color: Theme.muted
                            size: 12
                        }
                    }
                    Label {
                        width: parent.width
                        visible: note.modelData.sub !== ""
                        text: note.modelData.sub
                        color: Theme.muted
                        size: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
