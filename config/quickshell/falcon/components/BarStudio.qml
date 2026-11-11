import QtQuick
import qs.components
import qs.services

// Top of the Panel page: what the bar shows and where. Three boxes stand for the left, middle and
// right islands, a fourth holds the hidden parts. A part is dragged to another place or island,
// the cross on a part hides it, and a click on a hidden part puts it back where it belongs. Every
// change goes to the bar at once through BarLayout.
Item {
    id: root

    readonly property var boxes: [
        {
            zone: "left",
            title: Tr.t("Left island")
        },
        {
            zone: "center",
            title: Tr.t("Middle island")
        },
        {
            zone: "right",
            title: Tr.t("Right island")
        }
    ]

    // The drag in progress: which part, the pointer in this item's coordinates, and where it would land.
    property string dragId: ""
    property point pointer: Qt.point(0, 0)
    property string dropZone: ""
    property int dropIndex: 0
    property rect dropMark: Qt.rect(0, 0, 0, 0)

    function partsOf(zone) {
        return zone === "hidden" ? BarLayout.hidden : BarLayout[zone];
    }

    // Finds the box and the place under the pointer and the line that shows it.
    function aim() {
        dropZone = "";
        for (const box of zoneBoxes()) {
            const p = box.mapFromItem(root, pointer.x, pointer.y);
            if (p.x < 0 || p.y < 0 || p.x > box.width || p.y > box.height)
                continue;
            dropZone = box.zone;
            const chips = box.chips().filter(c => c.partId !== dragId);
            let index = 0;
            for (const c of chips) {
                const q = c.mapFromItem(root, pointer.x, pointer.y);
                const before = q.y > c.height || (q.y >= 0 && q.x > c.width / 2);
                if (before)
                    index++;
            }
            dropIndex = index;
            if (box.zone === "hidden") {
                dropMark = Qt.rect(0, 0, 0, 0);
            } else if (chips.length === 0) {
                const o = box.flowItem.mapToItem(root, 0, 0);
                dropMark = Qt.rect(o.x, o.y, 3, 30);
            } else if (index < chips.length) {
                const o = chips[index].mapToItem(root, 0, 0);
                dropMark = Qt.rect(o.x - 5, o.y, 3, chips[index].height);
            } else {
                const last = chips[chips.length - 1];
                const o = last.mapToItem(root, last.width, 0);
                dropMark = Qt.rect(o.x + 2, o.y, 3, last.height);
            }
            return;
        }
    }
    function zoneBoxes() {
        const out = [];
        for (let i = 0; i < islands.count; i++)
            out.push(islands.itemAt(i));
        out.push(hiddenBox);
        return out;
    }
    function drop() {
        if (dragId !== "" && dropZone !== "") {
            // The index counts the parts without the dragged one, which is what place() expects
            // after it takes the part out.
            const list = partsOf(dropZone);
            const from = list.indexOf(dragId);
            BarLayout.place(dragId, dropZone, from >= 0 && from < dropIndex ? dropIndex + 1 : dropIndex);
        }
        dragId = "";
        dropZone = "";
    }

    implicitHeight: column.implicitHeight

    // One part as a chip. It is dragged, or hidden with its cross, or put back with a click.
    component Chip: Rectangle {
        id: chip

        property string partId: ""
        property bool isHidden: false
        // The widest the chip may be: its box's inner width.
        property real room: 400
        readonly property var part: BarLayout.byId[partId] || ({})

        width: chipRow.implicitWidth + 20
        height: 30
        radius: 10
        opacity: root.dragId === partId ? 0.3 : 1
        color: isHidden ? Qt.alpha(Theme.text, area.containsMouse ? 0.1 : 0.04) : Qt.alpha(Theme.accent, area.containsMouse ? 0.3 : 0.18)
        border.width: 1
        border.color: isHidden ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.accent, 0.35)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Row {
            id: chipRow

            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.isHidden ? "plus" : chip.part.icon || "panel"
                size: 14
                color: chip.isHidden ? Theme.muted : Theme.accent
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, chip.room - 60)
                elide: Text.ElideRight
                text: Tr.t(chip.part.title || chip.partId)
                size: 12
                color: chip.isHidden ? Theme.muted : Theme.text
            }
            // Room for the cross, shown on hover.
            Item {
                visible: !chip.isHidden
                width: 14
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    opacity: area.containsMouse || crossArea.containsMouse ? 1 : 0
                    color: crossArea.containsMouse ? Qt.alpha(Theme.error, 0.3) : Qt.alpha(Theme.text, 0.1)

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 11
                        color: crossArea.containsMouse ? Theme.error : Theme.text
                    }
                }
            }
        }

        MouseArea {
            id: area

            property point start: Qt.point(0, 0)

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: root.dragId !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: mouse => start = Qt.point(mouse.x, mouse.y)
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                if (root.dragId === "" && Math.hypot(mouse.x - start.x, mouse.y - start.y) > 6)
                    root.dragId = chip.partId;
                if (root.dragId === chip.partId) {
                    root.pointer = mapToItem(root, mouse.x, mouse.y);
                    root.aim();
                }
            }
            onReleased: {
                if (root.dragId === chip.partId)
                    root.drop();
            }
            onCanceled: root.dragId = ""
            onClicked: {
                if (chip.isHidden)
                    BarLayout.restore(chip.partId);
            }
        }
        // Above the chip's own area, so a press on the cross hides instead of starting a drag.
        MouseArea {
            id: crossArea

            visible: !chip.isHidden && root.dragId === ""
            x: chip.width - 26
            width: 22
            height: chip.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: BarLayout.hide(chip.partId)
        }
    }

    // One drop box: a title and its chips.
    component Box: Rectangle {
        id: box

        property string zone: ""
        property string title: ""
        property alias flowItem: flow
        readonly property bool aimed: root.dragId !== "" && root.dropZone === zone

        function chips() {
            const out = [];
            for (const c of flow.children)
                if (c.partId !== undefined && c.visible)
                    out.push(c);
            return out;
        }

        height: Math.max(92, flow.y + flow.implicitHeight + 12)
        radius: 14
        color: aimed ? Qt.alpha(Theme.accent, 0.1) : Qt.alpha(Theme.glassBase, 0.35)
        border.width: 1
        border.color: aimed ? Qt.alpha(Theme.accent, 0.6) : Qt.alpha(Theme.text, 0.1)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Label {
            id: boxTitle

            x: 12
            y: 9
            text: box.title
            size: 11
            font.weight: Font.Medium
            color: Theme.muted
        }
        Flow {
            id: flow

            x: 10
            y: boxTitle.y + boxTitle.height + 8
            width: box.width - 20
            spacing: 6

            Repeater {
                model: root.partsOf(box.zone)

                delegate: Chip {
                    required property string modelData

                    partId: modelData
                    isHidden: box.zone === "hidden"
                    room: flow.width
                }
            }
        }
        Label {
            visible: root.partsOf(box.zone).length === 0
            x: 12
            y: flow.y + 6
            width: box.width - 24
            wrapMode: Text.Wrap
            text: box.zone === "hidden" ? Tr.t("Everything is on the bar") : Tr.t("Empty: this island is not shown")
            size: 12
            color: Qt.alpha(Theme.muted, 0.8)
        }
    }

    Column {
        id: column

        width: root.width
        spacing: 7

        Label {
            x: 6
            text: Tr.t("Parts of the bar")
            color: Theme.muted
            size: 12
            font.weight: Font.Medium
        }

        Rectangle {
            width: root.width
            height: inner.implicitHeight + 32
            radius: 18
            color: Qt.tint(Qt.alpha(Theme.glassBase, 0.3), Qt.alpha(Theme.text, 0.045))
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.08)

            Column {
                id: inner

                x: 16
                y: 16
                width: parent.width - 32
                spacing: 12

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: Tr.t("Drag a part to another place or island. The cross takes it off the bar, a click on a hidden part brings it back.")
                    size: 12
                    color: Theme.muted
                }

                Row {
                    id: islandRow

                    width: parent.width
                    spacing: 10

                    Repeater {
                        id: islands

                        model: root.boxes

                        delegate: Box {
                            required property var modelData

                            zone: modelData.zone
                            title: modelData.title
                            width: (islandRow.width - islandRow.spacing * 2) / 3
                        }
                    }
                }

                Box {
                    id: hiddenBox

                    zone: "hidden"
                    title: Tr.t("Hidden")
                    width: parent.width
                    height: Math.max(70, flowItem.y + flowItem.implicitHeight + 12)
                }

                Row {
                    spacing: 8

                    Rectangle {
                        width: resetLabel.implicitWidth + 28
                        height: 32
                        radius: 11
                        color: resetArea.containsMouse ? Qt.alpha(Theme.accent, 0.32) : Qt.alpha(Theme.accent, 0.18)

                        Label {
                            id: resetLabel

                            anchors.centerIn: parent
                            text: Tr.t("Default layout")
                            size: 12
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: resetArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BarLayout.resetLayout()
                        }
                    }
                    Rectangle {
                        width: lookLabel.implicitWidth + 28
                        height: 32
                        radius: 11
                        color: lookArea.containsMouse ? Qt.alpha(Theme.text, 0.14) : Qt.alpha(Theme.text, 0.07)

                        Label {
                            id: lookLabel

                            anchors.centerIn: parent
                            text: Tr.t("Default sizes")
                            size: 12
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: lookArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BarLayout.resetLook()
                        }
                    }
                }
            }
        }

    }

    // The line where the part would land, and the part following the pointer, above the boxes.
    Item {
        anchors.fill: parent
        z: 50

        Rectangle {
            visible: root.dragId !== "" && root.dropZone !== "" && root.dropZone !== "hidden"
            x: root.dropMark.x
            y: root.dropMark.y
            width: root.dropMark.width
            height: root.dropMark.height
            radius: 1.5
            color: Theme.accent
            z: 50
        }
        Rectangle {
            visible: root.dragId !== ""
            x: root.pointer.x - width / 2
            y: root.pointer.y - height / 2
            z: 60
            width: ghostRow.implicitWidth + 22
            height: 32
            radius: 11
            color: Theme.accent
            opacity: 0.92

            Row {
                id: ghostRow

                anchors.centerIn: parent
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: (BarLayout.byId[root.dragId] || {}).icon || "panel"
                    size: 14
                    color: Theme.accentText
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t((BarLayout.byId[root.dragId] || {}).title || "")
                    size: 12
                    font.weight: Font.Medium
                    color: Theme.accentText
                }
            }
        }
    }
}
