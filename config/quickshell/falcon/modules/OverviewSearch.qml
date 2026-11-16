import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services
import "../services/tools.js" as Tools

// Find a window in the overview (Mod+O) by typing: a glass field at the top of the focused
// screen while the overview is open (`windows.overviewSearch`). The overview itself and its
// motion stay niri's. Each match is focused as it is chosen, so the overview glides to it;
// Enter closes the overview on it, Esc clears the text, then closes, and with no text the arrow
// keys, Enter and Esc do what niri does in the overview.
//
// niri gives its own overview keys (Esc, Enter, arrows) only while the overview holds the
// keyboard; this field takes the keyboard (exclusive, on the Top layer, which niri focuses in
// the overview), so those keys are passed on through Niri.request() here.
PanelWindow {
    id: root

    readonly property bool wanted: Niri.overview && Settings.get("windows.overviewSearch", true) === true
    property string query: ""
    property int selected: 0
    property int startWindow: -1
    property real reveal: 0

    readonly property var matches: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        const list = [];
        for (const id in Niri.windows) {
            const w = Niri.windows[id];
            const app = w.app_id || "";
            const entry = DesktopEntries.heuristicLookup(app);
            const name = entry && entry.name ? entry.name : app;
            // Titles only by whole text (a scattered-letter match in a long title is noise);
            // the app's name also by its letters in order, as in the app menu.
            const rank = Math.max(root.within(w.title || "", q), root.within(name, q) + 50, root.within(app, q), Math.min(200, Tools.score(name, q, "")));
            if (rank > 0)
                list.push({ id: w.id, title: w.title || name, app: name, icon: entry ? entry.icon : "", workspace: w.workspace_id, rank: rank, focusedAt: w.focus_timestamp ? (w.focus_timestamp.secs || 0) : 0 });
        }
        list.sort((a, b) => b.rank - a.rank || b.focusedAt - a.focusedAt);
        return list.slice(0, 7);
    }

    // 1000 at the start, 800 at a word start, less further in; also typed on the other layout.
    function within(text, q) {
        const hay = (text || "").toLowerCase();
        let best = 0;
        for (const needle of [q, Tools.swapLayout(q)]) {
            const at = hay.indexOf(needle);
            if (at === 0)
                best = Math.max(best, 1000);
            else if (at > 0)
                best = Math.max(best, /[\s\-_.:—|]/.test(hay[at - 1]) ? 800 : 500 - Math.min(at, 300));
        }
        return best;
    }

    function workspaceNumber(id) {
        const ws = Niri.workspaces.find(w => w.id === id);
        return ws ? ws.idx : "";
    }

    function choose(index) {
        if (matches.length === 0)
            return;
        selected = (index + matches.length) % matches.length;
        Niri.request({ FocusWindow: { id: matches[selected].id } }, ["focus-window", "--id", String(matches[selected].id)]);
    }

    function closeOverview() {
        Niri.request({ CloseOverview: {} }, ["close-overview"]);
    }

    onMatchesChanged: {
        if (matches.length > 0)
            choose(0);
        else
            selected = 0;
    }

    onWantedChanged: {
        revealAnimation.stop();
        revealAnimation.to = wanted ? 1 : 0;
        revealAnimation.duration = wanted ? 260 : 140;
        revealAnimation.start();
        if (wanted) {
            query = "";
            field.text = "";
            selected = 0;
            startWindow = Niri.focusedWindowId;
            field.forceActiveFocus();
        }
    }

    NumberAnimation {
        id: revealAnimation

        target: root
        property: "reveal"
        easing.type: Easing.OutCubic
    }

    visible: wanted || reveal > 0.01
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
    anchors.top: true
    margins.top: 26
    implicitWidth: 480
    implicitHeight: card.height + 24
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "falcon-overview-search"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region {
        item: card
        radius: card.radius
    }

    Rectangle {
        id: card

        x: 12
        width: parent.width - 24
        height: column.implicitHeight + 16
        y: (1 - root.reveal) * -10
        opacity: root.reveal
        radius: 24
        border.width: 1
        border.color: Theme.panelEdge
        color: Qt.alpha(Theme.glassBase, Math.max(0.7, Theme.glassOpacity))

        Behavior on height {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: column

            x: 8
            y: 8
            width: parent.width - 16
            spacing: 4

            Item {
                width: parent.width
                height: 40

                Icon {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 17
                    color: root.query === "" ? Theme.muted : Theme.accent
                }
                TextInput {
                    id: field

                    x: 40
                    width: parent.width - 52
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Qt.alpha(Theme.accent, 0.4)
                    font.family: Theme.sans
                    font.pixelSize: 15
                    clip: true
                    focus: true
                    onTextChanged: root.query = text

                    Keys.onPressed: event => {
                        const empty = root.query.trim() === "";
                        switch (event.key) {
                        case Qt.Key_Escape:
                            if (!empty) {
                                text = "";
                                if (root.startWindow >= 0)
                                    Niri.request({ FocusWindow: { id: root.startWindow } }, null);
                            } else {
                                root.closeOverview();
                            }
                            event.accepted = true;
                            return;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.closeOverview();
                            event.accepted = true;
                            return;
                        case Qt.Key_Down:
                        case Qt.Key_Tab:
                            if (empty)
                                Niri.request({ FocusWindowOrWorkspaceDown: {} }, ["focus-window-or-workspace-down"]);
                            else
                                root.choose(root.selected + 1);
                            event.accepted = true;
                            return;
                        case Qt.Key_Up:
                        case Qt.Key_Backtab:
                            if (empty)
                                Niri.request({ FocusWindowOrWorkspaceUp: {} }, ["focus-window-or-workspace-up"]);
                            else
                                root.choose(root.selected - 1);
                            event.accepted = true;
                            return;
                        case Qt.Key_Left:
                            if (empty) {
                                Niri.request({ FocusColumnLeft: {} }, ["focus-column-left"]);
                                event.accepted = true;
                            }
                            return;
                        case Qt.Key_Right:
                            if (empty) {
                                Niri.request({ FocusColumnRight: {} }, ["focus-column-right"]);
                                event.accepted = true;
                            }
                            return;
                        }
                    }
                }
                Label {
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: Tr.t("Type to find a window")
                    color: Theme.muted
                    size: 15
                }
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.query.trim() !== ""
                    text: root.matches.length === 0 ? Tr.t("Nothing found") : ""
                    color: Theme.muted
                    size: 12
                }
            }

            Repeater {
                model: root.matches

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool on: index === root.selected

                    width: column.width
                    height: 46
                    radius: 16
                    color: on ? Qt.alpha(Theme.accent, 0.2) : rowArea.containsMouse ? Qt.alpha(Theme.text, 0.07) : "transparent"

                    IconImage {
                        id: appIcon

                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 26
                        source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                        visible: source !== ""
                    }
                    Icon {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !appIcon.visible
                        name: "windows"
                        size: 18
                        color: Theme.muted
                    }
                    Column {
                        x: 46
                        width: parent.width - 46 - chip.width - 22
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            width: parent.width
                            text: row.modelData.title
                            size: 13
                            font.weight: row.on ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            text: row.modelData.app
                            color: Theme.muted
                            size: 11
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        id: chip

                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: chipText.implicitWidth + 14
                        height: 22
                        radius: 8
                        color: Qt.alpha(row.on ? Theme.accent : Theme.text, 0.14)

                        Label {
                            id: chipText

                            anchors.centerIn: parent
                            text: root.workspaceNumber(row.modelData.workspace)
                            size: 11
                            font.family: Theme.mono
                            color: row.on ? Theme.accent : Theme.muted
                        }
                    }
                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.choose(row.index);
                            root.closeOverview();
                        }
                    }
                }
            }
        }
    }
}
