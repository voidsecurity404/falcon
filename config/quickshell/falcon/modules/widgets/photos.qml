import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.services

// A photo frame: pictures from a folder (widgets.photos.folder, ~/Pictures by default, two levels
// deep, wallpapers left out) one after another with a slow drift and a crossfade. A press opens
// the picture shown. Forms: square, wide, tall.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "square"
    // Empty means the pictures folder of xdg-user-dirs (~/Изображения on a Russian system).
    readonly property string folder: String(Settings.get("widgets.photos.folder", "") || "").trim().replace(/^~/, Quickshell.env("HOME"))
    readonly property int seconds: Math.max(10, Number(Settings.get("widgets.photos.seconds", 60)) || 60)
    property var files: []
    // Both copies show the same picture: the index is shared, counted by the face's timer.
    readonly property int at: Widgets.sharedValue(widgetId, "photo", 0)
    readonly property string current: files.length ? files[at % files.length] : ""
    property bool flip: false
    // The slide in front; the other loads the next picture and takes over once it is ready.
    property Item front: null

    function step(n) {
        if (files.length > 0)
            Widgets.share(widgetId, "photo", (at + n + files.length) % files.length);
    }

    Process {
        id: lister

        running: true
        // Wallpapers and screenshots in the folder are left out.
        command: ["sh", "-c", 'd="${1:-$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")}"; find "$d" -maxdepth 2 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) -not -path "$d/Wallpapers/*" -not -ipath "*/screenshots/*" -not -path "*/Скриншоты/*" -not -path "*/.*" -size +20k 2>/dev/null | shuf -n 400', "sh", root.folder]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(f => f !== "")
        }
    }
    onFolderChanged: lister.running = true
    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: lister.running = true
    }
    // Only the clickable copy moves on, so the two never step twice; the face follows the share.
    Timer {
        interval: root.seconds * 1000
        running: root.enabled && root.files.length > 1
        repeat: true
        onTriggered: root.step(1)
    }

    onCurrentChanged: {
        if (current === "")
            return;
        if (flip)
            a.source = "file://" + current;
        else
            b.source = "file://" + current;
        flip = !flip;
    }

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: 8
        radius: 16
        color: Qt.alpha(Theme.text, 0.05)

        component Slide: Image {
            id: slide

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 900
            asynchronous: true
            cache: false
            scale: 1.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 900
                    easing.type: Easing.InOutQuad
                }
            }
            // A slow drift, Ken Burns like, restarted with each picture.
            NumberAnimation on scale {
                id: drift
                from: 1.0
                to: 1.08
                duration: root.seconds * 1000 + 1000
                running: false
            }
            onStatusChanged: {
                if (status === Image.Ready && source !== "") {
                    drift.restart();
                    root.front = slide;
                }
            }
            opacity: root.front === slide ? 1 : 0
        }
        Slide {
            id: a
        }
        Slide {
            id: b
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 54
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha("#000000", 0.5)
                }
            }
        }
        Label {
            x: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: parent.width - 100
            elide: Text.ElideMiddle
            text: root.current.split("/").pop().replace(/\.[^.]+$/, "")
            size: 11
            color: "white"
            opacity: 0.85
        }
        Column {
            anchors.centerIn: parent
            visible: root.files.length === 0
            spacing: 8

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "image"
                size: 34
                color: Qt.alpha(Theme.accent, 0.7)
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Tr.t("No pictures in the folder")
                size: 12
                color: Theme.muted
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Tr.t("Choose one in Settings, Widgets")
                size: 11
                color: Theme.muted
            }
        }
    }
    WidgetHot {
        anchors.fill: parent
        onClicked: if (root.current !== "") Quickshell.execDetached(["xdg-open", root.current])
    }
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        spacing: 6
        visible: root.files.length > 1

        WidgetButton {
            height: 28
            icon: "back"
            onClicked: root.step(-1)
        }
        WidgetButton {
            height: 28
            icon: "forward"
            onClicked: root.step(1)
        }
    }
}
