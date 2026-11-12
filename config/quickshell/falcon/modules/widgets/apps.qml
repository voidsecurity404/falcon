import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The dock's pinned apps, then other common ones found on this computer, each started or brought
// forward with one press. A dot marks an app that has a window open. Forms: grid, row.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "grid"
    readonly property bool row: form === "row"
    readonly property int slots: row ? 6 : 8
    readonly property var extra: ["firefox", "org.telegram.desktop", "kitty", "thunar", "spotify", "com.microsoft.VSCode", "mpv", "steam", "org.kde.kdeconnect.app", "btop"]
    readonly property var apps: {
        const out = [];
        for (const id of Settings.get("dock.pinned", []).concat(extra)) {
            const entry = DesktopEntries.heuristicLookup(id);
            if (entry && !out.some(a => a.entry === entry))
                out.push({ id: id, entry: entry });
            if (out.length >= slots)
                break;
        }
        return out;
    }
    readonly property var running: {
        const ids = {};
        for (const key of Object.keys(Niri.windows))
            ids[(Niri.windows[key].app_id || "").toLowerCase()] = Niri.windows[key].id;
        return ids;
    }

    function windowOf(app) {
        const keys = [app.id, app.entry.id, app.entry.startupClass || ""].map(k => (k || "").toLowerCase().replace(/\.desktop$/, ""));
        for (const k of keys)
            if (k !== "" && root.running[k] !== undefined)
                return root.running[k];
        return -1;
    }

    WidgetCaption {
        visible: !root.row
        x: 20
        y: 18
        icon: "widgets"
        text: Tr.t("Apps")
    }

    Grid {
        id: grid

        readonly property real cellW: (width - (columns - 1) * spacing) / columns

        x: 14
        y: root.row ? 12 : 52
        width: root.width - 28
        columns: root.row ? 6 : 4
        spacing: 4

        Repeater {
            model: root.apps

            Item {
                id: app

                required property var modelData
                readonly property int windowId: root.windowOf(modelData)

                width: grid.cellW
                height: root.row ? root.height - 24 : (root.height - 52 - 14 - 4) / 2

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: Qt.alpha(Theme.text, hot.hovered ? 0.1 : 0)

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }
                Item {
                    id: iconBox

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.row ? 10 : 8
                    width: 48
                    height: 48

                    RectangularShadow {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 14
                        blur: hot.hovered ? 18 : 10
                        offset.y: hot.hovered ? 6 : 3
                        color: Qt.alpha("#000000", 0.35)
                    }
                    IconImage {
                        anchors.fill: parent
                        source: Quickshell.iconPath(app.modelData.entry.icon, "application-x-executable")
                        asynchronous: true
                    }
                    transform: Translate {
                        y: hot.down ? 1 : hot.hovered ? -4 : 0

                        Behavior on y {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutBack
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: iconBox.y + iconBox.height + 4
                    width: app.windowId >= 0 ? 6 : 0
                    height: 4
                    radius: 2
                    color: Theme.accent
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    width: Math.min(implicitWidth, parent.width - 6)
                    text: app.modelData.entry.name
                    size: 11
                    color: hot.hovered ? Theme.text : Theme.muted
                }
                WidgetHot {
                    id: hot

                    anchors.fill: parent
                    onClicked: {
                        if (app.windowId >= 0)
                            Niri.action("focus-window", "--id", String(app.windowId));
                        else
                            app.modelData.entry.execute();
                    }
                }
            }
        }
    }
}
