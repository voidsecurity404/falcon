import QtQuick
import Quickshell
import qs.components
import qs.services

// Top of the Animations page: how windows open. Every card plays its look in a loop, like a GIF,
// through shaders/winopen.frag, which is built from the same niri/shaders/window-open.glsl that
// niri runs (bin/falcon-apply), so the preview is the real thing in small: a window of a real size
// (`windowSize`) on a piece of the wallpaper, at the real speed (openDuration over animationSpeed).
Column {
    id: root

    readonly property string chosen: Settings.get("windows.openAnimation", "standard")
    readonly property real duration: Settings.get("windows.openDuration", 220)
    readonly property real globalSpeed: Math.max(0.1, Settings.get("windows.animationSpeed", 1))
    readonly property bool animationsOn: Settings.get("windows.animations", true)
    // What niri really takes: windows.animationSpeed becomes `slowdown 1/speed`.
    readonly property real realMs: duration / globalSpeed
    readonly property bool live: visible && Ui.settingsOpen

    // `n` is the number in fo_pick(), and the order of OPEN_ANIMATIONS in bin/falcon-apply.
    readonly property var looks: [
        { id: "standard", n: 0, name: Tr.t("Standard"), sub: Tr.t("Grows from half size") },
        { id: "fade", n: 1, name: Tr.t("Fade"), sub: Tr.t("Only appears") },
        { id: "pop", n: 2, name: Tr.t("Pop"), sub: Tr.t("Springs past its size") },
        { id: "rise", n: 3, name: Tr.t("Rise"), sub: Tr.t("Comes up from below") },
        { id: "drop", n: 4, name: Tr.t("Drop"), sub: Tr.t("Falls and bounces") },
        { id: "zoom", n: 5, name: Tr.t("Zoom"), sub: Tr.t("Comes toward its place") },
        { id: "unfold", n: 6, name: Tr.t("Unfold"), sub: Tr.t("A line opens like an old TV") },
        { id: "flip", n: 7, name: Tr.t("Flip"), sub: Tr.t("Turns in around its middle") },
        { id: "swing", n: 13, name: Tr.t("Swing"), sub: Tr.t("Swings down from its top") },
        { id: "circle", n: 8, name: Tr.t("Circle"), sub: Tr.t("Opens through a circle") },
        { id: "pixels", n: 9, name: Tr.t("Pixels"), sub: Tr.t("Big squares get finer") },
        { id: "glitch", n: 10, name: Tr.t("Glitch"), sub: Tr.t("Torn slices calm down") },
        { id: "dissolve", n: 11, name: Tr.t("Dissolve"), sub: Tr.t("Appears through noise") },
        { id: "blinds", n: 12, name: Tr.t("Blinds"), sub: Tr.t("Slats open one by one") },
        { id: "random", n: -1, name: Tr.t("Random"), sub: Tr.t("Another look every time") }
    ]
    readonly property var chosenLook: looks.find(l => l.id === chosen) || looks[0]

    // One clock for every card, so they play together and stop when the page is not seen.
    property real clock: 0
    // A loop: the opening, the window resting, then a short empty pause.
    readonly property real holdMs: 1100
    readonly property real gapMs: 450
    readonly property real loopMs: realMs + holdMs + gapMs
    readonly property int loopIndex: Math.floor(clock / loopMs)
    readonly property real progress: {
        const t = clock - loopIndex * loopMs;
        return t >= realMs + holdMs ? 0 : Math.min(1, t / realMs);
    }

    // A window of this many logical pixels, so effects measured in pixels look as on screen.
    readonly property size windowSize: Qt.size(1190, 680)
    // Its place in the piece of desktop each preview shows.
    readonly property rect windowArea: Qt.rect(0.17, 0.16, 0.66, 0.68)

    function effectFor(look) {
        // Random shows a different look on each loop, as niri picks one per window.
        return look.n >= 0 ? look.n : 1 + (root.loopIndex * 5) % 13;
    }

    spacing: 16

    FrameAnimation {
        running: root.live
        onTriggered: root.clock += frameTime * 1000
    }

    // One preview: a piece of the wallpaper with the window opening on it.
    component Preview: Rectangle {
        id: preview

        property int effect: 0
        property real progress: 0
        property real seed: 0.37

        radius: 14
        color: Theme.glassBase
        clip: true

        Image {
            anchors.fill: parent
            source: Wallpapers.shownImage === "" ? "" : "file://" + Wallpapers.shownImage
            sourceSize.width: 640
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            opacity: 0.9
        }
        ShaderEffect {
            anchors.fill: parent

            property variant niri_tex: windowTexture
            property real niri_clamped_progress: preview.progress
            property real niri_random_seed: preview.seed
            property real effect: preview.effect
            property rect area: root.windowArea
            property size size: root.windowSize

            fragmentShader: Qt.resolvedUrl("../shaders/winopen.frag.qsb")
        }
    }

    // ------------------------------------------------ the chosen look, large
    Rectangle {
        width: root.width
        height: 300
        radius: 20
        color: Qt.tint(Qt.alpha(Theme.glassBase, 0.3), Qt.alpha(Theme.text, 0.045))
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.08)

        // The window every preview opens: one texture, drawn once, shared by all cards.
        Item {
            width: 0
            height: 0
            clip: true

            Rectangle {
                id: mock

                width: 595
                height: 340
                radius: Math.max(2, Settings.get("windows.radius", 20) * width / root.windowSize.width)
                color: Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.04))
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.1)

                // Tabs and the address field of a browser-like app.
                Row {
                    x: 14
                    y: 10
                    spacing: 6

                    Repeater {
                        model: 3

                        Rectangle {
                            required property int index

                            width: index === 0 ? 120 : 92
                            height: 22
                            radius: 8
                            color: index === 0 ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.text, 0.08)

                            Rectangle {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: parent.index === 0 ? Theme.accent : Qt.alpha(Theme.text, 0.3)
                            }
                            Rectangle {
                                x: 26
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 40
                                height: 5
                                radius: 2.5
                                color: Qt.alpha(Theme.text, parent.index === 0 ? 0.55 : 0.28)
                            }
                        }
                    }
                }
                Rectangle {
                    x: 14
                    y: 40
                    width: mock.width - 28
                    height: 24
                    radius: 12
                    color: Qt.alpha(Theme.text, 0.07)

                    Rectangle {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        height: 5
                        radius: 2.5
                        color: Qt.alpha(Theme.text, 0.35)
                    }
                }
                // A page: a picture in the theme colors, headings and lines of text.
                Rectangle {
                    x: 14
                    y: 76
                    width: 250
                    height: 150
                    radius: 12
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Theme.accent
                        }
                        GradientStop {
                            position: 1
                            color: Theme.hueShift(Theme.accent, 0.12)
                        }
                    }

                    Rectangle {
                        x: 160
                        y: 26
                        width: 54
                        height: 54
                        radius: 27
                        color: Qt.alpha("white", 0.75)
                    }
                    Rectangle {
                        y: 96
                        width: parent.width
                        height: 54
                        radius: 12
                        color: Qt.alpha("black", 0.22)
                    }
                }
                Column {
                    x: 280
                    y: 82
                    spacing: 10

                    Rectangle {
                        width: 210
                        height: 12
                        radius: 6
                        color: Qt.alpha(Theme.text, 0.75)
                    }
                    Rectangle {
                        width: 150
                        height: 12
                        radius: 6
                        color: Qt.alpha(Theme.text, 0.75)
                    }
                    Item {
                        width: 1
                        height: 4
                    }
                    Repeater {
                        model: [280, 260, 290, 200, 240]

                        Rectangle {
                            required property var modelData

                            width: modelData
                            height: 6
                            radius: 3
                            color: Qt.alpha(Theme.text, 0.3)
                        }
                    }
                    Rectangle {
                        width: 96
                        height: 26
                        radius: 13
                        color: Theme.accent
                    }
                }
                Row {
                    x: 14
                    y: 240
                    spacing: 12

                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index

                            width: (mock.width - 28 - 36) / 4
                            height: 86
                            radius: 10
                            color: Qt.alpha(Theme.text, 0.06)

                            Rectangle {
                                x: 10
                                y: 10
                                width: parent.width - 20
                                height: 40
                                radius: 7
                                color: Qt.alpha(Theme.hueShift(Theme.accent, parent.index * 0.08), 0.45)
                            }
                            Rectangle {
                                x: 10
                                y: 60
                                width: parent.width * 0.6
                                height: 6
                                radius: 3
                                color: Qt.alpha(Theme.text, 0.35)
                            }
                        }
                    }
                }
            }
        }

        ShaderEffectSource {
            id: windowTexture

            sourceItem: mock
            hideSource: true
            mipmap: true
            smooth: true
            width: 0
            height: 0
        }

        Preview {
            id: big

            x: 12
            y: 12
            width: Math.round((parent.height - 24) * 16 / 10)
            height: parent.height - 24
            radius: 14
            effect: root.effectFor(root.chosenLook)
            progress: root.progress
            seed: (root.loopIndex * 0.618) % 1
        }

        Column {
            x: big.x + big.width + 22
            y: 26
            width: parent.width - x - 22
            spacing: 6

            Label {
                text: Tr.t("Opening a window")
                color: Theme.muted
                size: 12
                font.weight: Font.Medium
            }
            Label {
                width: parent.width
                text: root.chosenLook.name
                size: 26
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: root.chosenLook.sub
                color: Theme.muted
                size: 13
                wrapMode: Text.Wrap
            }
            Item {
                width: 1
                height: 14
            }
            Label {
                width: parent.width
                text: Tr.t("Takes {ms} ms").replace("{ms}", Math.round(root.realMs))
                size: 14
                font.weight: Font.Medium
            }
            Label {
                visible: Math.abs(root.globalSpeed - 1) > 0.001
                width: parent.width
                text: Tr.t("With the general animation speed of {x}").replace("{x}", "×" + root.globalSpeed.toFixed(1))
                color: Theme.muted
                size: 12
                wrapMode: Text.Wrap
            }
            Item {
                width: 1
                height: 8
            }
            Rectangle {
                visible: !root.animationsOn
                width: parent.width
                height: offText.implicitHeight + 16
                radius: 12
                color: Qt.alpha(Theme.error, 0.15)

                Label {
                    id: offText

                    x: 12
                    y: 8
                    width: parent.width - 24
                    text: Tr.t("Animations are off below, so windows open at once")
                    color: Theme.error
                    size: 12
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ------------------------------------------------ every look
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
            id: grid

            columns: 3
            spacing: 10
            width: root.width

            Repeater {
                model: root.looks

                delegate: Rectangle {
                    id: card

                    required property var modelData
                    readonly property bool picked: root.chosen === modelData.id

                    width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
                    height: width * 10 / 16 * 0.78 + 52
                    radius: 18
                    color: picked ? Qt.alpha(Theme.accent, 0.16) : cardMouse.containsMouse ? Qt.alpha(Theme.text, 0.08) : Qt.alpha(Theme.text, 0.045)
                    border.width: picked ? 2 : 1
                    border.color: picked ? Theme.accent : cardMouse.containsMouse ? Qt.alpha(Theme.text, 0.25) : Qt.alpha(Theme.text, 0.08)

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }

                    Preview {
                        x: 8
                        y: 8
                        width: parent.width - 16
                        height: parent.height - 60
                        radius: 12
                        effect: root.effectFor(card.modelData)
                        progress: root.progress
                        seed: (root.loopIndex * 0.618) % 1
                    }

                    Row {
                        x: 14
                        y: parent.height - 46
                        width: parent.width - 28
                        spacing: 7

                        Icon {
                            visible: card.picked
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 15
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width - (card.picked ? 22 : 0)
                            spacing: 1

                            Label {
                                width: parent.width
                                text: card.modelData.name
                                color: card.picked ? Theme.accent : Theme.text
                                size: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Label {
                                width: parent.width
                                text: card.modelData.sub
                                color: Theme.muted
                                size: 11
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.set("windows.openAnimation", card.modelData.id)
                    }
                }
            }
        }
    }
}
