import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The windows layout's dashboard is a start menu, after Windows 11's: a search field, a grid
// of pinned apps, a recommended list (the song playing, the weather, the latest notifications)
// and a footer with the user and the power button. It slides up out of the taskbar quickly and
// fades, and drops back the same way.
Rectangle {
    id: root

    property bool shown: false
    property real t: 0
    // The taskbar's top edge, where it slides out of.
    property real baseY: 0
    readonly property string user: Quickshell.env("USER") || ""
    readonly property var common: ["firefox", "kitty", "org.gnome.Nautilus", "thunar", "org.kde.dolphin", "code", "org.telegram.desktop", "mpv", "archmarket", "steam", "obsidian", "spotify", "discord", "gimp", "org.gnome.TextEditor", "btop", "org.pulseaudio.pavucontrol", "vlc"]
    // Pinned from the dock setting first, then well known apps, then the rest by name.
    readonly property var pinnedApps: {
        const all = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const out = [];
        const seen = {};
        const add = entry => {
            if (entry && !seen[entry.id] && out.length < 18) {
                seen[entry.id] = true;
                out.push(entry);
            }
        };
        for (const id of Settings.get("dock.pinned", []))
            add(DesktopEntries.heuristicLookup(id));
        for (const id of common)
            add(all.find(a => a.id === id || a.id === id + ".desktop"));
        for (const a of all.slice().sort((a, b) => a.name.localeCompare(b.name)))
            add(a);
        return out;
    }
    readonly property var recommended: {
        const list = [];
        if (Media.player)
            list.push({
                icon: "music",
                title: Media.title || Tr.t("Music"),
                sub: Media.player.trackArtist || Tr.t("Playing now"),
                run: () => Ui.popup = "control"
            });
        if (Weather.hasData)
            list.push({
                icon: Weather.icon(Weather.code, Weather.isDay),
                title: Weather.temperature + "° " + Weather.describe(Weather.code),
                sub: Tr.t("Feels like") + " " + Weather.feels + "°",
                run: null
            });
        for (const n of Toasts.history) {
            if (list.length >= 6)
                break;
            list.push({
                icon: "bell",
                title: n.title,
                sub: (n.app ? n.app + " · " : "") + Toasts.timeLabel(n),
                run: () => Ui.popup = "calendar"
            });
        }
        return list;
    }

    function launch(entry) {
        Ui.popup = "";
        entry.execute();
    }

    onShownChanged: {
        slide.stop();
        slide.to = shown ? 1 : 0;
        slide.duration = shown ? 300 : 170;
        slide.easing.bezierCurve = shown ? [0.1, 0.9, 0.2, 1, 1, 1] : [0.7, 0, 1, 0.5, 1, 1];
        slide.start();
    }

    NumberAnimation {
        id: slide

        target: root
        property: "t"
        easing.type: Easing.BezierSpline
    }

    width: 640
    height: 690
    y: baseY - height - 12 + (1 - t) * 70
    radius: 10
    visible: t > 0.001
    opacity: t
    clip: true
    color: Qt.alpha(Theme.glassBase, Math.max(0.86, Theme.glassOpacity))
    border.width: 1
    border.color: Qt.alpha(Theme.text, 0.12)

    MouseArea {
        anchors.fill: parent
    }

    // ------------------------------------------------ search
    Rectangle {
        id: search

        x: 32
        y: 28
        width: parent.width - 64
        height: 36
        radius: 18
        color: Qt.alpha(Theme.text, searchArea.containsMouse ? 0.1 : 0.06)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.1)

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 36
            height: 2
            radius: 1
            color: Theme.accent
            opacity: 0.8
        }
        Row {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 15
                color: Theme.muted
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("Search for apps, settings and files")
                size: 13
                color: Theme.muted
            }
        }
        MouseArea {
            id: searchArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            onClicked: Ui.popup = "menu"
        }
    }

    // A header with a small button on the right, as Windows 11 has over each part.
    component Header: Item {
        id: header

        property string title: ""
        property string action: ""
        signal clicked

        width: root.width - 100
        height: 30

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: header.title
            size: 14
            font.weight: Font.DemiBold
        }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: actionRow.implicitWidth + 18
            height: 26
            radius: 4
            color: Qt.alpha(Theme.text, actionArea.containsMouse ? 0.12 : 0.06)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.08)

            Row {
                id: actionRow

                anchors.centerIn: parent
                spacing: 6

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: header.action
                    size: 12
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "forward"
                    size: 11
                }
            }
            MouseArea {
                id: actionArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: header.clicked()
            }
        }
    }

    // ------------------------------------------------ pinned
    Header {
        x: 50
        y: 86
        title: Tr.t("Pinned")
        action: Tr.t("All apps")
        onClicked: Ui.popup = "menu"
    }
    Grid {
        id: pinnedGrid

        x: 34
        y: 124
        columns: 6

        Repeater {
            model: root.pinnedApps

            delegate: Rectangle {
                id: app

                required property var modelData
                required property int index

                width: (root.width - 68) / 6
                height: 84
                radius: 6
                color: Qt.alpha(Theme.text, appArea.containsMouse ? 0.08 : 0)
                // Rows come up one after another while the menu slides in.
                opacity: Math.max(0, Math.min(1, root.t * 2.2 - Math.floor(index / 6) * 0.25))
                transform: Translate {
                    y: (1 - Math.min(1, root.t * 1.6)) * (14 + Math.floor(app.index / 6) * 8)
                }

                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    implicitSize: 32
                    source: Quickshell.iconPath(app.modelData.icon, true)
                    scale: appArea.pressed ? 0.85 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 54
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    text: app.modelData.name
                    size: 11
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: appArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(app.modelData)
                }
            }
        }
    }

    // ------------------------------------------------ recommended
    Header {
        x: 50
        y: pinnedGrid.y + 3 * 84 + 16
        title: Tr.t("Recommended")
        action: Tr.t("More")
        onClicked: Ui.popup = "calendar"
    }
    Grid {
        x: 34
        y: pinnedGrid.y + 3 * 84 + 54
        columns: 2
        columnSpacing: 4
        rowSpacing: 2

        Repeater {
            model: root.recommended

            delegate: Rectangle {
                id: rec

                required property var modelData

                width: (root.width - 72) / 2
                height: 52
                radius: 6
                color: Qt.alpha(Theme.text, recArea.containsMouse ? 0.08 : 0)
                opacity: Math.max(0, Math.min(1, root.t * 2 - 0.6))

                Rectangle {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 6
                    color: Qt.alpha(Theme.accent, 0.2)

                    Icon {
                        anchors.centerIn: parent
                        name: rec.modelData.icon
                        size: 16
                        color: Theme.accent
                    }
                }
                Column {
                    x: 54
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 62

                    Label {
                        width: parent.width
                        text: rec.modelData.title
                        size: 12
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: rec.modelData.sub
                        size: 11
                        color: Theme.muted
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: recArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: rec.modelData.run ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (rec.modelData.run)
                            rec.modelData.run();
                    }
                }
            }
        }
    }
    Label {
        x: 50
        y: pinnedGrid.y + 3 * 84 + 70
        visible: root.recommended.length === 0
        text: Tr.t("New notifications and the song playing show here")
        size: 12
        color: Theme.muted
    }

    // ------------------------------------------------ footer: the user and power
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 64
        color: Qt.alpha(Theme.glassBase, 0.6)

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.text, 0.08)
        }
        Rectangle {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            width: userRow.implicitWidth + 20
            height: 42
            radius: 6
            color: Qt.alpha(Theme.text, userArea.containsMouse ? 0.08 : 0)

            Row {
                id: userRow

                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 16
                    color: Theme.accent

                    Label {
                        anchors.centerIn: parent
                        text: root.user.charAt(0).toUpperCase()
                        size: 14
                        font.weight: Font.DemiBold
                        color: Theme.accentText
                    }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.user
                    size: 13
                }
            }
            MouseArea {
                id: userArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Ui.popup = "";
                    Ui.settingsOpen = true;
                }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 6
            color: Qt.alpha(Theme.text, powerArea.containsMouse ? 0.1 : 0)

            Icon {
                anchors.centerIn: parent
                name: "power"
                size: 18
            }
            MouseArea {
                id: powerArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.popup = "power"
            }
        }
    }
}
