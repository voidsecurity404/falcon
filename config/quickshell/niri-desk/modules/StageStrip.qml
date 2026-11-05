import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Stage strip: the other workspaces of this screen as stacks of window pictures at the left edge.
// A workspace is one stage. Windows make room for the strip, and a click brings a stage in.
PanelWindow {
    id: root

    readonly property string outputName: screen ? screen.name : ""
    readonly property int stripWidth: Math.max(130, Math.min(260, Number(Settings.get("stages.width", 176)) || 176))
    readonly property bool wanted: Ui.stagesOn && !Ui.zen
    readonly property string captures: Quickshell.env("XDG_RUNTIME_DIR") + "/niri-desk-switcher/"
    readonly property var stages: {
        const all = Object.values(Niri.windows);
        return Niri.workspacesOn(outputName).filter(w => !w.is_active).map(w => ({
                    idx: w.idx,
                    id: w.id,
                    windows: all.filter(win => win.workspace_id === w.id).sort((a, b) => a.id - b.id)
                })).filter(s => s.windows.length > 0);
    }
    // Pictures are taken while a window has focus, so they are read again only when the stages change.
    readonly property string stageKey: stages.map(s => s.windows.map(w => w.id).join(",")).join(";") + "|" + Niri.focusedWindowId
    property int pictureEpoch: 0
    property var pictures: ({})

    onStageKeyChanged: {
        if (wanted)
            pictureList.running = true;
    }
    onWantedChanged: {
        if (wanted)
            pictureList.running = true;
    }

    Process {
        id: pictureList

        command: ["sh", "-c", 'ls -- "$XDG_RUNTIME_DIR/niri-desk-switcher" 2>/dev/null']
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const name of text.split("\n"))
                    found[name] = true;
                root.pictures = found;
                root.pictureEpoch += 1;
            }
        }
    }

    visible: wanted
    anchors {
        top: true
        bottom: true
        left: true
    }
    margins.top: Settings.bottom ? 0 : 52
    margins.bottom: Settings.bottom ? 52 : 0
    implicitWidth: stripWidth
    exclusiveZone: stripWidth
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "niri-desk-stages"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region {
        item: plate
        radius: plate.radius
    }


    // One glass plate: the labels must read over a light wallpaper and over desktop widgets.
    Rectangle {
        id: plate

        anchors.fill: parent
        anchors.margins: 6
        radius: 20
        color: Qt.alpha(Theme.surface, Math.max(0.5, Theme.panel.a))
        border.width: 1
        border.color: Theme.panelEdge
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.stages
            objectProp: "id"
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 220
            }
            NumberAnimation {
                property: "x"
                from: -40
                to: 0
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        delegate: Item {
            id: stage

            required property var modelData
            readonly property var shownWindows: modelData.windows.slice(-3)
            readonly property int cardWidth: width - 16
            readonly property int cardHeight: Math.round(cardWidth * 0.62)

            width: ListView.view.width
            height: cardHeight + 34
            scale: area.pressed ? 0.96 : area.containsMouse ? 1.03 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: stage.shownWindows

                delegate: Rectangle {
                    id: thumb

                    required property var modelData
                    required property int index

                    readonly property int depth: stage.shownWindows.length - 1 - index

                    x: 8 + depth * 5
                    y: 8 - depth * 5
                    z: index
                    width: stage.cardWidth - depth * 10
                    height: stage.cardHeight
                    radius: 12
                    color: Qt.alpha(Theme.surface, 0.82)
                    border.width: 1
                    border.color: Theme.panelEdge
                    clip: true

                    Image {
                        id: shot

                        anchors.fill: parent
                        anchors.margins: 1
                        source: root.pictures[thumb.modelData.id + ".jpg"] ? "file://" + root.captures + thumb.modelData.id + ".jpg?" + root.pictureEpoch : ""
                        sourceSize.width: 360
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        visible: status === Image.Ready
                    }
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 40
                        visible: shot.status !== Image.Ready
                        source: {
                            const entry = DesktopEntries.heuristicLookup(thumb.modelData.app_id || "");
                            return Quickshell.iconPath(entry ? entry.icon : (thumb.modelData.app_id || ""), true);
                        }
                    }
                }
            }
            Label {
                x: 8
                y: stage.cardHeight + 13
                width: stage.cardWidth
                text: {
                    const top = stage.modelData.windows[stage.modelData.windows.length - 1];
                    const entry = DesktopEntries.heuristicLookup(top.app_id || "");
                    const name = entry ? entry.name : (top.app_id || "");
                    const more = stage.modelData.windows.length - 1;
                    return more > 0 ? name + "  +" + more : name;
                }
                size: 12
                color: Theme.text
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.action("focus-workspace", String(stage.modelData.idx))
            }
        }
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - 28
        visible: list.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        text: Tr.t("{key} sends a column to a new stage").replace("{key}", Settings.get("binds.stageNew", "Mod+Shift+G"))
        color: Theme.text
        size: 12
    }
}
