import QtQuick
import qs.components
import qs.services

// One widget. It lives twice: role "face" is what you see in the backdrop, role "input" sits in
// the workspace layer and handles the pointer. The input copy shows only in edit mode or for a
// widget with something to press, while the pointer is on it.
Item {
    id: host

    required property string widgetId
    required property int areaWidth
    required property int areaHeight
    required property int topInset
    property string role: "input"
    property bool contentOn: true

    readonly property int side: 16
    readonly property bool isFace: role === "face"
    readonly property var entry: Widgets.get(widgetId)
    readonly property var info: entry ? Widgets.info(entry.type) : null
    readonly property real factor: entry ? Widgets.factor(entry.size) : 1
    readonly property var form: Widgets.formOf(entry)
    // The size being moved to. The frame grows to it while x and y already aim at the final place.
    readonly property real targetWidth: form ? form.w * factor : 0
    readonly property real targetHeight: form ? form.h * factor : 0
    // What the content is laid out for. It changes while the content is faded out.
    property var shownForm: form
    readonly property bool dragging: !isFace && mover.drag.active
    readonly property int gridStep: 16
    readonly property bool interactive: !!info && info.interactive === true
    readonly property bool holding: !isFace && interactive && (hover.hovered || (!!face.item && face.item.typing === true))
    readonly property bool showCopy: !isFace && (Widgets.editMode || (holding && !Widgets.sliding))
    readonly property bool hasContent: isFace ? contentOn : (Widgets.editMode || interactive)
    // Under the pointer the copy stays see-through and only takes the clicks, while the face goes on
    // drawing everything, because the face sits in niri's backdrop and its blur picks up its own
    // content as a soft glow the copy cannot draw. Only a widget being typed in shows its copy, so the
    // cursor and selection are seen. Then the face keeps its glass and hides only its content.
    readonly property bool typingHere: !isFace && interactive && !!face.item && face.item.typing === true
    readonly property bool copyDrawn: !isFace && (Widgets.editMode || (typingHere && !Widgets.sliding))
    readonly property real drawOpacity: isFace ? 1 : (copyDrawn ? 1 : 0)
    readonly property bool coveredHere: isFace && Widgets.hoverId === widgetId
    // Hidden only once the copy has faded in above it, so there is never a frame with neither.
    property bool contentCovered: false

    onCoveredHereChanged: {
        if (coveredHere) {
            coverDelay.restart();
        } else {
            coverDelay.stop();
            contentCovered = false;
        }
    }

    Timer {
        id: coverDelay

        interval: 150
        onTriggered: host.contentCovered = true
    }

    function snap(v, low, high) {
        return Math.max(low, Math.min(high, Math.round(v / gridStep) * gridStep));
    }

    readonly property real minX: side
    readonly property real maxX: side + Math.max(0, areaWidth - targetWidth)
    readonly property real minY: topInset
    readonly property real maxY: Math.max(topInset, areaHeight - targetHeight)

    function placeX() {
        return entry ? side + entry.fx * Math.max(0, areaWidth - targetWidth) : side;
    }
    function placeY() {
        return entry ? topInset + entry.fy * Math.max(0, areaHeight - topInset - targetHeight) : topInset;
    }

    width: targetWidth
    height: targetHeight
    visible: !!entry
    z: dragging ? 10 : 1

    Binding on x {
        when: !host.dragging
        value: host.placeX()
    }
    Binding on y {
        when: !host.dragging
        value: host.placeY()
    }

    onCopyDrawnChanged: {
        if (!isFace && !Widgets.editMode)
            Widgets.hoverId = copyDrawn ? widgetId : (Widgets.hoverId === widgetId ? "" : Widgets.hoverId);
    }
    onXChanged: report()
    onYChanged: report()
    onWidthChanged: report()
    onHeightChanged: report()

    function report() {
        if (!isFace)
            Widgets.setRect(widgetId, x, y, width, height);
    }

    onFormChanged: {
        if (form && shownForm && form.name !== shownForm.name)
            reshape.restart();
        else
            shownForm = form;
    }

    // Tarkib o'chib turganda yangi shaklga o'tadi, shunda eski tuzilish cho'zilib ko'rinmaydi.
    SequentialAnimation {
        id: reshape

        NumberAnimation {
            target: face
            property: "reshapeOpacity"
            to: 0
            duration: 110
        }
        ScriptAction {
            script: host.shownForm = host.form
        }
        NumberAnimation {
            target: face
            property: "reshapeOpacity"
            to: 1
            duration: 200
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 1.15, 0.35, 1, 1, 1]
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 1.15, 0.35, 1, 1, 1]
        }
    }
    Behavior on x {
        enabled: !host.dragging

        NumberAnimation {
            duration: 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 1.15, 0.35, 1, 1, 1]
        }
    }
    Behavior on y {
        enabled: !host.dragging

        NumberAnimation {
            duration: 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 1.15, 0.35, 1, 1, 1]
        }
    }

    HoverHandler {
        id: hover

        enabled: !host.isFace && !Widgets.editMode
    }

    // Tushish joyi: qo'yib yuborganda vidjet aynan shu yerga tushadi.
    Rectangle {
        visible: host.dragging
        x: host.snap(host.x, host.minX, host.maxX) - host.x
        y: host.snap(host.y, host.minY, host.maxY) - host.y
        width: host.width
        height: host.height
        radius: host.info && (host.info.plate || host.info.solid) ? 22 * host.factor : 18
        color: Qt.alpha(Theme.accent, 0.16)
        border.width: 2
        border.color: Theme.accent
        z: -1
    }

    // Ko'rinadigan qism
    Item {
        anchors.fill: parent
        opacity: host.drawOpacity
        // A copy nobody sees must not keep animating its content. Under the pointer it stays in place,
        // see-through, because clicks still reach items at opacity 0.
        visible: opacity > 0 || host.showCopy

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        // Yuzdagi shisha doim turadi, nusxa faqat tahrirda o'z shishasini chizadi.
        WidgetPlate {
            id: plate

            anchors.fill: parent
            visible: !!host.info && host.info.plate && (host.isFace || Widgets.editMode)
            radius: 22 * host.factor
        }

        // Tarkib faqat ko'rinayotganda ishlaydi va sekin paydo bo'ladi. Ramka o'lchami o'zgarmaydi.
        Item {
            anchors.fill: parent
            // No fade here: the copy above already shows the same content.
            visible: !host.contentCovered

            Loader {
                id: face

                property real reshapeOpacity: 1

                width: host.shownForm ? host.shownForm.w : 0
                height: host.shownForm ? host.shownForm.h : 0
                scale: host.factor
                transformOrigin: Item.TopLeft
                active: host.hasContent
                source: host.entry ? Qt.resolvedUrl("widgets/" + host.entry.type + ".qml") : ""
                enabled: !Widgets.editMode && !host.isFace
                // Reduced from its full size, because text scaled down by itself turns rough.
                layer.enabled: host.factor < 1
                layer.smooth: true
                layer.mipmap: true
                opacity: status === Loader.Ready ? reshapeOpacity : 0
                onLoaded: {
                    if ("form" in item)
                        item.form = Qt.binding(() => host.shownForm ? host.shownForm.name : "");
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 360
                    }
                }
            }
        }
    }

    // Tahrirlash: tortish va tugmalar
    Rectangle {
        anchors.fill: parent
        radius: host.info && (host.info.plate || host.info.solid) ? 22 * host.factor : 18
        color: "transparent"
        visible: !host.isFace && Widgets.editMode
        border.width: host.dragging ? 2 : 1
        border.color: host.dragging || mover.containsMouse ? Theme.accent : Qt.alpha(Theme.text, 0.35)
    }
    MouseArea {
        id: mover

        anchors.fill: parent
        enabled: !host.isFace && Widgets.editMode
        visible: enabled
        hoverEnabled: true
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: host
        drag.threshold: 2
        drag.minimumX: host.minX
        drag.maximumX: host.maxX
        drag.minimumY: host.minY
        drag.maximumY: host.maxY
        onReleased: {
            // Oddiy bosish vidjetni surmaydi va saqlangan joyini o'zgartirmaydi.
            if (Math.abs(host.x - host.placeX()) < 0.5 && Math.abs(host.y - host.placeY()) < 0.5)
                return;
            const x = host.snap(host.x, host.minX, host.maxX);
            const y = host.snap(host.y, host.minY, host.maxY);
            const spanX = Math.max(1, host.areaWidth - host.targetWidth);
            const spanY = Math.max(1, host.areaHeight - host.topInset - host.targetHeight);
            Widgets.move(host.widgetId, (x - host.side) / spanX, (y - host.topInset) / spanY);
        }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 5
        visible: !host.isFace && Widgets.editMode && !host.dragging

        Rectangle {
            width: sizeLabel.implicitWidth + 16
            height: 26
            radius: 13
            color: sizeArea.containsMouse ? Theme.accent : Theme.pill

            Label {
                id: sizeLabel

                anchors.centerIn: parent
                text: host.entry ? host.entry.size.toUpperCase() : ""
                color: sizeArea.containsMouse ? Theme.accentText : Theme.text
                size: 11
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: sizeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Widgets.cycleSize(host.widgetId)
            }
        }
        Rectangle {
            width: 26
            height: 26
            radius: 13
            color: removeArea.containsMouse ? Theme.error : Theme.pill

            Icon {
                anchors.centerIn: parent
                name: "close"
                size: 12
                color: removeArea.containsMouse ? Theme.pill : Theme.text
            }
            MouseArea {
                id: removeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Widgets.remove(host.widgetId)
            }
        }
    }
}
