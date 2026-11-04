import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services
import "../services/tools.js" as Tools

// Clipboard history: the newest is on top, typing filters it and Enter copies the row again.
LazyLoader {
    active: Ui.popup === "clipboard"

    PanelWindow {
        id: root

        property string query: ""
        property int selected: 0
        property var clips: []
        property var lastPointer: null

        readonly property var results: {
            const q = query.trim().toLowerCase();
            // Ties keep the original order, so the newest stays on top.
            const rows = clips.map((clip, order) => ({
                        clip: clip,
                        order: order,
                        rank: Tools.score(clip.text, q, "")
                    })).filter(r => r.rank > 0).sort((a, b) => b.rank - a.rank || a.order - b.order);
            const exact = rows.some(r => r.rank >= 300);
            return rows.filter(r => !exact || r.rank >= 300).slice(0, 10).map(r => r.clip);
        }

        function execute(index) {
            const clip = results[index];
            if (!clip)
                return;
            Ui.popup = "";
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", clip.id]);
            Toasts.show(Tr.t("Copied"), clip.text, "check");
        }

        // A row left under the pointer stays unselected until the pointer really moves.
        function pointerMoved(index, point) {
            if (lastPointer && Math.abs(lastPointer.x - point.x) + Math.abs(lastPointer.y - point.y) > 3)
                selected = index;
            lastPointer = point;
        }

        function report() {
            Ui.launcherRows = results.map(r => "Clipboard|" + r.text);
        }

        onSelectedChanged: Ui.launcherSelected = selected
        onResultsChanged: {
            selected = Math.min(selected, Math.max(0, results.length - 1));
            report();
        }
        Component.onCompleted: {
            Ui.launcherSelected = 0;
            report();
        }

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "niri-desk-clipboard"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Connections {
            target: Ui
            function onLauncherInject(text) {
                input.text = text;
            }
        }

        Process {
            command: ["cliphist", "list"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    root.clips = text.split("\n").filter(l => /^\d+\t/.test(l)).map(l => {
                        const tab = l.indexOf("\t");
                        return {
                            id: l.slice(0, tab),
                            text: l.slice(tab + 1).trim()
                        };
                    });
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.popup = ""
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.17)
            width: Math.min(680, parent.width - 40)
            height: column.implicitHeight
            radius: 17
            color: Theme.pill

            opacity: 0
            scale: 0.98
            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: column

                width: parent.width

                TextInput {
                    id: input

                    width: parent.width
                    leftPadding: 24
                    rightPadding: 24
                    topPadding: 20
                    bottomPadding: 20
                    focus: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.family: Theme.sans
                    font.pixelSize: 24
                    font.weight: Font.Light
                    onTextChanged: {
                        root.query = text;
                        root.selected = 0;
                    }
                    Keys.onEscapePressed: Ui.popup = ""
                    Keys.onReturnPressed: root.execute(root.selected)
                    Keys.onEnterPressed: root.execute(root.selected)
                    Keys.onDownPressed: root.selected = Math.min(root.results.length - 1, root.selected + 1)
                    Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                    Keys.onTabPressed: root.selected = (root.selected + 1) % Math.max(1, root.results.length)

                    Label {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text === ""
                        text: Tr.t("Search clipboard history…")
                        color: Qt.alpha(Theme.text, 0.36)
                        size: 24
                        font.weight: Font.Light
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.text, 0.08)
                }

                Column {
                    width: parent.width - 16
                    x: 8
                    topPadding: 8
                    bottomPadding: 8

                    Label {
                        visible: root.results.length === 0
                        leftPadding: 14
                        topPadding: 8
                        bottomPadding: 8
                        text: Tr.t("Clipboard history is empty")
                        color: Theme.muted
                    }

                    Repeater {
                        model: root.results

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property bool isSelected: index === root.selected

                            width: parent.width
                            height: 40
                            radius: 9
                            color: isSelected ? Theme.accent : "transparent"

                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.text
                                color: row.isSelected ? Theme.accentText : Theme.text
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: mouse => root.pointerMoved(row.index, mapToItem(null, mouse.x, mouse.y))
                                onClicked: root.execute(row.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
