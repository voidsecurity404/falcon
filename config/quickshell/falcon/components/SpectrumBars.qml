import QtQuick
import qs.services

// Bars that follow the sound, from the middle to both sides. Spectrum must be told someone is watching.
Item {
    id: root

    // Off means no level changes reach the bars, so a hidden copy costs nothing.
    property bool active: true
    property color color: Theme.accent
    property real topAlpha: 0.55
    property real bottomAlpha: 0.04
    property int gap: 4

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.height
        spacing: root.gap

        Repeater {
            model: Spectrum.count * 2

            delegate: Rectangle {
                required property int index

                readonly property int band: index < Spectrum.count ? Spectrum.count - 1 - index : index - Spectrum.count

                anchors.bottom: parent.bottom
                width: (root.width - root.gap * (Spectrum.count * 2 - 1)) / (Spectrum.count * 2)
                height: root.active ? (Spectrum.levels[band] || 0) / 100 * root.height : 0
                visible: height > 1
                topLeftRadius: width / 2
                topRightRadius: width / 2
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(root.color, root.topAlpha)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(root.color, root.bottomAlpha)
                    }
                }

                // Follows the sound closely, and sinks slowly once the music stops.
                Behavior on height {
                    NumberAnimation {
                        duration: Spectrum.levels.length > 0 ? 70 : 500
                    }
                }
            }
        }
    }
}
