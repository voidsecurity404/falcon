import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Top of the Fastfetch page: a live terminal preview, the logos, the ten styles and the seven animations.
// Everything comes from bin/falcon-fetch, the same code that draws the greeting:
// --preview-text gives the chosen style's lines, --previews a still PNG per logo and an animated
// WebP for every logo and animation, one JSON line each, so another logo shows at once when picked.
// While a clip is still being made, its logo's still picture stands in for it.
Column {
    id: root

    readonly property string style: Settings.get("fetch.style", "classic")
    readonly property string animationSet: Settings.get("fetch.animation", "spin")
    // A name from an older list falls back to spin, as in falcon-fetch.
    readonly property string animation: animations.some(a => a.id === animationSet) ? animationSet : "spin"
    readonly property real seconds: Settings.get("fetch.seconds", 3.2)
    readonly property string logo: Settings.get("fetch.logo", "brand")
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
    readonly property var logos: [
        { id: "brand", name: Tr.t("Brand") },
        { id: "falcon", name: Tr.t("Falcon bird") },
        { id: "sword", name: Tr.t("Sword") },
        { id: "skull", name: Tr.t("Skull") },
        { id: "moon", name: Tr.t("Moon") },
        { id: "mountain", name: Tr.t("Mountains") },
        { id: "flame", name: Tr.t("Flame") },
        { id: "eye", name: Tr.t("Eye") },
        { id: "crystal", name: Tr.t("Crystal") },
        { id: "bolt", name: Tr.t("Lightning") },
        { id: "planet", name: Tr.t("Planet") }
    ]
    readonly property var animations: [
        { id: "spin", name: Tr.t("Spin") },
        { id: "flip", name: Tr.t("Flip") },
        { id: "swing", name: Tr.t("Swing") },
        { id: "bounce", name: Tr.t("Bounce") },
        { id: "assemble", name: Tr.t("Assemble") },
        { id: "decode", name: Tr.t("Decode") },
        { id: "aurora", name: Tr.t("Aurora") }
    ]

    // clips[logo][animation] is the path of a WebP, stills[logo] of a PNG.
    property var clips: ({})
    property var stills: ({})
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
    function clipOf(logo, anim) {
        const set = root.clips[logo];
        return set && set[anim] ? "file://" + set[anim] : "";
    }
    function stillOf(logo) {
        return root.stills[logo] ? "file://" + root.stills[logo] : "";
    }
    function takeLine(line) {
        let data;
        try {
            data = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (data.logos) {
            root.stills = data.logos;
            return;
        }
        if (!data.logo || !data.animation)
            return;
        const all = Object.assign({}, root.clips);
        all[data.logo] = Object.assign({}, all[data.logo] || {});
        all[data.logo][data.animation] = data.path;
        root.clips = all;
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
        stdout: SplitParser {
            onRead: line => root.takeLine(line)
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

                Item {
                    id: bigClip

                    // 24 columns of 9 px and 14 rows of 19 px, scaled to the preview's lines.
                    readonly property string clipFile: root.clipOf(root.logo, root.animation)

                    height: 14 * term.lineHeight
                    width: Math.round(216 * height / 266)

                    Image {
                        anchors.fill: parent
                        visible: bigClip.clipFile === ""
                        source: root.stillOf(root.logo)
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                    }
                    AnimatedImage {
                        anchors.fill: parent
                        visible: bigClip.clipFile !== ""
                        source: bigClip.clipFile
                        playing: root.live
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                    }
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
                visible: root.clipsBusy && bigClip.clipFile === "" && root.stillOf(root.logo) === ""
                anchors.centerIn: parent
                text: Tr.t("Preparing the animations…")
                color: Qt.alpha(root.sample.foreground, 0.7)
            }
        }
    }

    // ------------------------------------------------ logos
    Column {
        width: root.width
        spacing: 7

        Label {
            x: 6
            text: Tr.t("Logo")
            color: Theme.muted
            size: 12
            font.weight: Font.Medium
        }

        Grid {
            id: logoGrid

            columns: 6
            spacing: 8
            width: root.width

            Repeater {
                model: root.logos

                delegate: Rectangle {
                    id: logoCard

                    required property var modelData
                    readonly property bool chosen: root.logo === modelData.id
                    readonly property string picture: root.stillOf(modelData.id)

                    width: (logoGrid.width - logoGrid.spacing * (logoGrid.columns - 1)) / logoGrid.columns
                    height: 124
                    radius: 16
                    color: root.sample.background
                    border.width: chosen ? 2 : 1
                    border.color: chosen ? Theme.accent : logoMouse.containsMouse ? Qt.alpha(Theme.text, 0.25) : Qt.alpha(Theme.text, 0.08)

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10
                        height: 82
                        width: Math.round(216 * height / 266)
                        source: logoCard.picture
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                    }
                    Label {
                        visible: !logoCard.picture
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 40
                        text: "…"
                        color: Qt.alpha(root.sample.foreground, 0.6)
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 26
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        text: logoCard.modelData.name
                        color: logoCard.chosen ? Theme.accent : Theme.text
                        size: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: logoMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.set("fetch.logo", logoCard.modelData.id)
                    }
                }
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

            columns: 4
            spacing: 10
            width: root.width

            Repeater {
                model: root.animations

                delegate: Rectangle {
                    id: card

                    required property var modelData
                    readonly property bool chosen: root.animation === modelData.id
                    readonly property string clipFile: root.clipOf(root.logo, modelData.id)

                    width: (animGrid.width - animGrid.spacing * (animGrid.columns - 1)) / animGrid.columns
                    height: 176
                    radius: 18
                    color: root.sample.background
                    border.width: chosen ? 2 : 1
                    border.color: chosen ? Theme.accent : cardMouse.containsMouse ? Qt.alpha(Theme.text, 0.25) : Qt.alpha(Theme.text, 0.08)

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 12
                        height: 116
                        width: Math.round(216 * height / 266)
                        visible: card.clipFile === ""
                        opacity: 0.5
                        source: root.stillOf(root.logo)
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                    }
                    AnimatedImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 12
                        height: 116
                        width: Math.round(216 * height / 266)
                        visible: card.clipFile !== ""
                        source: card.clipFile
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
                        visible: card.clipFile === "" && root.stillOf(root.logo) === ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 60
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
