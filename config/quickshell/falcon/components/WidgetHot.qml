import QtQuick
import qs.services

// A pressable spot of a desktop widget. The widget is drawn by its face, which takes no input, while a
// see-through copy takes the clicks; both read Widgets.pointer, so hover and press show on the face.
Item {
    id: hot

    signal clicked
    // For sliders: where along the width the pointer is pressed or dragged, 0 to 1.
    signal slid(real share)
    property bool slider: false
    property bool vertical: false
    property int cursor: Qt.PointingHandCursor
    property Item base: null

    readonly property var ptr: Widgets.pointer
    readonly property bool hovered: {
        const p = ptr;
        if (!base || !visible || p.id === "" || p.id !== base.widgetId)
            return false;
        const q = base.mapToItem(hot, p.x, p.y);
        return q.x >= 0 && q.y >= 0 && q.x < width && q.y < height;
    }
    readonly property bool down: area.pressed || (hovered && ptr.down)

    Component.onCompleted: {
        let p = parent;
        while (p && !(p.widgetRoot === true))
            p = p.parent;
        base = p;
    }

    function share(mouse) {
        return vertical ? Math.max(0, Math.min(1, 1 - mouse.y / height)) : Math.max(0, Math.min(1, mouse.x / width));
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: hot.cursor
        preventStealing: hot.slider
        onPressedChanged: Widgets.setPointerDown(pressed)
        onPressed: mouse => {
            if (hot.slider)
                hot.slid(hot.share(mouse));
        }
        onPositionChanged: mouse => {
            if (hot.slider && pressed)
                hot.slid(hot.share(mouse));
        }
        onClicked: hot.clicked()
    }
}
