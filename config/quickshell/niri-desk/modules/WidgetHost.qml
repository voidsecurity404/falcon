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
    readonly property bool dragging: !isFace && mover.drag.active
    readonly property int gridStep: 16
    readonly property bool interactive: !!info && info.interactive === true
    readonly property bool holding: !isFace && interactive && (hover.hovered || (entry && entry.type === "notes" && Widgets.noteFocused))
    readonly property bool showCopy: !isFace && (Widgets.editMode || (holding && !Widgets.sliding))
    readonly property bool hasContent: isFace ? contentOn : (Widgets.editMode || interactive)
    readonly property real drawOpacity: isFace ? (Widgets.hoverId === widgetId ? 0 : 1) : (showCopy ? 1 : 0)

    function snap(v, low, high) {
        return Math.max(low, Math.min(high, Math.round(v / gridStep) * gridStep));
    }

    readonly property real minX: side
    readonly property real maxX: side + Math.max(0, areaWidth - width)
    readonly property real minY: topInset
    readonly property real maxY: Math.max(topInset, areaHeight - height)

    function placeX() {
        return entry ? side + entry.fx * Math.max(0, areaWidth - width) : side;
    }
    function placeY() {
        return entry ? topInset + entry.fy * Math.max(0, areaHeight - topInset - height) : topInset;
    }

    width: info ? info.w * factor : 0
    height: info ? info.h * factor : 0
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

    onShowCopyChanged: {
        if (!isFace && !Widgets.editMode)
            Widgets.hoverId = showCopy ? widgetId : (Widgets.hoverId === widgetId ? "" : Widgets.hoverId);
    }
    onXChanged: report()
    onYChanged: report()
    onWidthChanged: report()
    onHeightChanged: report()

    function report() {
        if (!isFace)
            Widgets.setRect(widgetId, x, y, width, height);
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
        radius: plate.visible ? plate.radius : 18
        color: Qt.alpha(Theme.accent, 0.16)
        border.width: 2
        border.color: Theme.accent
        z: -1
    }

    // Ko'rinadigan qism
    Item {
        anchors.fill: parent
        opacity: host.drawOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        // Yuzdagi shisha doim turadi, nusxa faqat tahrirda o'z shishasini chizadi.
        Rectangle {
            id: plate

            anchors.fill: parent
            visible: !!host.info && host.info.plate && (host.isFace || Widgets.editMode)
            radius: 22 * host.factor
            border.width: 1
            border.color: Theme.panelEdge
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.glassBase, Math.max(0.05, Widgets.glass - 0.08))
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Theme.glassBase, Widgets.glass)
                }
            }
        }

        // Tarkib faqat ko'rinayotganda ishlaydi va sekin paydo bo'ladi. Ramka o'lchami o'zgarmaydi.
        Loader {
            id: face

            width: host.info ? host.info.w : 0
            height: host.info ? host.info.h : 0
            scale: host.factor
            transformOrigin: Item.TopLeft
            active: host.hasContent
            source: host.entry ? Qt.resolvedUrl("widgets/" + host.entry.type + ".qml") : ""
            enabled: !Widgets.editMode && !host.isFace
            opacity: status === Loader.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 360
                }
            }
        }
    }

    // Tahrirlash: tortish va tugmalar
    Rectangle {
        anchors.fill: parent
        radius: plate.visible ? plate.radius : 18
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
            const spanX = Math.max(1, host.areaWidth - host.width);
            const spanY = Math.max(1, host.areaHeight - host.topInset - host.height);
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
