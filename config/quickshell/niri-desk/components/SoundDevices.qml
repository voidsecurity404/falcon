import QtQuick
import Quickshell.Services.Pipewire
import qs.services

// Sound page of the settings: which output and microphone are used.
Column {
    id: root

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    readonly property var sections: [
        {
            title: Tr.t("Sound output"),
            icon: "volume",
            nodes: sinks,
            current: Pipewire.defaultAudioSink,
            choose: node => Pipewire.preferredDefaultAudioSink = node
        },
        {
            title: Tr.t("Microphone"),
            icon: "mic",
            nodes: sources,
            current: Pipewire.defaultAudioSource,
            choose: node => Pipewire.preferredDefaultAudioSource = node
        }
    ]

    spacing: 16

    PwObjectTracker {
        objects: root.sinks.concat(root.sources)
    }

    Column {
        width: parent.width
        spacing: 7
        visible: appLevels.visible

        Label {
            x: 6
            text: Tr.t("Apps playing now")
            color: Theme.muted
            size: 12
            font.weight: Font.Medium
        }
        Rectangle {
            width: parent.width
            height: appLevels.implicitHeight + 16
            radius: 18
            color: Qt.alpha(Theme.text, 0.045)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.06)

            AppVolumes {
                id: appLevels

                x: 10
                y: 8
                width: parent.width - 20
            }
        }
    }

    Repeater {
        model: root.sections

        delegate: Reveal {
            id: section

            required property var modelData
            required property int index

            width: root.width
            shown: root.visible
            delay: index * 40
            visible: modelData.nodes.length > 0

            Column {
                width: parent.width
                spacing: 7

                Label {
                    x: 6
                    text: section.modelData.title
                    color: Theme.muted
                    size: 12
                    font.weight: Font.Medium
                }
                Rectangle {
                    width: parent.width
                    height: choices.implicitHeight + 16
                    radius: 18
                    color: Qt.alpha(Theme.text, 0.045)
                    border.width: 1
                    border.color: Qt.alpha(Theme.text, 0.06)

                    Column {
                        id: choices

                        x: 8
                        y: 8
                        width: parent.width - 16
                        spacing: 2

                        Repeater {
                            model: section.modelData.nodes

                            delegate: ChoiceRow {
                                required property var modelData

                                icon: section.modelData.icon
                                title: modelData.description || modelData.name
                                current: section.modelData.current === modelData
                                onClicked: section.modelData.choose(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
