import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Qiyshiq kartalar: fon tanlanganda ranglar ham undan olinadi.
LazyLoader {
    active: Ui.popup === "wallpapers"

    // Reading this starts the service with the shell, so the pictures are ready before the first opening.
    readonly property int known: Wallpapers.liveFiles.length + Wallpapers.imageFiles.length

    PanelWindow {
        id: root

        readonly property string liveDir: Settings.wallpaperDir + "/Live"

        // 0: jonli fonlar, 1: oddiy rasmlar. Har biri o'z o'rnini eslab qoladi.
        property int tab: 1
        property var marks: [0, 0]
        // Once the user has moved, a late answer about the current wallpaper must not move the carousel.
        property bool moved: false
        readonly property var files: tab === 0 ? Wallpapers.liveFiles : Wallpapers.imageFiles
        property int selected: 0
        onSelectedChanged: Ui.pickerSelected = selected
        onFilesChanged: Ui.pickerFiles = files.length
        onTabChanged: Ui.pickerTab = tab
        Component.onCompleted: {
            startAtCurrent();
            Ui.pickerSelected = selected;
            Ui.pickerFiles = files.length;
            Ui.pickerTab = tab;
            Wallpapers.refresh();
        }
        readonly property real cardHeight: Math.min(620, height * 0.62)
        readonly property real skew: 0.12

        Connections {
            target: Ui
            function onPickerTabChanged() {
                root.setTab(Ui.pickerTab);
            }
        }

        Connections {
            target: Wallpapers
            function onCurrentChanged() {
                if (!root.moved)
                    root.startAtCurrent();
            }
        }

        // Starts on the tab of the current wallpaper, at that wallpaper.
        function startAtCurrent() {
            const live = Wallpapers.liveFiles.indexOf(Wallpapers.currentLive);
            const image = Wallpapers.imageFiles.indexOf(Wallpapers.currentImage);
            marks = [Math.max(0, live), Math.max(0, image)];
            tab = live >= 0 ? 0 : 1;
            selected = marks[tab];
        }

        function step(by) {
            moved = true;
            selected = Math.max(0, Math.min(files.length - 1, selected + by));
        }

        function setTab(next) {
            if (next === tab)
                return;
            moved = true;
            const saved = marks.slice();
            saved[tab] = selected;
            marks = saved;
            tab = next;
            selected = Math.min(marks[next], Math.max(0, files.length - 1));
        }

        function apply(index) {
            const path = files[index];
            if (!path)
                return;
            Wallpapers.chosen(path, tab === 0);
            Ui.popup = "";
            Ui.run("niri-desk-wallpaper", path);
        }

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
        color: Qt.rgba(0, 0, 0, 0.3)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "niri-desk-picker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.popup = ""
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Ui.popup = ""

            // Sensorli panel mayda qadamlar yuboradi, shuning uchun yig'ib hisoblaymiz.
            WheelHandler {
                property real sum: 0

                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    sum += event.angleDelta.y + event.angleDelta.x;
                    if (Math.abs(sum) < 120)
                        return;
                    root.step(sum > 0 ? -1 : 1);
                    sum = 0;
                }
            }

            Keys.onLeftPressed: root.step(-1)
            Keys.onRightPressed: root.step(1)
            Keys.onTabPressed: root.setTab(1 - root.tab)
            Keys.onBacktabPressed: root.setTab(1 - root.tab)
            Keys.onReturnPressed: root.apply(root.selected)
            Keys.onEnterPressed: root.apply(root.selected)

            Label {
                anchors.centerIn: parent
                visible: root.files.length === 0
                text: Tr.t("No wallpapers found:") + " " + (root.tab === 0 ? root.liveDir : Settings.wallpaperDir)
                color: "white"
                size: 18
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: carousel.top
                anchors.bottomMargin: 30
                spacing: 8

                Repeater {
                    model: [
                        { label: Tr.t("Live wallpapers"), icon: "play" },
                        { label: Tr.t("Wallpapers"), icon: "wallpaper" }
                    ]

                    delegate: Rectangle {
                        id: tabButton

                        required property var modelData
                        required property int index
                        readonly property bool active: root.tab === index

                        width: tabRow.implicitWidth + 40
                        height: 44
                        radius: 22
                        color: active ? Theme.accent : tabHover.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.45)
                        border.width: active ? 0 : 1
                        border.color: Qt.rgba(1, 1, 1, 0.14)

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }
                        }

                        Row {
                            id: tabRow

                            anchors.centerIn: parent
                            spacing: 9

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: tabButton.modelData.icon
                                size: 17
                                color: tabButton.active ? Theme.accentText : "white"
                            }

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tabButton.modelData.label
                                color: tabButton.active ? Theme.accentText : "white"
                                size: 15
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: tabHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setTab(tabButton.index)
                        }
                    }
                }
            }

            // Fonlar ko'p: tanlangani doim o'rtada, qolganlari yonga suriladi.
            ListView {
                id: carousel

                anchors.centerIn: parent
                width: parent.width
                height: root.cardHeight
                orientation: ListView.Horizontal
                spacing: -12
                interactive: false
                cacheBuffer: 1200
                model: root.files
                currentIndex: root.selected
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - 440) / 2
                preferredHighlightEnd: (width + 440) / 2
                highlightMoveDuration: 320
                highlightMoveVelocity: -1

                delegate: Item {
                    id: card

                    required property string modelData
                    required property int index

                    readonly property bool active: index === root.selected
                    readonly property string title: modelData.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]/g, " ")

                    z: active ? 2 : 1
                    width: active ? 440 : 340
                    height: root.cardHeight

                    Behavior on width {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.OutCubic
                        }
                    }

                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, -root.skew, 0, root.skew * root.cardHeight / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 15
                        color: Theme.pill

                        Image {
                            anchors.centerIn: parent
                            width: parent.width + root.cardHeight * root.skew + 8
                            height: parent.height
                            source: Wallpapers.thumbOf(card.modelData)
                            // The same size as in the service: this finds the picture already in memory.
                            sourceSize: Wallpapers.thumbSize
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, root.skew, 0, -root.skew * root.cardHeight / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                        }

                        // Nom yorug' rasm ustida ham o'qilsin.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 96
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: "transparent"
                                }
                                GradientStop {
                                    position: 1
                                    color: Qt.rgba(0, 0, 0, 0.62)
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 15
                        color: "transparent"
                        border.width: card.active ? 3 : 1
                        border.color: card.active ? "white" : cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.14)
                    }

                    Label {
                        x: 26
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 18
                        width: parent.width - 52
                        text: card.title
                        color: "white"
                        size: 17
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cardHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.apply(card.index)
                    }
                }
            }
        }
    }
}
