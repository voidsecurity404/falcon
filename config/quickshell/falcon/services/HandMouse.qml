pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hand control: bin/falcon-handmouse watches one hand through the webcam and drives a virtual mouse.
// It runs only while switched on, which is a quick toggle kept by Saved, so the camera is off otherwise.
// Settings go to it as JSON lines on stdin, and it ends when the shell closes that pipe.
Singleton {
    id: root

    property bool enabled: false
    property bool loaded: false

    // From `falcon-handmouse status`.
    property bool ready: false
    property bool checked: false
    property var cameras: []
    property bool uinput: true
    property string calibratedAt: ""

    // From the running engine.
    property bool started: false
    property bool active: true
    property bool hand: false
    property string gesture: ""
    property bool cameraOk: true
    property real fps: 0
    property int cpu: 0
    property real latency: 0
    property string problem: ""

    // Setup
    property bool installing: false
    property string installStep: ""
    property string installError: ""

    // The camera view on the settings page, asked for only while that page is on screen.
    property bool previewWanted: false
    property string previewImage: ""
    property var previewPoints: null

    // Calibration: step 0 to 3 while it runs, -1 otherwise.
    property int calStep: -1
    property real calHold: 0
    property bool calHand: false
    readonly property var targets: [[0.1, 0.1], [0.9, 0.1], [0.9, 0.9], [0.1, 0.9]]

    readonly property var config: Settings.get("handmouse", ({}))
    readonly property string configText: JSON.stringify(config)
    // These are read only when the engine starts.
    readonly property string startKey: [config.camera, config.mode, config.steadyFps].join("|")
    readonly property bool notify: config.notify !== false
    readonly property bool running: engine.running

    readonly property string stateText: {
        if (installing)
            return Tr.t("Installing…");
        if (!checked)
            return "";
        if (!ready)
            return Tr.t("Needs a one time download");
        if (!enabled)
            return Tr.t("Off");
        if (problem === "camera" || problem === "cameraLost")
            return Tr.t("Camera not available");
        if (problem === "uinput")
            return Tr.t("No access to /dev/uinput");
        if (!started)
            return Tr.t("Starting…");
        if (calStep >= 0)
            return Tr.t("Calibrating");
        if (!active)
            return Tr.t("Paused. Hold an open palm to resume");
        if (!hand)
            return Tr.t("No hand in view");
        switch (gesture) {
        case "pinch":
        case "rightWait":
            return Tr.t("Pinch");
        case "drag":
            return Tr.t("Dragging");
        case "scroll":
            return Tr.t("Scrolling");
        case "pause":
            return Tr.t("Holding the pointer");
        }
        return Tr.t("Following your hand");
    }

    onEnabledChanged: {
        if (loaded)
            Saved.set("handmouse", enabled);
        if (!enabled) {
            started = false;
            problem = "";
            calStep = -1;
        }
    }
    Component.onCompleted: {
        enabled = Saved.get("handmouse", false);
        loaded = true;
        status.running = true;
    }

    function send(message) {
        if (engine.running)
            engine.write(JSON.stringify(message) + "\n");
    }

    function toggle() {
        if (!ready) {
            openPage();
            if (!installing)
                Toasts.show(Tr.t("Hand control"), Tr.t("It needs a one time download first"), "hand");
            return;
        }
        enabled = !enabled;
        if (notify || !enabled)
            Toasts.show(enabled ? Tr.t("Hand control on") : Tr.t("Hand control off"), enabled ? Tr.t("Pinch to click, hold an open palm to pause") : "", "hand");
    }

    function openPage() {
        Ui.settingsPage = Ui.pageHand;
        Ui.settingsOpen = true;
    }

    function install() {
        if (installing)
            return;
        installError = "";
        installStep = "";
        installer.running = true;
    }

    function calibrate() {
        if (!ready)
            return;
        if (!enabled)
            enabled = true;
        Ui.settingsOpen = false;
        calStep = 0;
        calHold = 0;
        calHand = false;
        if (started)
            send({ cmd: "calibrate" });
    }

    function cancelCalibration() {
        if (calStep < 0)
            return;
        calStep = -1;
        send({ cmd: "cancelCalibration" });
    }

    function forgetCalibration() {
        forget.running = true;
    }

    onConfigTextChanged: send({ config: config })
    onPreviewWantedChanged: send({ cmd: "preview", on: previewWanted })
    onStartKeyChanged: {
        if (engine.running)
            restart.restart();
    }

    Process {
        id: status

        command: ["falcon-handmouse", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.ready = !!s.ready;
                    root.cameras = s.cameras || [];
                    root.uinput = !!s.uinput;
                    root.calibratedAt = s.calibrated || "";
                } catch (e) {
                    root.ready = false;
                }
                root.checked = true;
            }
        }
    }

    Process {
        id: installer

        command: ["falcon-handmouse", "setup"]
        onRunningChanged: {
            root.installing = running;
            if (!running)
                status.running = true;
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const m = JSON.parse(line);
                    if (m.step)
                        root.installStep = m.step;
                    if (m.error)
                        root.installError = m.error;
                    if (m.done)
                        Toasts.show(Tr.t("Hand control is ready"), Tr.t("Turn it on with {key}").replace("{key}", Settings.get("binds.handmouse", "")), "hand");
                } catch (e) {}
            }
        }
    }

    Process {
        id: engine

        command: ["falcon-handmouse", "run"]
        running: root.enabled && root.ready && !restart.running
        stdinEnabled: true
        onStarted: {
            root.started = false;
            root.problem = "";
            root.send({ config: root.config });
            if (root.previewWanted)
                root.send({ cmd: "preview", on: true });
        }
        onExited: (code, exitStatus) => {
            root.started = false;
            root.previewImage = "";
            root.previewPoints = null;
            if (root.calStep >= 0)
                root.calStep = -1;
            // An engine that could not start says why on its last line. It is not started again
            // until switched on again, so a missing camera does not loop.
            if (root.enabled && !restart.running && code !== 0) {
                root.enabled = false;
                Toasts.show(Tr.t("Hand control stopped"), root.problemText(root.problem), "hand");
            }
        }
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
    }

    // A camera or pointer mode change needs a new engine.
    Timer {
        id: restart

        interval: 400
    }

    Process {
        id: forget

        command: ["rm", "-f", Quickshell.env("HOME") + "/.local/state/falcon/handmouse-calibration.json"]
        onExited: {
            root.calibratedAt = "";
            root.send({ cmd: "reloadCalibration" });
        }
    }

    function problemText(name) {
        switch (name) {
        case "camera":
        case "cameraLost":
            return Tr.t("The camera could not be opened");
        case "uinput":
            return Tr.t("No access to /dev/uinput");
        case "setup":
            return Tr.t("It needs a one time download first");
        }
        return Tr.t("Something went wrong");
    }

    function handle(line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (m.started) {
            started = true;
            if (calStep >= 0)
                send({ cmd: "calibrate" });
        } else if (m.state) {
            active = m.state.active;
            hand = m.state.hand;
            gesture = m.state.gesture;
            cameraOk = m.state.camera;
            fps = m.state.fps;
            cpu = m.state.cpu;
            latency = m.state.latency;
        } else if (m.preview) {
            if (previewWanted) {
                previewImage = m.preview.image;
                previewPoints = m.preview.points;
            }
        } else if (m.calibrate) {
            const c = m.calibrate;
            if (c.done) {
                calStep = -1;
                calibratedAt = c.date;
                Toasts.show(Tr.t("Hand control calibrated"), Tr.t("The corners of the screen are easier to reach now"), "check");
            } else if (c.failed) {
                calStep = -1;
                Toasts.show(Tr.t("Calibration failed"), Tr.t("Point at each circle from a different place"), "hand");
            } else if (c.cancelled) {
                calStep = -1;
            } else if (calStep >= 0) {
                calStep = c.step;
                calHold = c.hold;
                calHand = c.hand;
            }
        } else if (m.event) {
            if (m.event === "on" || m.event === "off") {
                active = m.event === "on";
                if (notify)
                    Toasts.show(active ? Tr.t("Hand control resumed") : Tr.t("Hand control paused"), active ? "" : Tr.t("Hold an open palm to resume"), "hand");
            } else if (m.event === "cameraBack") {
                problem = "";
            }
        } else if (m.error) {
            problem = m.error;
            if (m.error === "cameraLost")
                Toasts.show(Tr.t("Hand control"), Tr.t("The camera was lost, trying again"), "camera");
        }
    }
}
