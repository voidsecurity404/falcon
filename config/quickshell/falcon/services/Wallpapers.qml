pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper lists and small pictures for the picker. Everything is kept ready in memory,
// so the picker shows its cards at once and only checks for changes in the background.
Singleton {
    id: root

    readonly property string stateDir: Ui.home + "/.local/state/falcon"
    readonly property string liveDir: Settings.wallpaperDir + "/Live"
    readonly property size thumbSize: Qt.size(530, 620)
    property var liveFiles: []
    property var imageFiles: []
    property var thumbs: ({})
    property string currentLive: ""
    property string currentImage: ""
    // The last live wallpaper chosen, so the live tab opens there while a picture is on.
    property string lastLive: ""
    // The picture on screen now (a live wallpaper's first frame) and whether a video plays over it.
    // falcon-wallpaper reports each change through `desk wallpaperShown`, as its transition starts.
    property string shownImage: ""
    property bool shownLive: false

    signal currentChanged

    function lines(text) {
        return text.trim().split("\n").filter(l => l.length > 0).sort();
    }

    function nameOf(path) {
        return path.split("/").pop();
    }

    // Before its small picture exists, a card shows the original or the first frame of the video.
    function thumbOf(path) {
        if (!path)
            return "";
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
        if (live) {
            Saved.set("lastLive", path);
            lastLive = path;
        } else {
            Saved.set("lastImage", path);
            currentImage = path;
        }
        currentChanged();
    }

    // The wallpaper on screen now cannot be deleted: hyprlock and the next login read it.
    function isOnScreen(path) {
        return path !== "" && (path === currentLive || (currentLive === "" && path === currentImage));
    }

    // Deletes a wallpaper from the disk for good, with its small picture and a live one's first
    // frame. Only files of the two lists are touched.
    function remove(path) {
        const live = liveFiles.indexOf(path) >= 0;
        if ((!live && imageFiles.indexOf(path) < 0) || isOnScreen(path))
            return false;
        const name = nameOf(path);
        const files = [path, stateDir + "/thumbs/" + name + ".jpg"];
        if (live)
            files.push(stateDir + "/live-posters/" + name.replace(/\.[^.]+$/, "") + ".jpg");
        if (live) {
            liveFiles = liveFiles.filter(f => f !== path);
            if (lastLive === path) {
                lastLive = "";
                Saved.set("lastLive", "");
            }
        } else {
            imageFiles = imageFiles.filter(f => f !== path);
            if (Saved.get("lastImage", "") === path)
                Saved.set("lastImage", "");
        }
        Quickshell.execDetached(["rm", "-f", "--"].concat(files));
        return true;
    }

    Component.onCompleted: {
        lastLive = Saved.get("lastLive", "");
        refresh();
    }

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
                const live = paths[1] || "";
                // With a live wallpaper the link holds its first frame, which is not in the plain
                // tab. That tab then opens on the last plain picture instead of the first one.
                const onScreen = paths[0] || "";
                let image = onScreen;
                if (live === "" && image !== "")
                    Saved.set("lastImage", image);
                else if (live !== "")
                    image = Saved.get("lastImage", image);
                if (live !== "" && live !== root.lastLive) {
                    Saved.set("lastLive", live);
                    root.lastLive = live;
                }
                if (root.shownImage === "") {
                    root.shownImage = onScreen;
                    root.shownLive = live !== "";
                }
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

        command: [Ui.binDir + "falcon-wallpaper", "--thumbs"]
        onRunningChanged: {
            if (running)
                tried = true;
        }
        onExited: readThumbs.running = true
    }

    // Holding the pictures here keeps them decoded, and the cards find them ready. Only those
    // around each tab's place are held, since every card of a large folder would take a lot of
    // memory: the current wallpaper's neighbors while the picker is closed, then the ones around
    // the selection as it moves, so the cards ahead are ready before they come into view.
    readonly property int preloadSpan: 8
    readonly property var preloaded: {
        const around = (list, at) => list.slice(Math.max(0, at - preloadSpan), Math.max(0, at) + preloadSpan + 1);
        const open = Ui.pickerAlive;
        const liveAt = open && Ui.pickerTab === 0 ? Ui.pickerSelected : liveFiles.indexOf(currentLive || lastLive);
        const imageAt = open && Ui.pickerTab === 1 ? Ui.pickerSelected : imageFiles.indexOf(currentImage);
        return around(liveFiles, liveAt).concat(around(imageFiles, imageAt));
    }

    Instantiator {
        model: ScriptModel {
            values: root.preloaded
        }

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
