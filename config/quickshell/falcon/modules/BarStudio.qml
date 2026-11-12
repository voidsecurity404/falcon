import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Top of the Panel page: a working copy of the top bar on a strip of the wallpaper, made of the
// same BarIsland parts, scaled down to fit. A part is dragged with the mouse to another place or
// island; dropped in Hidden it leaves the bar, and a hidden one is dragged back or clicked to
// return home. Every change goes to the real bar at once through BarLayout.
Item {
    id: root

    // The drag in progress: which part, the pointer in this item's coordinates, and where it would land.
    property string dragId: ""
    property point pointer: Qt.point(0, 0)
    property string dropZone: ""
    property int dropIndex: 0
    property rect dropMark: Qt.rect(0, 0, 0, 0)
    // The part under the pointer in the preview, named under the bar.
    property string hoverId: ""
    property rect hoverRect: Qt.rect(0, 0, 0, 0)

    readonly property var islands: [previewLeft, previewCenter, previewRight]

    // The preview stage in the bar's own pixels, scaled to the card.
    readonly property real gapMin: 14
    // The sides of the strip are kept narrow, so the islands get the room.
    readonly property real edge: Math.min(BarLayout.sideGap, 8)
    readonly property real stageWidth: Math.max(stageArea.width, previewLeft.width + previewCenter.width + previewRight.width + 2 * edge + 2 * gapMin)
    readonly property real stageScale: stageArea.width > 0 ? Math.min(1, stageArea.width / stageWidth) : 1
    readonly property real stageHeight: BarLayout.height + 2 * Math.max(8, BarLayout.edgeGap)

    function partsOf(zone) {
        return zone === "hidden" ? BarLayout.hidden : BarLayout[zone];
    }

    function begin(id) {
        hoverId = "";
        dragId = id;
    }
    function moveTo(p) {
        pointer = p;
        aim();
    }
    function cancel() {
        dragId = "";
        dropZone = "";
    }
    function hover(id, item) {
        if (dragId !== "")
            return;
        const p = item.mapToItem(root, 0, 0);
        hoverRect = Qt.rect(p.x, p.y, item.width * stageScale, item.height * stageScale);
        hoverId = id;
    }
    function unhover(id) {
        if (hoverId === id)
            hoverId = "";
    }

    // Finds the island or the hidden box under the pointer, the place in it and the line that shows it.
    function aim() {
        dropZone = "";
        // Hidden parts.
        const h = hiddenBox.mapFromItem(root, pointer.x, pointer.y);
        if (h.x >= 0 && h.y >= 0 && h.x <= hiddenBox.width && h.y <= hiddenBox.height) {
            dropZone = "hidden";
            dropIndex = 0;
            return;
        }
        // Anywhere over the bar strip: the nearest island across.
        const s = stageArea.mapFromItem(root, pointer.x, pointer.y);
        if (s.x < -20 || s.y < -20 || s.x > stageArea.width + 20 || s.y > stageArea.height + 20)
            return;
        let best = null;
        let bestGap = Infinity;
        for (const island of islands) {
            const p = island.mapFromItem(root, pointer.x, pointer.y);
            const gap = p.x < 0 ? -p.x : p.x > island.width ? p.x - island.width : 0;
            if (gap < bestGap) {
                bestGap = gap;
                best = island;
            }
        }
        if (!best)
            return;
        dropZone = best.zone;
        const slots = best.slots().filter((d, i) => best.parts[i] !== dragId);
        let index = 0;
        for (const d of slots) {
            const q = d.mapFromItem(root, pointer.x, pointer.y);
            if (q.x > d.width / 2)
                index++;
        }
        dropIndex = index;
        const top = best.mapToItem(root, 0, 0).y + 5 * stageScale;
        const tall = (best.height - 10) * stageScale;
        if (slots.length === 0) {
            const o = best.mapToItem(root, best.width / 2, 0);
            dropMark = Qt.rect(o.x - 1.5, top, 3, tall);
        } else if (index < slots.length) {
            const o = slots[index].mapToItem(root, -BarLayout.spacing / 2, 0);
            dropMark = Qt.rect(o.x - 1.5, top, 3, tall);
        } else {
            const last = slots[slots.length - 1];
            const o = last.mapToItem(root, last.width + BarLayout.spacing / 2, 0);
            dropMark = Qt.rect(o.x - 1.5, top, 3, tall);
        }
    }
    function drop() {
        if (dragId !== "" && dropZone !== "") {
            // The index counts the parts without the dragged one; place() expects it counted
            // with the part still in its list.
            const list = partsOf(dropZone);
            const from = list.indexOf(dragId);
            BarLayout.place(dragId, dropZone, from >= 0 && from < dropIndex ? dropIndex + 1 : dropIndex);
        }
        dragId = "";
        dropZone = "";
    }

    implicitHeight: column.implicitHeight

    // A hidden part: dragged back onto the bar, or put back home with a click.
    component Chip: Rectangle {
        id: chip

        property string partId: ""
        readonly property var part: BarLayout.byId[partId] || ({})

        width: chipRow.implicitWidth + 20
        height: 32
        radius: 11
        opacity: root.dragId === partId ? 0.3 : 1
        color: Qt.alpha(Theme.text, area.containsMouse ? 0.12 : 0.05)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.12)

        Row {
            id: chipRow

            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.part.icon || "panel"
                size: 15
                color: Theme.muted
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t(chip.part.title || chip.partId)
                size: 12
                color: Theme.text
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
                if (root.dragId === "" && Math.hypot(mouse.x - start.x, mouse.y - start.y) > 5)
                    root.begin(chip.partId);
                if (root.dragId === chip.partId)
                    root.moveTo(mapToItem(root, mouse.x, mouse.y));
            }
            onReleased: {
                if (root.dragId === chip.partId)
                    root.drop();
            }
            onCanceled: root.cancel()
            onClicked: {
                if (root.dragId === "")
                    BarLayout.restore(chip.partId);
            }
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
                    text: Tr.t("This is your bar. Drag any part with the mouse to another place or island, or down to Hidden to take it off.")
                    size: 12
                    color: Theme.muted
                }

                // The bar itself on the top of the wallpaper.
                ClippingRectangle {
                    id: stageArea

                    width: parent.width
                    height: Math.round(root.stageHeight * root.stageScale)
                    radius: 14
                    color: Theme.glassBase

                    Image {
                        anchors.fill: parent
                        source: Wallpapers.shownImage !== "" ? "file://" + Wallpapers.shownImage : ""
                        fillMode: Image.PreserveAspectCrop
                        verticalAlignment: Image.AlignTop
                        sourceSize.width: 1400
                        asynchronous: true
                        cache: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.alpha("#000000", 0.12)
                    }

                    Item {
                        id: stage

                        width: root.stageWidth
                        height: root.stageHeight
                        scale: root.stageScale
                        transformOrigin: Item.TopLeft
                        // Text drawn smaller than its size turns rough, so the stage is reduced as a picture.
                        layer.enabled: root.stageScale < 0.99
                        layer.mipmap: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(Math.ceil(width), Math.ceil(height))

                        GlassIsland {
                            x: root.edge
                            y: Math.max(8, BarLayout.edgeGap)
                            width: stage.width - 2 * root.edge
                            visible: BarLayout.joined
                            wheelEnabled: false
                        }
                        BarIsland {
                            id: previewLeft

                            plain: BarLayout.joined
                            zone: "left"
                            preview: true
                            studio: root
                            x: root.edge
                            y: Math.max(8, BarLayout.edgeGap)
                        }
                        BarIsland {
                            id: previewRight

                            plain: BarLayout.joined
                            zone: "right"
                            preview: true
                            studio: root
                            x: stage.width - width - root.edge
                            y: Math.max(8, BarLayout.edgeGap)
                        }
                        BarIsland {
                            id: previewCenter

                            plain: BarLayout.joined
                            zone: "center"
                            preview: true
                            studio: root
                            // Centered like the real one, but never over its neighbours.
                            x: Math.max(previewLeft.x + previewLeft.width + root.gapMin, Math.min(previewRight.x - width - root.gapMin, Math.round((stage.width - width) / 2)))
                            y: Math.max(8, BarLayout.edgeGap)
                        }
                    }
                }

                // The name of the part under the pointer.
                Item {
                    width: parent.width
                    height: 18

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.dragId !== "" ? Tr.t("Drop it where the line is") : root.hoverId !== "" ? Tr.t((BarLayout.byId[root.hoverId] || {}).title || "") : ""
                        size: 12
                        color: root.dragId !== "" ? Theme.accent : Theme.text
                    }
                }

                Rectangle {
                    id: hiddenBox

                    readonly property bool aimed: root.dragId !== "" && root.dropZone === "hidden"

                    width: parent.width
                    readonly property var plainHidden: BarLayout.hidden.filter(id => !(BarLayout.byId[id] || {}).net)
                    readonly property var netHidden: BarLayout.hidden.filter(id => !!(BarLayout.byId[id] || {}).net)

                    height: Math.max(84, (netHidden.length > 0 ? netFlow.y + netFlow.implicitHeight : hiddenFlow.y + hiddenFlow.implicitHeight) + 12)
                    radius: 14
                    color: aimed ? Qt.alpha(Theme.error, 0.1) : Qt.alpha(Theme.glassBase, 0.35)
                    border.width: 1
                    border.color: aimed ? Qt.alpha(Theme.error, 0.55) : Qt.alpha(Theme.text, 0.1)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Label {
                        id: hiddenTitle

                        x: 12
                        y: 9
                        text: Tr.t("Hidden")
                        size: 11
                        font.weight: Font.Medium
                        color: Theme.muted
                    }
                    Flow {
                        id: hiddenFlow

                        x: 10
                        y: hiddenTitle.y + hiddenTitle.height + 8
                        width: hiddenBox.width - 20
                        spacing: 6

                        Repeater {
                            model: hiddenBox.plainHidden

                            delegate: Chip {
                                required property string modelData

                                partId: modelData
                            }
                        }
                    }
                    // Network and security readings, kept apart so the ordinary parts stay easy to find.
                    Label {
                        id: netTitle

                        visible: hiddenBox.netHidden.length > 0
                        x: 12
                        y: hiddenFlow.y + Math.max(hiddenFlow.implicitHeight, 20) + 12
                        text: Tr.t("Network and security")
                        size: 11
                        font.weight: Font.Medium
                        color: Theme.muted
                    }
                    Flow {
                        id: netFlow

                        visible: netTitle.visible
                        x: 10
                        y: netTitle.y + netTitle.height + 8
                        width: hiddenBox.width - 20
                        spacing: 6

                        Repeater {
                            model: hiddenBox.netHidden

                            delegate: Chip {
                                required property string modelData

                                partId: modelData
                            }
                        }
                    }
                    Label {
                        visible: hiddenBox.plainHidden.length === 0
                        x: 12
                        y: hiddenFlow.y + 7
                        text: root.dragId !== "" ? Tr.t("Drop here to take it off the bar") : Tr.t("Everything is on the bar")
                        size: 12
                        color: Qt.alpha(Theme.muted, 0.8)
                    }
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

    // Above everything: the outline of the part under the pointer, the line where a dragged part
    // would land, and the part following the pointer.
    Item {
        anchors.fill: parent
        z: 50

        Rectangle {
            visible: root.hoverId !== "" && root.dragId === ""
            x: root.hoverRect.x - 3
            y: root.hoverRect.y - 3
            width: root.hoverRect.width + 6
            height: root.hoverRect.height + 6
            radius: height / 2
            color: Qt.alpha(Theme.accent, 0.12)
            border.width: 1.5
            border.color: Theme.accent
        }
        Rectangle {
            visible: root.dragId !== "" && root.dropZone !== "" && root.dropZone !== "hidden"
            x: root.dropMark.x
            y: root.dropMark.y
            width: root.dropMark.width
            height: root.dropMark.height
            radius: 1.5
            color: Theme.accent
        }
        Rectangle {
            visible: root.dragId !== ""
            // Below the pointer, so the line where it lands stays in sight.
            x: root.pointer.x - width / 2
            y: root.pointer.y + 16
            width: ghostRow.implicitWidth + 22
            height: 34
            radius: 12
            color: Theme.accent
            opacity: 0.94

            Row {
                id: ghostRow

                anchors.centerIn: parent
                spacing: 7

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: (BarLayout.byId[root.dragId] || {}).icon || "panel"
                    size: 15
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
