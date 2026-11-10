import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Downloads wallpapers: pictures from Wallhaven, live wallpapers from MotionBGs (services/WallGet).
// Opened by the download button and Ctrl+D in the wallpaper picker, `>download` in the app menu,
// or `desk wallget`. A card's Set button downloads and applies, Save only downloads; the files go
// to the wallpaper folder and its Live folder.
LazyLoader {
    active: Ui.popup === "wallget"

    PanelWindow {
        id: root

        readonly property var sources: [
            { id: "wallhaven", label: Tr.t("Pictures"), site: "Wallhaven", icon: "wallpaper" },
            { id: "motionbgs", label: Tr.t("Live wallpapers"), site: "MotionBGs", icon: "play" }
        ]
        readonly property int columns: card.width > 1000 ? 4 : 3

        function search() {
            WallGet.search(WallGet.source, input.text.trim());
            grid.positionViewAtBeginning();
        }

        function setSource(id) {
            if (id === WallGet.source)
                return;
            WallGet.search(id, input.text.trim());
            grid.positionViewAtBeginning();
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
        WlrLayershell.namespace: "falcon-wallget"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Component.onCompleted: {
            WallGet.screenSize = Math.round(screen.width * screen.devicePixelRatio) + "x" + Math.round(screen.height * screen.devicePixelRatio);
            input.text = WallGet.query;
            if (WallGet.results.length === 0 && !WallGet.searching)
                WallGet.search(WallGet.source, WallGet.query);
            input.forceActiveFocus();
        }

        // A dim veil; a click on it closes.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: card.opacity

            MouseArea {
                anchors.fill: parent
                onClicked: Ui.popup = ""
            }
        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(1180, parent.width - 80)
            height: Math.min(760, parent.height - 100)
            radius: 22
            color: Theme.pill
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.08)
            clip: true
            opacity: 0
            scale: 0.97
            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
            }

            // Header: the source, the search field, close.
            Item {
                id: header

                x: 20
                y: 18
                width: parent.width - 40
                height: 48

                Rectangle {
                    id: sourceSwitch

                    width: sourceRow.implicitWidth + 8
                    height: 44
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 22
                    color: Qt.alpha(Theme.text, 0.06)

                    Rectangle {
                        readonly property Item target: sourceRow.children[Math.max(0, root.sources.findIndex(s => s.id === WallGet.source))] || null

                        x: target ? target.x + 4 : 4
                        y: 4
                        width: target ? target.width : 0
                        height: 36
                        radius: 18
                        color: Theme.accent

                        Behavior on x {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Row {
                        id: sourceRow

                        x: 4
                        y: 4

                        Repeater {
                            model: root.sources

                            delegate: Item {
                                id: sourceItem

                                required property var modelData
                                readonly property bool chosen: WallGet.source === modelData.id

                                width: sourceLabel.implicitWidth + 50
                                height: 36

                                Icon {
                                    x: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: sourceItem.modelData.icon
                                    size: 15
                                    color: sourceItem.chosen ? Theme.accentText : Theme.text
                                }
                                Label {
                                    id: sourceLabel

                                    x: 38
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: sourceItem.modelData.label
                                    size: 13
                                    font.weight: Font.Medium
                                    color: sourceItem.chosen ? Theme.accentText : Theme.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setSource(sourceItem.modelData.id)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: sourceSwitch.right
                    anchors.leftMargin: 12
                    anchors.right: closeButton.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 44
                    radius: 22
                    color: Qt.alpha(Theme.text, input.activeFocus ? 0.09 : 0.06)

                    Icon {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: 16
                        color: Theme.muted
                    }
                    TextInput {
                        id: input

                        anchors.left: parent.left
                        anchors.leftMargin: 44
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.family: Theme.sans
                        font.pixelSize: Math.round(15 * Theme.fontScale)
                        Keys.onEscapePressed: Ui.popup = ""
                        Keys.onReturnPressed: root.search()
                        Keys.onEnterPressed: root.search()
                        Keys.onTabPressed: root.setSource(WallGet.source === "wallhaven" ? "motionbgs" : "wallhaven")

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: Tr.t("Search {site}, Enter to find. Empty shows the popular ones").replace("{site}", root.sources.find(s => s.id === WallGet.source).site)
                            color: Qt.alpha(Theme.text, 0.38)
                            size: 14
                        }
                    }
                }

                Rectangle {
                    id: closeButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: Qt.alpha(Theme.text, closeArea.containsMouse ? 0.14 : 0.06)

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 16
                    }
                    MouseArea {
                        id: closeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.popup = ""
                    }
                }
            }

            Label {
                anchors.centerIn: grid
                visible: WallGet.results.length === 0
                text: WallGet.searching ? Tr.t("Looking…") : WallGet.error === "offline" ? Tr.t("No answer from the site. Check the internet connection") : Tr.t("Nothing found")
                color: Theme.muted
                size: 15
            }

            GridView {
                id: grid

                x: 14
                y: header.y + header.height + 14
                width: parent.width - 28
                height: parent.height - y - 30
                clip: true
                cellWidth: width / root.columns
                cellHeight: Math.round(cellWidth * 9 / 16) + 44
                model: WallGet.results
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 600
                onAtYEndChanged: {
                    if (atYEnd)
                        WallGet.loadMore();
                }

                delegate: Item {
                    id: tile

                    required property var modelData
                    readonly property var job: WallGet.jobs[WallGet.keyOf(modelData)] || null
                    readonly property bool busy: !!job && (job.state === "loading" || job.state === "waiting")
                    readonly property bool done: !!job && job.state === "done"

                    width: grid.cellWidth
                    height: grid.cellHeight

                    HoverHandler {
                        id: hover
                    }

                    ClippingRectangle {
                        id: shot

                        x: 6
                        y: 6
                        width: parent.width - 12
                        height: Math.round(width * 9 / 16)
                        radius: 14
                        color: Qt.alpha(Theme.text, 0.06)
                        scale: hover.hovered ? 1.02 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        Image {
                            id: picture

                            anchors.fill: parent
                            source: "file://" + tile.modelData.thumb
                            sourceSize: Qt.size(Math.round(shot.width * 1.5), Math.round(shot.height * 1.5))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 220
                                }
                            }
                        }
                        // Darkens under the buttons.
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.38)
                            opacity: hover.hovered || tile.busy ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }
                        }
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            opacity: hover.hovered && !tile.busy ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            Repeater {
                                model: [
                                    { text: Tr.t("Set"), main: true, apply: true },
                                    { text: tile.done ? Tr.t("Saved") : Tr.t("Save"), main: false, apply: false }
                                ]

                                delegate: Rectangle {
                                    id: action

                                    required property var modelData

                                    width: actionLabel.implicitWidth + 28
                                    height: 34
                                    radius: 17
                                    color: modelData.main ? (actionArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : Qt.rgba(1, 1, 1, actionArea.containsMouse ? 0.3 : 0.18)

                                    Label {
                                        id: actionLabel

                                        anchors.centerIn: parent
                                        text: action.modelData.text
                                        size: 13
                                        font.weight: Font.Medium
                                        color: action.modelData.main ? Theme.accentText : "white"
                                    }
                                    MouseArea {
                                        id: actionArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            WallGet.get(tile.modelData, action.modelData.apply);
                                            if (action.modelData.apply && tile.done)
                                                Ui.popup = "";
                                        }
                                    }
                                }
                            }
                        }
                        // Progress of the download along the bottom.
                        Rectangle {
                            anchors.bottom: parent.bottom
                            height: 4
                            width: parent.width * (tile.job ? tile.job.progress || 0 : 0)
                            visible: tile.busy
                            color: Theme.accent

                            Behavior on width {
                                NumberAnimation {
                                    duration: 150
                                }
                            }
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: tile.busy
                            text: tile.job && tile.job.state === "waiting" ? Tr.t("Waiting…") : Math.round((tile.job ? tile.job.progress || 0 : 0) * 100) + "%"
                            color: "white"
                            size: 15
                            font.weight: Font.Medium
                        }
                        // Downloaded already.
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 26
                            height: 26
                            radius: 13
                            visible: tile.done
                            color: Theme.accent

                            Icon {
                                anchors.centerIn: parent
                                name: "check"
                                size: 13
                                color: Theme.accentText
                            }
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 8
                            visible: tile.modelData.size !== ""
                            width: sizeLabel.implicitWidth + 14
                            height: 22
                            radius: 11
                            color: Qt.rgba(0, 0, 0, 0.5)

                            Label {
                                id: sizeLabel

                                anchors.centerIn: parent
                                text: tile.modelData.size
                                size: 11
                                color: "white"
                            }
                        }
                    }
                    Label {
                        x: 12
                        y: shot.y + shot.height + 8
                        width: parent.width - 24
                        text: tile.modelData.title
                        size: 13
                        elide: Text.ElideRight
                        color: Theme.text
                    }
                }

                footer: Item {
                    width: grid.width
                    height: WallGet.more || (WallGet.searching && WallGet.results.length > 0) ? 50 : 10

                    Label {
                        anchors.centerIn: parent
                        visible: parent.height > 10
                        text: Tr.t("Loading more…")
                        color: Theme.muted
                        size: 13
                    }
                }
            }

            Label {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                text: Tr.t("Set downloads and applies, Save only downloads · Tab: pictures or live · Esc: close")
                color: Theme.muted
                size: 11
            }
        }
    }
}
