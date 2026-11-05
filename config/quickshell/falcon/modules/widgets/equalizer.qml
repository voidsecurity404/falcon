import QtQuick
import qs.components
import qs.services

// Bars that move with the sound, and what is playing. Forms: wide, compact.
Item {
    id: root

    property string form: "wide"
    readonly property bool compact: form === "compact"
    readonly property string key: "widget-" + Math.random()
    readonly property var player: Media.player

    Component.onCompleted: Spectrum.setWatching(key, true)
    Component.onDestruction: Spectrum.setWatching(key, false)

    // Silence still looks like an equalizer: the bars rest at a calm shape.
    Row {
        x: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: 3
        visible: Spectrum.levels.length === 0

        Repeater {
            model: root.compact ? 24 : 34

            delegate: Rectangle {
                required property int index

                anchors.bottom: parent.bottom
                width: (root.width - 36 - 3 * ((root.compact ? 24 : 34) - 1)) / (root.compact ? 24 : 34)
                height: 6 + (root.compact ? 26 : 44) * Math.pow(Math.abs(Math.sin(index * 0.42) * Math.cos(index * 0.17)), 1.4)
                radius: 2
                color: Qt.alpha(Theme.accent, 0.3)
            }
        }
    }
    SpectrumBars {
        x: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: parent.width - 36
        height: root.compact ? parent.height - 28 : parent.height - 58
        active: true
        style: "bars"
        bars: root.compact ? 24 : 34
        gap: 3
        mirrored: false
        topAlpha: 1
        bottomAlpha: 0.35
        smoothing: 60
    }
    // Without sound the floor is still there.
    Rectangle {
        x: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 13
        width: parent.width - 36
        height: 2
        radius: 1
        color: Qt.alpha(Theme.text, 0.14)
    }
    Column {
        visible: !root.compact
        x: 20
        y: 12
        width: parent.width - 40

        Label {
            width: parent.width
            text: root.player ? Media.title : Tr.t("Nothing is playing")
            size: 14
            font.weight: Font.DemiBold
        }
        Label {
            width: parent.width
            visible: !!root.player
            text: root.player ? root.player.trackArtist : ""
            color: Theme.muted
            size: 11
        }
    }
}
