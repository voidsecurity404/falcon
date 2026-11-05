import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// Quick Look: a file in a glass card over a dim screen. Esc or Space closes, the arrows go
// through several files, Enter opens the file in its own app.
PanelWindow {
    id: root

    readonly property bool closing: Ui.popup !== "quicklook"
    readonly property string path: Ui.quickFiles[Ui.quickIndex] || ""
    readonly property int maxWidth: Math.round(width * 0.82)
    readonly property int maxHeight: Math.round(height * 0.84)
    readonly property int headHeight: 62
    property var info: ({})
    property bool loading: false
    property real reveal: 0
    // Size of the picture on screen, once its real size is known.
    readonly property string kind: info.kind || ""
    readonly property string pictureSource: {
        const file = kind === "image" ? path : (info.picture || "");
        return file === "" ? "" : fileUrl(file);
    }
    readonly property bool hasPicture: pictureSource !== "" && !(picture.status === Image.Error && !info.animated)
    readonly property real naturalWidth: info.animated && animated.status === AnimatedImage.Ready ? animated.sourceSize.width : picture.sourceSize.width
    readonly property real naturalHeight: info.animated && animated.status === AnimatedImage.Ready ? animated.sourceSize.height : picture.sourceSize.height
    readonly property real fit: naturalWidth > 0 && naturalHeight > 0 ? Math.min((maxWidth - 16) / naturalWidth, (maxHeight - headHeight - 16) / naturalHeight, kind === "image" ? 2 : 1) : 1
    readonly property int wantedWidth: {
        if (hasPicture && naturalWidth > 0)
            return Math.max(520, Math.round(naturalWidth * fit) + 16);
        if (kind === "text" || kind === "folder" || kind === "archive")
            return Math.min(maxWidth, 860);
        return 520;
    }
    readonly property int wantedHeight: {
        if (hasPicture && naturalHeight > 0)
            return Math.round(naturalHeight * fit) + headHeight + 16;
        if (kind === "text" || kind === "folder" || kind === "archive")
            return Math.min(maxHeight, 660);
        return 300;
    }

    function fileUrl(file) {
        return "file://" + encodeURI(file).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function load() {
        info = {};
        if (path === "")
            return;
        loading = true;
        reader.running = false;
        reader.exec([Ui.binDir + "niri-desk-preview", path]);
    }

    function step(by) {
        const count = Ui.quickFiles.length;
        if (count > 1)
            Ui.quickIndex = (Ui.quickIndex + by + count) % count;
    }

    function openFile() {
        Ui.popup = "";
        Quickshell.execDetached(["xdg-open", path]);
    }

    onPathChanged: {
        if (!closing)
            load();
    }
    onClosingChanged: {
        if (closing) {
            openAnim.stop();
            closeAnim.start();
        } else {
            closeAnim.stop();
            load();
            keys.forceActiveFocus();
            openAnim.start();
        }
    }

    visible: Ui.quickAlive
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
    WlrLayershell.namespace: "niri-desk-quicklook"
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    mask: Region {
        item: catcher
    }
    BackgroundEffect.blurRegion: Region {
        item: card
        radius: card.radius
    }

    Process {
        id: reader

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    root.info = JSON.parse(text);
                } catch (e) {
                    root.info = { kind: "other", name: root.path };
                }
            }
        }
    }

    NumberAnimation {
        id: openAnim

        target: root
        property: "reveal"
        to: 1
        duration: 300
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
    }
    SequentialAnimation {
        id: closeAnim

        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: 170
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root.info = {};
                Ui.quickAlive = false;
                Quickshell.execDetached(["rm", "-rf", Quickshell.env("XDG_RUNTIME_DIR") + "/niri-desk-preview"]);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("black", 0.34 * root.reveal)
    }
    MouseArea {
        id: catcher

        width: root.closing ? 0 : parent.width
        height: root.closing ? 0 : parent.height
        onClicked: Ui.popup = ""
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space)
                Ui.popup = "";
            else if (event.key === Qt.Key_Left)
                root.step(-1);
            else if (event.key === Qt.Key_Right)
                root.step(1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.openFile();
            else if (event.key === Qt.Key_Down)
                textView.contentY = Math.min(Math.max(0, textView.contentHeight - textView.height), textView.contentY + 60);
            else if (event.key === Qt.Key_Up)
                textView.contentY = Math.max(0, textView.contentY - 60);
            else
                return;
            event.accepted = true;
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: root.wantedWidth * (0.9 + 0.1 * root.reveal)
        height: root.wantedHeight * (0.9 + 0.1 * root.reveal)
        radius: 24
        opacity: Math.min(1, root.reveal * 1.6)
        border.width: 1
        border.color: Theme.panelEdge
        // A file can be anything, so the card keeps its own floor under the text.
        color: Qt.alpha(Theme.surface, Math.max(0.72, Theme.panel.a))
        clip: true

        Behavior on width {
            enabled: root.reveal > 0.9

            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            enabled: root.reveal > 0.9

            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: head

            width: parent.width
            height: root.headHeight

            Column {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40 - buttons.width

                Label {
                    width: parent.width
                    text: root.info.name || root.path.slice(root.path.lastIndexOf("/") + 1)
                    size: 14
                    font.weight: Font.Medium
                    elide: Text.ElideMiddle
                }
                Label {
                    width: parent.width
                    size: 12
                    color: Theme.muted
                    elide: Text.ElideRight
                    text: {
                        const i = root.info;
                        const parts = [];
                        if (Ui.quickFiles.length > 1)
                            parts.push((Ui.quickIndex + 1) + " / " + Ui.quickFiles.length);
                        for (const value of [i.dimensions, i.duration, i.pages ? Tr.t("{n} pages").replace("{n}", i.pages) : "", i.count !== undefined ? Tr.t("{n} items").replace("{n}", i.count) : "", i.size, i.modified])
                            if (value)
                                parts.push(value);
                        return parts.join("  ·  ");
                    }
                }
            }
            Row {
                id: buttons

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                PillButton {
                    icon: "share"
                    implicitWidth: 38
                    visible: root.kind !== "folder" && root.kind !== "missing"
                    onClicked: {
                        Ui.popup = "";
                        Devices.share(root.path);
                    }
                }
                PillButton {
                    text: Tr.t("Open")
                    accent: true
                    visible: root.kind !== "missing"
                    onClicked: root.openFile()
                }
            }
        }

        Item {
            id: body

            x: 8
            y: root.headHeight
            width: parent.width - 16
            height: parent.height - root.headHeight - 8
            clip: true

            Image {
                id: picture

                anchors.fill: parent
                visible: !root.info.animated
                source: root.info.animated ? "" : root.pictureSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                mipmap: true
                smooth: true
            }
            AnimatedImage {
                id: animated

                anchors.fill: parent
                visible: !!root.info.animated
                source: root.info.animated ? root.pictureSource : ""
                fillMode: Image.PreserveAspectFit
                cache: false
                playing: visible && !root.closing
            }

            Loader {
                anchors.fill: parent
                active: !root.closing && (root.kind === "video" || root.kind === "audio")
                source: Qt.resolvedUrl("../components/QuickLookVideo.qml")
                onLoaded: {
                    item.path = Qt.binding(() => root.path);
                    item.showVideo = Qt.binding(() => root.kind === "video");
                    item.active = true;
                }
            }

            // Text, with the same keys and selection as anywhere.
            Flickable {
                id: textView

                anchors.fill: parent
                anchors.margins: 8
                visible: root.kind === "text"
                contentHeight: textBody.implicitHeight + (cutNote.visible ? cutNote.height + 10 : 0)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: textBody

                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.WrapAnywhere
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.family: Theme.mono
                    font.pixelSize: 13
                    text: root.kind === "text" ? (root.info.text || "") : ""
                }
                Label {
                    id: cutNote

                    y: textBody.implicitHeight + 10
                    visible: !!root.info.truncated
                    text: Tr.t("Only the start of the file is shown")
                    color: Theme.muted
                    size: 12
                }
            }

            // Folders and archives
            ListView {
                anchors.fill: parent
                anchors.margins: 4
                visible: root.kind === "folder" || root.kind === "archive"
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: visible ? (root.info.entries || []) : []
                delegate: Item {
                    required property var modelData

                    width: ListView.view.width
                    height: 30

                    Icon {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: parent.modelData.dir ? "folder" : "note"
                        size: 15
                        color: parent.modelData.dir ? Theme.accent : Theme.muted
                    }
                    Label {
                        x: 34
                        width: parent.width - 44
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.name
                        size: 13
                        elide: Text.ElideMiddle
                    }
                }
            }

            // Anything else, and a sound without a picture
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.kind === "audio" ? -24 : 0
                spacing: 12
                visible: !root.loading && (root.kind === "other" || root.kind === "missing" || root.kind === "audio" || (root.kind === "pdf" && !root.hasPicture))

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.kind === "audio" ? "music" : root.kind === "missing" ? "alert" : "note"
                    size: 54
                    color: Theme.muted
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.info.error ? root.info.error : root.info.mime || ""
                    color: Theme.muted
                    size: 13
                }
            }

            Label {
                anchors.centerIn: parent
                visible: root.loading
                text: Tr.t("Loading…")
                color: Theme.muted
            }
        }
    }
}
