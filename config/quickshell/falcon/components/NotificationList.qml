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

    // Ids of the cards flying away, so that a header goes together with the last card of its app.
    property var gone: ({})

    // Notifications of one app stay together. The app with the newest one comes first.
    readonly property var groups: {
        const all = [];
        for (const item of Toasts.history) {
            let group = all.find(g => g.app === item.app);
            if (!group) {
                group = {
                    app: item.app,
                    items: []
                };
                all.push(group);
            }
            group.items.push(item);
        }
        return all;
    }
    // A header is a row of its own. Had it been part of a group's first card, removing that card would
    // make the next one taller while the list is moving, and the cards below would stay where they were.
    readonly property var rows: groups.reduce((all, g) => all.concat([{
                id: "app:" + g.app,
                app: g.app,
                isHeader: true
            }], g.items), [])
    readonly property var rowsById: {
        const byId = {};
        for (const row of rows)
            byId[row.id] = row;
        return byId;
    }
    readonly property var rowIds: rows.map(row => row.id)
    readonly property var cardIds: groups.reduce((all, g) => all.concat(g.items.map(item => item.id)), [])
    // For each app: the ids of its cards.
    readonly property var groupIds: {
        const ids = {};
        for (const g of groups)
            ids[g.app] = g.items.map(item => item.id);
        return ids;
    }

    onCardIdsChanged: {
        const still = {};
        for (const id of cardIds) {
            if (gone[id])
                still[id] = true;
        }
        gone = still;
    }

    signal sweep(var ids, int first)

    function clearAll() {
        clearIds(cardIds, Math.max(0, list.indexAt(10, list.contentY + 4)));
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
        anchors.rightMargin: 18
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

        // Plain ids: a card keeps its delegate across changes, and a removal moves the others.
        model: ScriptModel {
            values: root.rowIds
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
            // A delegate outlives its row for a moment when the row is removed.
            readonly property var row: root.rowsById[modelData] || ({})
            readonly property bool isHeader: row.isHeader === true
            readonly property var groupCards: root.groupIds[row.app] || []

            // dir is -1 or 1. The card only flies here, the model removes it afterward.
            function leave(dir, delay, swiped) {
                if (leaving)
                    return;
                leaving = true;
                root.gone = Object.assign({}, root.gone, {
                    [modelData]: true
                });
                settle.stop();
                flyMove.to = dir * (width + 24);
                flyMove.duration = swiped ? 200 : root.sweepTime;
                flyMove.easing.type = swiped ? Easing.OutCubic : Easing.InCubic;
                flyPause.duration = delay;
                fly.swiped = swiped;
                fly.restart();
            }

            width: ListView.view.width
            // The list's spacing lies between a header and its first card.
            height: isHeader ? 20 : card.height

            Item {
                visible: note.isHeader
                width: parent.width
                height: parent.height
                opacity: note.groupCards.every(id => root.gone[id]) ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }

                Label {
                    x: 4
                    width: parent.width - 34
                    anchors.verticalCenter: parent.verticalCenter
                    text: (note.row.app || Tr.t("Other")) + (note.groupCards.length > 1 ? " · " + note.groupCards.length : "")
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
                    onClicked: root.clearIds(note.groupCards, note.index)
                }
            }

            Connections {
                target: root

                function onSweep(ids, first) {
                    if (ids.includes(note.modelData))
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
                            Toasts.forget([note.modelData]);
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

                visible: !note.isHeader
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
                            text: note.row.title || ""
                            size: 13
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Label {
                            id: noteTime

                            anchors.right: parent.right
                            text: note.row.title ? Toasts.timeLabel(note.row) : ""
                            color: Theme.muted
                            size: 12
                        }
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: note.row.sub || ""
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
