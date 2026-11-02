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

    PanelWindow {
        id: root

        property var files: []
        property int selected: 0
        onSelectedChanged: Ui.pickerSelected = selected
        onFilesChanged: Ui.pickerFiles = files.length
        Component.onCompleted: {
            Ui.pickerSelected = 0;
            Ui.pickerFiles = 0;
        }
        property var lastPointer: null
        readonly property real cardHeight: Math.min(620, height * 0.62)
        readonly property real skew: 0.12

        function pointerMoved(index, point) {
            if (lastPointer && Math.abs(lastPointer.x - point.x) + Math.abs(lastPointer.y - point.y) > 3)
                selected = index;
            lastPointer = point;
        }

        function apply(index) {
            const path = files[index];
            if (!path)
                return;
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

        Process {
            command: ["find", Settings.wallpaperDir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    root.files = text.trim().split("\n").filter(l => l.length > 0).sort();
                    current.running = true;
                }
            }
        }

        // Hozirgi fon rasmidan boshlaymiz.
        Process {
            id: current

            command: ["readlink", "-f", Ui.home + "/.local/state/niri-desk/wallpaper"]
            stdout: StdioCollector {
                onStreamFinished: root.selected = Math.max(0, root.files.indexOf(text.trim()))
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.popup = ""
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Ui.popup = ""
            Keys.onLeftPressed: root.selected = Math.max(0, root.selected - 1)
            Keys.onRightPressed: root.selected = Math.min(root.files.length - 1, root.selected + 1)
            Keys.onReturnPressed: root.apply(root.selected)
            Keys.onEnterPressed: root.apply(root.selected)

            Label {
                anchors.centerIn: parent
                visible: root.files.length === 0
                text: Tr.t("No wallpapers found:") + " " + Settings.wallpaperDir
                color: "white"
                size: 18
            }

            Row {
                anchors.centerIn: parent
                spacing: -12

                Repeater {
                    model: root.files

                    delegate: Item {
                        id: card

                        required property string modelData
                        required property int index

                        readonly property bool active: index === root.selected
                        readonly property string title: modelData.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]/g, " ")

                        z: active ? 2 : 1
                        width: Math.min(active ? 440 : 340, (root.width - 80) / Math.max(1, root.files.length) * (active ? 1.25 : 0.95))
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
                                source: "file://" + card.modelData
                                sourceSize.height: root.cardHeight
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, root.skew, 0, -root.skew * root.cardHeight / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 15
                            color: "transparent"
                            border.width: card.active ? 3 : 1
                            border.color: card.active ? "white" : Qt.rgba(1, 1, 1, 0.14)
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
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => root.pointerMoved(card.index, mapToItem(null, mouse.x, mouse.y))
                            onClicked: root.apply(card.index)
                        }
                    }
                }
            }
        }
    }
}
