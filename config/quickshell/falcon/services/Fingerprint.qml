pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The fingerprint sensor through bin/falcon-fingerprint: what is enrolled, adding and removing
// fingers, and what is set up. The lock screens use fprintd as the user (no setup needed); the
// login screen and the password dialog need falcon-fingerd, installed once with sudo.
Singleton {
    id: root

    property bool known: false
    property string device: ""
    property var fingers: []
    property int stages: 0
    property var setup: ({})

    readonly property bool hasSensor: device !== ""
    readonly property bool hasPrints: fingers.length > 0
    readonly property bool lockOn: hasPrints && Settings.get("fingerprint.lock", true) === true
    readonly property bool polkitOn: hasPrints && setup.daemon === true && setup.polkit === true
        && Settings.get("fingerprint.polkit", true) === true
    readonly property bool needsSetup: hasSensor && setup.done !== true

    // Adding a finger: "" while idle.
    property string enrolling: ""
    property int enrollDone: 0
    property int enrollStages: 0
    property string enrollNote: ""
    property string enrollError: ""
    property string justAdded: ""
    property bool removing: false

    readonly property var allFingers: ["right-index-finger", "left-index-finger", "right-thumb", "left-thumb",
        "right-middle-finger", "left-middle-finger", "right-ring-finger", "left-ring-finger",
        "right-little-finger", "left-little-finger"]

    function nameOf(finger) {
        return ({
                "right-index-finger": Tr.t("Right index finger"),
                "left-index-finger": Tr.t("Left index finger"),
                "right-thumb": Tr.t("Right thumb"),
                "left-thumb": Tr.t("Left thumb"),
                "right-middle-finger": Tr.t("Right middle finger"),
                "left-middle-finger": Tr.t("Left middle finger"),
                "right-ring-finger": Tr.t("Right ring finger"),
                "left-ring-finger": Tr.t("Left ring finger"),
                "right-little-finger": Tr.t("Right little finger"),
                "left-little-finger": Tr.t("Left little finger")
            })[finger] || finger;
    }

    function noteOf(reason) {
        return ({
                "retry-scan": Tr.t("Not read, touch again"),
                "swipe-too-short": Tr.t("Too short, touch a little longer"),
                "finger-not-centered": Tr.t("Put the finger in the middle"),
                "remove-and-retry": Tr.t("Lift the finger and touch again"),
                "data-full": Tr.t("The sensor is full"),
                "duplicate": Tr.t("This finger is already added"),
                "denied": Tr.t("Not allowed: the password was not given"),
                "busy": Tr.t("The sensor is busy, try again"),
                "nodevice": Tr.t("No fingerprint sensor found"),
                "disconnected": Tr.t("The sensor was disconnected"),
                "failed": Tr.t("Could not add the finger"),
                "timeout": Tr.t("Took too long, try again")
            })[reason] || Tr.t("Could not add the finger");
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function enroll(finger) {
        if (enrolling !== "" || removing)
            return;
        enrolling = finger;
        enrollDone = 0;
        enrollStages = stages;
        enrollNote = "";
        enrollError = "";
        justAdded = "";
        enrollProc.command = [Ui.binDir + "falcon-fingerprint", "enroll", finger];
        enrollProc.running = true;
    }

    function cancelEnroll() {
        if (enrollProc.running)
            enrollProc.signal(15);
    }

    function remove(finger) {
        if (removing || enrolling !== "")
            return;
        removing = true;
        removeProc.command = [Ui.binDir + "falcon-fingerprint", "delete", finger];
        removeProc.running = true;
    }

    function runSetup() {
        Quickshell.execDetached(["kitty", "--title", "falcon fingerprint setup", "env", "PATH=" + Ui.binDir + ":" + Quickshell.env("PATH"), "sh", "-c", 'falcon-fingerprint setup; qs -c falcon ipc call desk fingerprintRefresh >/dev/null 2>&1; printf "\\n%s " "$(falcon-tr "Press Enter to close.")"; read _']);
    }

    Component.onCompleted: refresh()

    Process {
        id: statusProc

        command: [Ui.binDir + "falcon-fingerprint", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.device = s.device || "";
                    const before = root.fingers.length > 0;
                    root.fingers = s.fingers || [];
                    root.stages = s.stages || 0;
                    root.setup = s.setup || {};
                    const wasKnown = root.known;
                    root.known = true;
                    // hyprlock's finger lines are written by falcon-apply only while fingers exist.
                    if (wasKnown && before !== root.hasPrints)
                        Quickshell.execDetached([Ui.binDir + "falcon-apply"]);
                } catch (e) {}
            }
        }
    }

    Process {
        id: enrollProc

        stdout: SplitParser {
            onRead: line => {
                let e;
                try {
                    e = JSON.parse(line);
                } catch (err) {
                    return;
                }
                if (e.event === "start") {
                    root.enrollStages = e.stages || root.enrollStages;
                } else if (e.event === "stage") {
                    root.enrollDone = e.done;
                    root.enrollStages = e.stages || root.enrollStages;
                    root.enrollNote = "";
                } else if (e.event === "retry") {
                    root.enrollNote = root.noteOf(e.reason);
                } else if (e.event === "done") {
                    root.justAdded = root.enrolling;
                } else if (e.event === "error") {
                    root.enrollError = root.noteOf(e.reason);
                }
            }
        }
        onExited: {
            root.enrolling = "";
            root.refresh();
        }
    }

    Process {
        id: removeProc

        onExited: {
            root.removing = false;
            root.refresh();
        }
    }
}
