import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Clickable side of desktop widgets, below windows: right click menu, buttons and notes.
// Edit mode lifts this layer above windows. What you normally see is in WidgetFace.
PanelWindow {
    id: root

    property string outputName: ""

    readonly property var workspace: Niri.activeWorkspaceOn(outputName)
    readonly property bool wanted: Widgets.enabled && Widgets.loaded && !Niri.overview && (!Widgets.firstOnly || (!!workspace && workspace.idx === 1))
    readonly property bool focusedScreen: Niri.focusedOutput === "" || Niri.focusedOutput === outputName
    readonly property int topInset: Widgets.topInset
    readonly property int bottomInset: Widgets.bottomInset
    readonly property var plated: Widgets.ids.filter(id => {
        const w = Widgets.get(id);
        const i = w ? Widgets.info(w.type) : null;
        return !!i && i.plate;
    })
    property bool menuOpen: false
    property point menuAt: Qt.point(0, 0)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: wanted || Widgets.editMode
    WlrLayershell.layer: Widgets.editMode ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "falcon-widgets"
    WlrLayershell.keyboardFocus: Widgets.editMode && focusedScreen ? WlrKeyboardFocus.Exclusive : Widgets.noteHovered || Widgets.noteFocused ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (!visible)
            menuOpen = false;
    }

    Connections {
        target: Widgets
        function onEditModeChanged() {
            root.resetArmed = false;
            if (Widgets.editMode)
                root.menuOpen = false;
        }
    }

    // Tahrirda vidjet shishasi shu qatlamda, orqasi xiralashadi.
    BackgroundEffect.blurRegion: Region {
        Region {
            regions: Widgets.editMode ? blurs.instances : []
        }
        Region {
            item: Widgets.editMode && Widgets.galleryOpen && root.focusedScreen ? gallery.panel : null
            radius: 26
        }
    }
    Variants {
        id: blurs

        model: root.plated

        Region {
            required property string modelData

            readonly property int index: Widgets.ids.indexOf(modelData)

            item: hosts.count > index && index >= 0 ? hosts.itemAt(index) : null
            radius: item ? 22 * item.factor : 22
        }
    }

    // Bo'sh joyni o'ng tugma bilan bosish menyuni ochadi.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && !Widgets.editMode) {
                root.menuAt = Qt.point(Math.min(mouse.x, root.width - 230), Math.min(mouse.y, root.height - 150));
                root.menuOpen = true;
            } else {
                root.menuOpen = false;
            }
        }
    }

    // Tahrirlash: fon qorayadi va to'r ko'rinadi.
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.pill, 0.55)
        opacity: Widgets.editMode ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }

        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.fillStyle = Qt.alpha(Theme.text, 0.14);
                for (let x = 0; x < width; x += 32)
                    for (let y = 0; y < height; y += 32)
                        ctx.fillRect(x, y, 1.5, 1.5);
            }
        }
    }

    Repeater {
        id: hosts

        model: Widgets.ids

        delegate: WidgetHost {
            required property string modelData

            widgetId: modelData
            areaWidth: root.width - 32
            areaHeight: root.height - root.bottomInset
            topInset: root.topInset
        }
    }

    // O'ng tugma menyusi
    Rectangle {
        x: root.menuAt.x
        y: root.menuAt.y
        width: 220
        height: menuColumn.implicitHeight + 12
        radius: 14
        color: Theme.pill
        border.width: 1
        border.color: Theme.panelEdge
        opacity: root.menuOpen ? 1 : 0
        scale: root.menuOpen ? 1 : 0.94
        visible: opacity > 0
        transformOrigin: Item.TopLeft

        Behavior on opacity {
            NumberAnimation {
                duration: 130
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 1.35, 0.4, 1, 1, 1]
            }
        }

        Column {
            id: menuColumn

            x: 6
            y: 6
            width: parent.width - 12

            Repeater {
                model: [
                    {
                        label: Tr.t("Edit widgets"),
                        icon: "windows",
                        run: () => Widgets.editMode = true
                    },
                    {
                        label: Tr.t("Change wallpaper"),
                        icon: "wallpaper",
                        run: () => Ui.popup = "wallpapers"
                    },
                    {
                        label: Tr.t("Settings"),
                        icon: "settings",
                        run: () => Ui.settingsOpen = true
                    }
                ]

                delegate: Rectangle {
                    id: menuRow

                    required property var modelData

                    width: parent.width
                    height: 38
                    radius: 10
                    color: menuArea.containsMouse ? Qt.alpha(Theme.accent, 0.2) : "transparent"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        spacing: 10

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: menuRow.modelData.icon
                            size: 15
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuRow.modelData.label
                            size: 13
                        }
                    }
                    MouseArea {
                        id: menuArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.menuOpen = false;
                            menuRow.modelData.run();
                        }
                    }
                }
            }
        }
    }

    property bool resetArmed: false

    Timer {
        id: resetDisarm

        interval: 3500
        onTriggered: root.resetArmed = false
    }

    // Tahrirlash paneli. Above the widgets, whose own z is 1 to 10, so the gallery covers them.
    Item {
        anchors.fill: parent
        z: 100
        focus: Widgets.editMode
        Keys.onEscapePressed: {
            if (Widgets.galleryOpen)
                Widgets.galleryOpen = false;
            else
                Widgets.editMode = false;
        }
        visible: Widgets.editMode && root.focusedScreen

        // Under the bar, so the bar stays pressable.
        WidgetGallery {
            id: gallery

            anchors.fill: parent
            bottomSpace: bar.height + 26 + 14
        }

        Rectangle {
            id: bar

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            width: barRow.implicitWidth + 16
            height: 52
            radius: 18
            color: Theme.pill
            border.width: 1
            border.color: Theme.panelEdge

            Row {
                id: barRow

                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: [
                        {
                            label: Widgets.galleryOpen ? Tr.t("Close gallery") : Tr.t("Add widget"),
                            main: false,
                            run: () => Widgets.galleryOpen = !Widgets.galleryOpen
                        },
                        {
                            label: root.resetArmed ? Tr.t("Press again to reset") : Tr.t("Reset layout"),
                            main: false,
                            danger: root.resetArmed,
                            run: () => {
                                if (root.resetArmed) {
                                    root.resetArmed = false;
                                    Widgets.reset();
                                } else {
                                    root.resetArmed = true;
                                    resetDisarm.restart();
                                }
                            }
                        },
                        {
                            label: Tr.t("Done"),
                            main: true,
                            run: () => Widgets.editMode = false
                        }
                    ]

                    delegate: Rectangle {
                        id: barButton

                        required property var modelData

                        width: barLabel.implicitWidth + 28
                        height: 36
                        radius: 12
                        color: modelData.main ? Theme.accent : modelData.danger ? Theme.error : Qt.alpha(Theme.text, barArea.containsMouse ? 0.14 : 0.07)
                        scale: barArea.pressed ? 0.95 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 110
                            }
                        }

                        Label {
                            id: barLabel

                            anchors.centerIn: parent
                            text: barButton.modelData.label
                            color: barButton.modelData.main ? Theme.accentText : barButton.modelData.danger ? Theme.pill : Theme.text
                            size: 13
                        }
                        MouseArea {
                            id: barArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barButton.modelData.run()
                        }
                    }
                }
            }
        }
    }
}
