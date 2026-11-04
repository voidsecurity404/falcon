pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper lists and small pictures for the picker. Everything is kept ready in memory,
// so the picker shows its cards at once and only checks for changes in the background.
Singleton {
    id: root

    readonly property string stateDir: Ui.home + "/.local/state/niri-desk"
    readonly property string liveDir: Settings.wallpaperDir + "/Live"
    readonly property size thumbSize: Qt.size(530, 620)
    property var liveFiles: []
    property var imageFiles: []
    property var thumbs: ({})
    property string currentLive: ""
    property string currentImage: ""

    signal currentChanged

    function lines(text) {
        return text.trim().split("\n").filter(l => l.length > 0).sort();
    }

    function nameOf(path) {
        return path.split("/").pop();
    }

    // Before its small picture exists, a card shows the original or the first frame of the video.
    function thumbOf(path) {
        const name = nameOf(path);
        if (thumbs[name])
            return "file://" + stateDir + "/thumbs/" + name + ".jpg";
        if (liveFiles.indexOf(path) >= 0)
            return "file://" + stateDir + "/live-posters/" + name.replace(/\.[^.]+$/, "") + ".jpg";
        return "file://" + path;
    }

    function refresh() {
        makeThumbs.tried = false;
        findLive.running = true;
    }

    function chosen(path, live) {
        currentLive = live ? path : "";
        if (!live)
            currentImage = path;
        currentChanged();
    }

    Component.onCompleted: refresh()

    Process {
        id: findLive

        command: ["find", root.liveDir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.mp4", "-o", "-iname", "*.webm", "-o", "-iname", "*.mkv", "-o", "-iname", "*.mov", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.lines(text);
                if (JSON.stringify(list) !== JSON.stringify(root.liveFiles))
                    root.liveFiles = list;
                findImages.running = true;
            }
        }
    }

    Process {
        id: findImages

        command: ["find", Settings.wallpaperDir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.lines(text);
                if (JSON.stringify(list) !== JSON.stringify(root.imageFiles))
                    root.imageFiles = list;
                current.running = true;
            }
        }
    }

    Process {
        id: current

        command: ["sh", "-c", 'readlink -f "$1/wallpaper"; [ -e "$1/wallpaper-live" ] && readlink -f "$1/wallpaper-live"; true', "sh", root.stateDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const paths = text.trim().split("\n");
                const image = paths[0] || "";
                const live = paths[1] || "";
                if (image !== root.currentImage || live !== root.currentLive) {
                    root.currentImage = image;
                    root.currentLive = live;
                    root.currentChanged();
                }
                readThumbs.running = true;
            }
        }
    }

    // Reads what exists, makes what is missing, and reads again only if something was made.
    Process {
        id: readThumbs

        command: ["find", root.stateDir + "/thumbs", "-maxdepth", "1", "-type", "f", "-name", "*.jpg", "-printf", "%f\\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of root.lines(text))
                    found[line.replace(/\.jpg$/, "")] = true;
                root.thumbs = found;
                const missing = root.liveFiles.concat(root.imageFiles).some(path => !found[root.nameOf(path)]);
                if (missing && !makeThumbs.tried)
                    makeThumbs.running = true;
            }
        }
    }

    Process {
        id: makeThumbs

        // A file that cannot be converted stays missing: one attempt per check is enough.
        property bool tried: false

        command: [Ui.binDir + "niri-desk-wallpaper", "--thumbs"]
        onRunningChanged: {
            if (running)
                tried = true;
        }
        onExited: readThumbs.running = true
    }

    // Holding the pictures here keeps them decoded, and the cards find them ready.
    Instantiator {
        model: root.liveFiles.concat(root.imageFiles)

        delegate: Image {
            required property string modelData

            source: root.thumbOf(modelData)
            sourceSize: root.thumbSize
            // Must match the cards: the fill mode is part of what identifies a picture in memory.
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
    }
}
