import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Top of the Panel page: the real panel parts (Ribbon, Island, StatusPill) drawn on a small copy
// of the screen with the wallpaper, so every choice below shows at once as it will look, and
// ready-made looks that set all parts together.
Column {
    id: root

    // Each preset sets these keys. A preset is lit while every one of them matches.
    readonly property var presets: [
        {
            id: "falcon",
            name: Tr.t("Falcon"),
            sub: Tr.t("Numbers, an island at the edge, one panel"),
            values: { "panel.style": "hug", "panel.workspaces": "numbers", "panel.island": "notch", "panel.clock": "classic", "panel.status": "together" }
        },
        {
            id: "floating",
            name: Tr.t("Floating"),
            sub: Tr.t("Capsules away from the edge"),
            values: { "panel.style": "float", "panel.workspaces": "pills", "panel.island": "capsule", "panel.clock": "classic", "panel.status": "chips" }
        },
        {
            id: "minimal",
            name: Tr.t("Minimal"),
            sub: Tr.t("Dots and icons, nothing more"),
            values: { "panel.style": "float", "panel.workspaces": "dots", "panel.island": "capsule", "panel.clock": "display", "panel.status": "minimal" }
        },
        {
            id: "workbench",
            name: Tr.t("Workbench"),
            sub: Tr.t("The apps of each workspace"),
            values: { "panel.style": "hug", "panel.workspaces": "apps", "panel.island": "notch", "panel.clock": "accent", "panel.status": "together" }
        }
    ]

    function matches(preset) {
        for (const key in preset.values) {
            if (Settings.get(key, "") !== preset.values[key])
                return false;
        }
        return true;
    }

    function use(preset) {
        for (const key in preset.values)
            Settings.set(key, preset.values[key]);
    }

    spacing: 14

    // ------------------------------------------------ the screen in small
    Rectangle {
        id: frame

        width: root.width
        height: 168
        radius: 20
        color: Qt.tint(Qt.alpha(Theme.glassBase, 0.3), Qt.alpha(Theme.text, 0.045))
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.08)

        ClippingRectangle {
            id: screenCopy

            // The real parts at their real size, on a screen this wide, shown smaller.
            readonly property real scaleBy: 0.86
            readonly property real virtualWidth: width / scaleBy
            readonly property int edgeGap: Settings.hug ? -1 : 10
            readonly property int sideGap: Settings.hug ? -1 : 14

            anchors.fill: parent
            anchors.margins: 12
            radius: 12
            color: Theme.glassBase

            Image {
                anchors.fill: parent
                source: Wallpapers.shownImage === "" ? "" : "file://" + Wallpapers.shownImage
                sourceSize.width: 960
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // A soft shade along the edge with the panel, as the blur behind it gives on screen.
            Rectangle {
                width: parent.width
                height: 54
                y: Settings.bottom ? parent.height - height : 0
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Theme.glassBase, Settings.bottom ? 0 : 0.35)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Theme.glassBase, Settings.bottom ? 0.35 : 0)
                    }
                }
            }

            Item {
                id: virtualScreen

                width: screenCopy.virtualWidth
                height: screenCopy.height / screenCopy.scaleBy
                scale: screenCopy.scaleBy
                transformOrigin: Item.TopLeft
                enabled: false

                Ribbon {
                    x: screenCopy.sideGap
                    y: Settings.bottom ? parent.height - height - screenCopy.edgeGap : screenCopy.edgeGap
                    preview: true
                    screenInfo: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
                }

                Island {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property int gap: capsule ? (Settings.hug ? 4 : 8) : 0
                    y: Settings.bottom ? parent.height - height - gap : gap
                    preview: true
                }

                StatusPill {
                    anchors.right: parent.right
                    anchors.rightMargin: screenCopy.sideGap
                    y: Settings.bottom ? parent.height - height - screenCopy.edgeGap : screenCopy.edgeGap
                    preview: true
                }

                // The screen's own corners, as the panel draws them in the corners shape.
                Repeater {
                    model: Settings.hug ? [[false, false], [true, false], [false, true], [true, true]] : []

                    delegate: EdgeCurve {
                        required property var modelData

                        size: 23
                        x: modelData[0] ? virtualScreen.width - size : 0
                        y: modelData[1] ? virtualScreen.height - size : 0
                        flipX: modelData[0]
                        flipY: modelData[1]
                        color: "black"
                    }
                }
            }
        }
    }

    // ------------------------------------------------ ready-made looks
    Row {
        id: presetRow

        width: root.width
        spacing: 10

        Repeater {
            model: root.presets

            delegate: Rectangle {
                id: presetCard

                required property var modelData
                readonly property bool on: root.matches(modelData)

                width: (presetRow.width - presetRow.spacing * 3) / 4
                height: 74
                radius: 16
                color: on ? Qt.alpha(Theme.accent, 0.2) : Qt.alpha(Theme.text, presetArea.containsMouse ? 0.08 : 0.04)
                border.width: 1
                border.color: on ? Theme.accent : Qt.alpha(Theme.text, 0.08)
                scale: presetArea.pressed ? 0.97 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }

                Column {
                    x: 14
                    width: parent.width - 28
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Row {
                        spacing: 7

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: presetCard.on
                            name: "check"
                            size: 15
                            color: Theme.accent
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: presetCard.modelData.name
                            size: 14
                            font.weight: Font.DemiBold
                        }
                    }
                    Label {
                        width: parent.width
                        text: presetCard.modelData.sub
                        color: Theme.muted
                        size: 12
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: presetArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.use(presetCard.modelData)
                }
            }
        }
    }
}
