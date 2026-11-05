import QtQuick
import qs.services

Text {
    property int size: Theme.fontBody

    color: Theme.text
    font.family: Theme.sans
    font.pixelSize: Math.round(size * Theme.fontScale)
    font.features: {
        "tnum": 1
    }
    renderType: Text.NativeRendering
    elide: Text.ElideRight
}
