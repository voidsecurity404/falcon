import QtQuick
import qs.components
import qs.services

// A widget as it looks on the desktop, live and scaled to fit, for the gallery. It takes no input.
Item {
    id: preview

    required property var info

    readonly property var form: info.forms[0]
    readonly property real fit: Math.min(1, width / form.w, height / form.h)

    Item {
        anchors.centerIn: parent
        width: preview.form.w * preview.fit
        height: preview.form.h * preview.fit

        WidgetPlate {
            anchors.fill: parent
            visible: preview.info.plate
            radius: 22 * preview.fit
        }
        Loader {
            width: preview.form.w
            height: preview.form.h
            scale: preview.fit
            transformOrigin: Item.TopLeft
            asynchronous: true
            enabled: false
            // Drawn at full size and then reduced, because text scaled by itself turns rough.
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            source: Qt.resolvedUrl("widgets/" + preview.info.type + ".qml")
            opacity: status === Loader.Ready ? 1 : 0
            onLoaded: {
                if ("form" in item)
                    item.form = preview.form.name;
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }
        }
    }
}
