import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
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
        property var pointerStart: null
        property bool pointerLive: false
        property bool thumbsReady: false
        // Pictures are decoded to memory-backed storage, so copies of them do not stay on the disk.
        readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/niri-desk-clip"

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

        // A row left under the pointer stays unselected until the pointer has really moved.
        function pointerMoved(index, point) {
            if (!pointerStart)
                pointerStart = point;
            else if (Math.abs(pointerStart.x - point.x) + Math.abs(pointerStart.y - point.y) > 3)
                pointerLive = true;
            if (pointerLive)
                selected = index;
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
                        const raw = l.slice(tab + 1).trim();
                        const picture = raw.match(/^\[\[ binary data (.+) (png|jpe?g|webp|bmp|gif) (\d+x\d+) \]\]$/);
                        return {
                            id: l.slice(0, tab),
                            text: picture ? Tr.t("Image") + " " + picture[3] + " · " + picture[1] : raw,
                            image: !!picture
                        };
                    });
                    thumbs.command = ["sh", "-c", 'umask 077; mkdir -p "$0" && cd "$0" || exit 1; for f in *; do case " $* " in *" $f "*) ;; *) rm -f -- "$f";; esac; done; for id; do [ -s "$id" ] || cliphist decode "$id" > "$id"; done', root.thumbDir].concat(root.clips.filter(c => c.image).slice(0, 20).map(c => c.id));
                    thumbs.running = true;
                }
            }
        }

        Process {
            id: thumbs

            onExited: root.thumbsReady = true
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
                            height: modelData.image ? 64 : 40
                            radius: 9
                            color: isSelected ? Theme.accent : "transparent"

                            ClippingRectangle {
                                id: thumb

                                visible: row.modelData.image
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 84
                                height: 52
                                radius: 6
                                color: Qt.alpha(Theme.text, 0.08)

                                Image {
                                    anchors.fill: parent
                                    source: row.modelData.image && root.thumbsReady ? "file://" + root.thumbDir + "/" + row.modelData.id : ""
                                    sourceSize: Qt.size(168, 104)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                }
                            }

                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: row.modelData.image ? 104 : 14
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
