import QtQuick
import Quickshell.Services.Pipewire
import qs.components
import qs.services

// Sound output choice in the control center.
Column {
    id: root

    signal releaseFocus

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    width: parent.width
    spacing: 10

    PwObjectTracker {
        objects: root.sinks
    }

    PageHeader {
        title: Tr.t("Sound output")
        on: !Audio.muted
        onBack: Ui.controlPage = ""
        onToggled: Audio.toggleMute()
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: root.sinks

            delegate: ChoiceRow {
                required property var modelData

                icon: "volume"
                title: modelData.description || modelData.name
                current: Pipewire.defaultAudioSink === modelData
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }
}
