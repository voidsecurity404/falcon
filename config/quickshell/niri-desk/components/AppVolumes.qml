import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

// One slider for each app playing sound. Empty and without height when nothing plays.
Column {
    id: root

    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)

    function appName(node) {
        const p = node.properties || {};
        return p["application.name"] || p["media.name"] || node.description || node.name || "";
    }

    spacing: 2
    visible: streams.length > 0

    PwObjectTracker {
        objects: root.streams
    }

    Repeater {
        model: root.streams

        delegate: Item {
            id: row

            required property var modelData

            width: root.width
            height: 54

            Label {
                x: 6
                y: 4
                width: parent.width - 12
                text: root.appName(row.modelData)
                size: 12
                color: Theme.muted
                elide: Text.ElideRight
            }
            LevelRow {
                y: 18
                width: parent.width
                icon: row.modelData.audio.muted ? "mute" : "music"
                dimmed: row.modelData.audio.muted
                iconButton: true
                value: row.modelData.audio.volume
                text: Math.round(row.modelData.audio.volume * 100) + "%"
                onMoved: value => row.modelData.audio.volume = value
                onIconClicked: row.modelData.audio.muted = !row.modelData.audio.muted
            }
        }
    }
}
