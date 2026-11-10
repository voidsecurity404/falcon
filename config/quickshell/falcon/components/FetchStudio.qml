import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Top of the Fastfetch page: a live terminal preview, the ten styles and the six animations.
// Everything comes from bin/falcon-fetch, the same code that draws the greeting:
// --preview-text gives the chosen style's lines, --previews an animated WebP per animation.
Column {
    id: root

    readonly property string style: Settings.get("fetch.style", "classic")
    readonly property string animation: Settings.get("fetch.animation", "spin")
    readonly property real seconds: Settings.get("fetch.seconds", 3.2)
    readonly property bool live: visible && Ui.settingsOpen

    readonly property var styles: [
        { id: "classic", name: Tr.t("Classic"), sub: Tr.t("Everything, as before") },
        { id: "minimal", name: Tr.t("Minimal"), sub: Tr.t("Six short lines") },
        { id: "boxed", name: Tr.t("Boxed"), sub: Tr.t("Lines inside a frame") },
        { id: "tree", name: Tr.t("Tree"), sub: Tr.t("System, desktop, hardware") },
        { id: "icons", name: Tr.t("Icons"), sub: Tr.t("An icon on every line") },
        { id: "hardware", name: Tr.t("Hardware"), sub: Tr.t("Processor, memory, disks") },
        { id: "bars", name: Tr.t("Bars"), sub: Tr.t("Memory and disk as bars") },
        { id: "palette", name: Tr.t("Palette"), sub: Tr.t("User name and the colors") },
        { id: "arrows", name: Tr.t("Arrows"), sub: Tr.t("Name, arrow, value") },
        { id: "quiet", name: Tr.t("Quiet"), sub: Tr.t("Values only") }
    ]
    readonly property var animations: [
        { id: "spin", name: Tr.t("Spin") },
        { id: "pulse", name: Tr.t("Pulse") },
        { id: "shine", name: Tr.t("Shine") },
        { id: "wave", name: Tr.t("Wave") },
        { id: "glitch", name: Tr.t("Glitch") },
        { id: "scan", name: Tr.t("Scan") }
    ]

    property var clips: ({})
    property var sample: ({ html: "", background: "#000000", foreground: "#ffffff", lines: 14 })
    property bool clipsBusy: false

    function refreshClips() {
        if (!live)
            return;
        if (clipMaker.running) {
            clipsAgain.restart();
            return;
        }
        root.clipsBusy = true;
        clipMaker.running = true;
    }
    function refreshText() {
        if (!live)
            return;
        textMaker.command = ["falcon-fetch", "--preview-text", root.style];
        textMaker.running = false;
        textMaker.running = true;
    }

    spacing: 16

    onLiveChanged: {
        if (live) {
            refreshText();
            refreshClips();
        }
    }
    onStyleChanged: refreshText()
    onSecondsChanged: clipsAgain.restart()

    Connections {
        target: Theme
        function onAccentChanged() {
            clipsAgain.restart();
            textAgain.restart();
        }
    }
    // A new theme writes the kitty colors a moment after colors.json.
    Timer {
        id: textAgain

        interval: 900
        onTriggered: root.refreshText()
    }
    Timer {
        id: clipsAgain

        interval: 600
        onTriggered: root.refreshClips()
    }

    Process {
        id: clipMaker

        command: ["falcon-fetch", "--previews"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.clips = JSON.parse(text);
                } catch (e) {}
                root.clipsBusy = false;
            }
        }
        onExited: root.clipsBusy = false
    }
    Process {
        id: textMaker

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sample = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    // ------------------------------------------------ live preview
    Column {
        width: root.width
        spacing: 7

        Label {
            x: 6
            text: Tr.t("Preview")
            color: Theme.muted
            size: 12
            font.weight: Font.Medium
        }

        Rectangle {
            id: term

            readonly property int lineHeight: 17

            width: root.width
            height: Math.max(14, root.sample.lines) * lineHeight + 64
            radius: 18
            color: root.sample.background
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.08)
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            // Window dots and the command, so it reads as a terminal.
            Row {
                x: 16
                y: 13
                spacing: 7

                Repeater {
                    model: 3

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: Qt.alpha(root.sample.foreground, 0.22)
                    }
                }
            }
            Label {
                x: 76
                y: 9
                text: "~ ❯ fastfetch"
                font.family: Theme.mono
                size: 12
                color: Qt.alpha(root.sample.foreground, 0.55)
            }

            Row {
                x: 18
                y: 40
                spacing: 18

                AnimatedImage {
                    id: bigClip

                    // 24 columns of 9 px and 14 rows of 19 px, scaled to the preview's lines.
                    height: 14 * term.lineHeight
                    width: Math.round(216 * height / 266)
                    source: root.clips[root.animation] ? "file://" + root.clips[root.animation] : ""
                    playing: root.live
                    smooth: true
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    width: term.width - bigClip.width - 60
                    textFormat: Text.RichText
                    text: root.sample.html
                    color: root.sample.foreground
                    font.family: Theme.mono
                    font.pixelSize: 12
                    lineHeightMode: Text.FixedHeight
                    lineHeight: term.lineHeight
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    clip: true
                }
            }

            Label {
                visible: root.clipsBusy && !root.clips[root.animation]
                anchors.centerIn: parent
                text: Tr.t("Preparing the animations…")
                color: Qt.alpha(root.sample.foreground, 0.7)
            }
        }
    }

    // ------------------------------------------------ styles
    Column {
        width: root.width
        spacing: 7

        Label {
            x: 6
            text: Tr.t("Style")
            color: Theme.muted
            size: 12
            font.weight: Font.Medium
        }

        Grid {
            id: styleGrid

            columns: 5
            spacing: 8
            width: root.width

            Repeater {
                model: root.styles

                delegate: Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool chosen: root.style === modelData.id

                    width: (styleGrid.width - styleGrid.spacing * (styleGrid.columns - 1)) / styleGrid.columns
                    height: 58
                    radius: 14
                    color: chosen ? Qt.alpha(Theme.accent, 0.2) : chipMouse.containsMouse ? Qt.alpha(Theme.text, 0.08) : Qt.alpha(Theme.text, 0.045)
                    border.width: chosen ? 1.5 : 1
                    border.color: chosen ? Theme.accent : Qt.alpha(Theme.text, 0.06)

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }

                    Column {
                        x: 12
                        width: parent.width - 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Label {
                            width: parent.width
                            text: chip.modelData.name
                            color: chip.chosen ? Theme.accent : Theme.text
                            size: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            text: chip.modelData.sub
                            color: Theme.muted
                            size: 11
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: chipMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.set("fetch.style", chip.modelData.id)
                    }
                }
            }
        }
    }

    // ------------------------------------------------ animations
    Column {
        width: root.width
        spacing: 7

        Label {
            x: 6
            text: Tr.t("Animation")
            color: Theme.muted
            size: 12
            font.weight: Font.Medium
        }

        Grid {
            id: animGrid

            columns: 3
            spacing: 10
            width: root.width

            Repeater {
                model: root.animations

                delegate: Rectangle {
                    id: card

                    required property var modelData
                    readonly property bool chosen: root.animation === modelData.id

                    width: (animGrid.width - animGrid.spacing * (animGrid.columns - 1)) / animGrid.columns
                    height: 186
                    radius: 18
                    color: root.sample.background
                    border.width: chosen ? 2 : 1
                    border.color: chosen ? Theme.accent : cardMouse.containsMouse ? Qt.alpha(Theme.text, 0.25) : Qt.alpha(Theme.text, 0.08)

                    AnimatedImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 14
                        height: 124
                        width: Math.round(216 * height / 266)
                        source: root.clips[card.modelData.id] ? "file://" + root.clips[card.modelData.id] : ""
                        playing: root.live
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 40
                        radius: 18
                        color: card.chosen ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.text, 0.05)

                        // Square off the top corners of the caption strip.
                        Rectangle {
                            width: parent.width
                            height: 18
                            color: parent.color
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 7

                            Icon {
                                visible: card.chosen
                                anchors.verticalCenter: parent.verticalCenter
                                name: "check"
                                size: 15
                                color: Theme.accent
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.modelData.name
                                color: card.chosen ? Theme.accent : Theme.text
                                size: 13
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Label {
                        visible: !root.clips[card.modelData.id]
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 66
                        text: "…"
                        color: Qt.alpha(root.sample.foreground, 0.6)
                    }

                    MouseArea {
                        id: cardMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.set("fetch.animation", card.modelData.id)
                    }
                }
            }
        }
    }
}
