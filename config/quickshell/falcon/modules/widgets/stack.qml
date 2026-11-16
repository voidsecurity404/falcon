import QtQuick
import qs.components
import qs.services

// Several widgets in one place, one shown at a time: the wheel or the dots on the side turn to
// the next. Made by dropping a widget onto another in edit mode, or from the gallery. Its size is
// the first widget's; the others are scaled to fit inside. Children live in the entry's "stack".
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "stack"
    property string role: ""
    readonly property var entry: Widgets.get(widgetId)
    // In the gallery there is no entry yet: the stack it would make.
    readonly property var children_: entry && Array.isArray(entry.stack) ? entry.stack : Widgets.defaultStack
    readonly property int count: children_.length
    readonly property int page: count > 0 ? ((Widgets.sharedValue(widgetId, "page", 0) % count) + count) % count : 0
    // Which way the last turn went, for the slide.
    property int direction: 1
    property int shownPage: 0

    function turn(step) {
        if (count < 2)
            return;
        direction = step > 0 ? 1 : -1;
        Widgets.share(widgetId, "page", (page + step + count) % count);
    }

    onPageChanged: {
        if (page !== shownPage)
            swap.restart();
    }

    SequentialAnimation {
        id: swap

        ParallelAnimation {
            NumberAnimation {
                target: holder
                property: "opacity"
                to: 0
                duration: 120
            }
            NumberAnimation {
                target: holder
                property: "y"
                to: -24 * root.direction
                duration: 120
                easing.type: Easing.InQuad
            }
        }
        ScriptAction {
            script: {
                root.shownPage = root.page;
                holder.y = 24 * root.direction;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: holder
                property: "opacity"
                to: 1
                duration: 220
            }
            NumberAnimation {
                target: holder
                property: "y"
                to: 0
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        id: holder

        width: root.width
        height: root.height

        Repeater {
            model: root.count

            Item {
                id: slot

                required property int index
                readonly property var child: root.children_[index] || null
                readonly property var info: child ? Widgets.info(child.type) : null
                readonly property var form: info ? (info.forms.find(f => f.name === child.form) || info.forms[0]) : null
                readonly property real fit: form ? Math.min(1, (root.width - 20) / form.w, root.height / form.h) : 1

                anchors.fill: parent
                visible: index === root.shownPage

                Loader {
                    x: (slot.width - width * slot.fit) / 2
                    y: (slot.height - height * slot.fit) / 2
                    width: slot.form ? slot.form.w : 0
                    height: slot.form ? slot.form.h : 0
                    scale: slot.fit
                    transformOrigin: Item.TopLeft
                    // Only the page on show is built, and the next ones once seen.
                    active: !!slot.info && slot.visible
                    source: slot.info ? Qt.resolvedUrl(slot.info.type + ".qml") : ""
                    layer.enabled: slot.fit < 1
                    layer.smooth: true
                    layer.mipmap: true
                    onLoaded: {
                        if ("widgetId" in item)
                            item.widgetId = root.widgetId + "/" + slot.index;
                        if ("role" in item)
                            item.role = Qt.binding(() => root.role);
                        if ("form" in item)
                            item.form = Qt.binding(() => slot.form ? slot.form.name : "");
                    }
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: root.count > 1
        property real sum: 0
        onWheel: event => {
            sum += event.angleDelta.y;
            if (Math.abs(sum) >= 120) {
                root.turn(sum > 0 ? -1 : 1);
                sum = 0;
            }
        }
    }

    // Dots on the right edge: where we are, and a press turns to that page.
    Column {
        visible: root.count > 1
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Repeater {
            model: root.count

            Rectangle {
                id: dot

                required property int index

                width: 6
                height: index === root.page ? 16 : 6
                radius: 3
                color: index === root.page ? Theme.accent : Qt.alpha(Theme.text, dotHot.hovered ? 0.6 : 0.3)

                Behavior on height {
                    NumberAnimation {
                        duration: 180
                    }
                }

                WidgetHot {
                    id: dotHot

                    anchors.fill: parent
                    anchors.margins: -5
                    onClicked: root.turn(dot.index - root.page)
                }
            }
        }
    }
}
