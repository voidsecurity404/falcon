pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Widgets behind the subject: `wallpaper.depth` cuts the main thing of the picture out through
// bin/falcon-depth, and WidgetFace draws `subject` over the widgets in the same place as the
// wallpaper. Only for pictures, not live wallpapers. The first cut of a picture takes about 25 s
// in the background, later ones come from the cache. A new subject shows only after the
// wallpaper's own change has played, so it never stands over the old picture.
Singleton {
    id: root

    readonly property bool enabled: Settings.get("wallpaper.depth", false)
    readonly property string image: Wallpapers.shownLive ? "" : Wallpapers.shownImage
    property bool installed: false
    readonly property bool installing: installProc.running
    readonly property bool cutting: cutProc.running
    // The cut-out on screen, "" when none.
    property string subject: ""
    property string ready: ""
    property string readyFor: ""
    property string wanted: ""
    property bool told: false

    function refresh() {
        statusProc.running = true;
    }

    function update() {
        wanted = enabled && installed ? image : "";
        if (readyFor !== wanted) {
            subject = "";
            ready = "";
            readyFor = "";
        }
        if (wanted !== "" && readyFor !== wanted && !cutProc.running)
            cut(wanted);
    }

    function cut(path) {
        cutProc.forImage = path;
        cutProc.answered = false;
        cutProc.command = [Ui.binDir + "falcon-depth", "cut", path];
        cutProc.running = true;
    }

    function install() {
        if (installProc.running)
            return;
        installProc.running = true;
        Toasts.show(Tr.t("Getting ready for depth"), Tr.t("Downloads the model and its Python once, about 400 MB"), "wallpaper");
    }

    onEnabledChanged: {
        if (enabled && !installed)
            refresh();
        update();
    }
    onImageChanged: {
        subject = "";
        update();
    }
    onInstalledChanged: update()
    Component.onCompleted: refresh()

    Process {
        id: statusProc

        command: [Ui.binDir + "falcon-depth", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.installed = !!JSON.parse(text).installed;
                } catch (e) {}
                if (root.enabled && !root.installed)
                    root.install();
            }
        }
    }

    Process {
        id: installProc

        command: [Ui.binDir + "falcon-depth", "install"]
        onExited: code => {
            if (code === 0)
                Toasts.show(Tr.t("Depth is ready"), Tr.t("The first cut of each wallpaper takes about half a minute"), "wallpaper");
            else
                Toasts.show(Tr.t("Depth could not be set up"), Tr.t("Check the internet connection"), "wallpaper");
            root.refresh();
        }
    }

    Process {
        id: cutProc

        property string forImage: ""
        property bool answered: false

        stdout: SplitParser {
            onRead: line => {
                let answer = null;
                try {
                    answer = JSON.parse(line);
                } catch (e) {
                    return;
                }
                cutProc.answered = true;
                if (cutProc.forImage !== root.wanted)
                    return;
                root.readyFor = cutProc.forImage;
                root.ready = answer.path || "";
                show.restart();
            }
        }
        onExited: {
            // The wallpaper changed meanwhile: the newest one is cut next.
            if (root.wanted !== "" && root.readyFor !== root.wanted)
                Qt.callLater(root.update);
        }
    }

    // Waits for the wallpaper's own change to end.
    Timer {
        id: show

        interval: Math.max(200, Settings.get("wallpaper.duration", 1) * 1000) + 150
        onTriggered: {
            if (root.readyFor === root.wanted)
                root.subject = root.ready;
        }
    }
}
