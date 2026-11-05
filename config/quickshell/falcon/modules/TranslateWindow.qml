import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Shows a selected area with its text translated on the picture itself. While the work goes on, a
// scanner's light passes over the original, and its last pass lays the translation down behind it.
// Reading and drawing are done by falcon-image-translate.
LazyLoader {
    active: Ui.translateSource !== ""

    FloatingWindow {
        id: win

        readonly property string source: Ui.translateSource
        readonly property string result: source + ".translated.png"
        readonly property var output: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
        readonly property int barHeight: 62
        readonly property int margin: 14
        // Decided once from the picture's size, then the picture follows the window when it is resized.
        readonly property real startScale: Math.min(1, (output.width * 0.85 - margin * 2) / Ui.translateWidth, (output.height * 0.82 - barHeight - margin) / Ui.translateHeight)
        readonly property real pictureScale: Math.min(1, pictureArea.width / Math.max(1, original.implicitWidth), pictureArea.height / Math.max(1, original.implicitHeight))

        // read, translate, draw, done
        property string stage: "read"
        property string translatedText: ""
        property bool showOriginal: false
        readonly property bool done: stage === "done"

        // Where the scanner's light is, 0 at the top of the picture and 1 at the bottom.
        property real scanAt: 0
        property real scanLight: 0
        property bool scanForward: true
        // The last pass is laying the translation down, and then it is all there.
        property bool laying: false
        property bool revealed: false
        // An even speed, whatever the size of the picture. A real carriage does not ease in and out.
        readonly property int passTime: Math.max(1000, Math.min(2200, original.height * 3.2))
        readonly property int lastPassTime: Math.max(500, Math.min(950, original.height * 1.5))

        function close() {
            Ui.translateClose();
        }

        function finishScan() {
            if (laying || revealed)
                return;
            scanning.stop();
            scanForward = false;
            lastPass.start();
        }

        SequentialAnimation {
            id: scanning

            running: true
            loops: Animation.Infinite

            ScriptAction {
                script: win.scanForward = true
            }
            NumberAnimation {
                target: win
                property: "scanAt"
                from: 0
                to: 1
                duration: win.passTime
            }
            PauseAnimation {
                duration: 70
            }
            ScriptAction {
                script: win.scanForward = false
            }
            // The carriage runs back fast, as it does in a scanner.
            NumberAnimation {
                target: win
                property: "scanAt"
                to: 0
                duration: 300
                easing.type: Easing.InOutCubic
            }
            PauseAnimation {
                duration: 90
            }
        }
        NumberAnimation on scanLight {
            from: 0
            to: 1
            duration: 180
        }
        SequentialAnimation {
            id: lastPass

            // Home first, from wherever it was when the result came.
            NumberAnimation {
                target: win
                property: "scanAt"
                to: 0
                duration: 240 * Math.max(0.3, win.scanAt)
                easing.type: Easing.InOutCubic
            }
            ScriptAction {
                script: {
                    win.laying = true;
                    win.scanForward = true;
                }
            }
            NumberAnimation {
                target: win
                property: "scanAt"
                from: 0
                to: 1
                duration: win.lastPassTime
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: win
                property: "scanLight"
                to: 0
                duration: 220
                easing.type: Easing.OutCubic
            }
            ScriptAction {
                script: {
                    win.revealed = true;
                    win.laying = false;
                }
            }
        }

        title: "falcon translate"
        color: Theme.surface
        readonly property int startWidth: Math.max(620, Math.round(Ui.translateWidth * startScale) + margin * 2)
        readonly property int startHeight: Math.max(220, Math.round(Ui.translateHeight * startScale) + margin + barHeight)
        implicitWidth: startWidth
        implicitHeight: startHeight
        // niri opens a floating window at a default size unless the window insists on its own,
        // so the size is held at first and let go, which keeps the window resizable.
        property bool holdSize: true
        minimumSize: holdSize ? Qt.size(startWidth, startHeight) : Qt.size(420, 200)
        maximumSize: holdSize ? Qt.size(startWidth, startHeight) : Qt.size(0, 0)

        Timer {
            running: true
            interval: 400
            onTriggered: win.holdSize = false
        }

        Process {
            running: true
            command: [Ui.binDir + "falcon-image-translate", win.source, win.result]
            stdout: SplitParser {
                onRead: line => {
                    let message;
                    try {
                        message = JSON.parse(line);
                    } catch (e) {
                        return;
                    }
                    if (message.stage === "empty") {
                        Toasts.show(Tr.t("No text found"), Tr.t("Try selecting another area"), "alert");
                        win.close();
                    } else if (message.stage === "same") {
                        Toasts.show(Tr.t("Nothing to translate"), Tr.t("The text is already in this language. Change it in Settings → System"), "alert");
                        win.close();
                    } else if (message.stage === "error") {
                        Toasts.show(Tr.t("Translation failed"), Tr.t("No internet, or the free service is limiting requests. Try again in a few minutes"), "alert");
                        win.close();
                    } else {
                        if (message.stage === "done") {
                            win.translatedText = message.text;
                            translated.source = "file://" + win.result;
                        }
                        win.stage = message.stage;
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    win.close();
                    event.accepted = true;
                }
            }
        }

        Item {
            id: pictureArea

            x: win.margin
            y: win.margin
            width: parent.width - win.margin * 2
            height: parent.height - win.margin - win.barHeight
            clip: true

            Image {
                id: original

                anchors.centerIn: parent
                width: implicitWidth * win.pictureScale
                height: implicitHeight * win.pictureScale
                source: "file://" + win.source
                cache: false
                fillMode: Image.PreserveAspectFit
                mipmap: win.pictureScale < 1
            }
            // The translation lies under a window that opens behind the last pass of the light.
            Item {
                x: original.x
                y: original.y
                width: original.width
                height: original.height * (win.revealed ? 1 : win.laying ? win.scanAt : 0)
                clip: true
                opacity: win.showOriginal ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }

                Image {
                    id: translated

                    width: original.width
                    height: original.height
                    cache: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    mipmap: win.pictureScale < 1
                    onStatusChanged: {
                        if (status === Image.Ready)
                            win.finishScan();
                    }
                }
            }

            // The scanner: what it has not reached is dimmer, and one thin hot line travels at an even speed.
            Item {
                id: scanner

                readonly property real lineY: height * win.scanAt
                opacity: win.revealed ? 0 : 1

                x: original.x
                y: original.y
                width: original.width
                height: original.height
                clip: true
                visible: opacity > 0

                Rectangle {
                    y: scanner.lineY
                    width: parent.width
                    height: parent.height - y
                    color: Qt.alpha("black", 0.3 * win.scanLight)
                }
                // Light the sensor has just passed, which is left behind only on the way forward.
                Rectangle {
                    y: scanner.lineY - height
                    width: parent.width
                    height: Math.min(96, parent.height * 0.32)
                    opacity: win.scanForward ? win.scanLight : 0
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.alpha(Theme.accent, 0)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(Theme.accent, 0.2)
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
                // The glow around the lamp, then the lamp.
                Rectangle {
                    y: scanner.lineY - height / 2
                    width: parent.width
                    height: 26
                    opacity: win.scanLight
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.alpha(Theme.accent, 0)
                        }
                        GradientStop {
                            position: 0.5
                            color: Qt.alpha(Theme.accent, 0.6)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(Theme.accent, 0)
                        }
                    }
                }
                Rectangle {
                    y: scanner.lineY - 1
                    width: parent.width
                    height: 2
                    color: Qt.lighter(Theme.accent, 1.5)
                    opacity: win.scanLight
                }
                // The carriage that holds the lamp, on both edges.
                Repeater {
                    model: 2

                    delegate: Rectangle {
                        required property int index

                        x: index === 0 ? 0 : scanner.width - width
                        y: scanner.lineY - height / 2
                        width: 3
                        height: 18
                        radius: 1.5
                        color: "white"
                        opacity: win.scanLight
                    }
                }
            }
        }

        Item {
            anchors.bottom: parent.bottom
            width: parent.width
            height: win.barHeight

            Row {
                anchors.left: parent.left
                anchors.leftMargin: win.margin + 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "translate"
                    size: 18
                    color: Theme.accent
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.showOriginal ? Tr.t("Original") : win.stage === "read" ? Tr.t("Reading the text…") : win.stage === "translate" ? Tr.t("Translating…") : win.stage === "draw" ? Tr.t("Drawing…") : Tr.t("Translated")
                    color: Theme.muted
                    size: 13
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: win.margin
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                TranslateButton {
                    icon: "translate"
                    tip: win.showOriginal ? Tr.t("Show translation") : Tr.t("Show original")
                    active: win.showOriginal
                    enabled: win.done
                    onClicked: win.showOriginal = !win.showOriginal
                }
                TranslateButton {
                    icon: "copy"
                    tip: Tr.t("Copy picture")
                    enabled: win.done
                    onClicked: {
                        Quickshell.execDetached(["sh", "-c", 'exec wl-copy --type image/png < "$1"', "sh", win.result]);
                        Toasts.show(Tr.t("Picture copied"), "", "check");
                    }
                }
                TranslateButton {
                    icon: "note"
                    tip: Tr.t("Copy text")
                    enabled: win.done
                    onClicked: {
                        Quickshell.execDetached(["wl-copy", "--", win.translatedText]);
                        Toasts.show(Tr.t("Text copied"), "", "check");
                    }
                }
                TranslateButton {
                    icon: "save"
                    tip: Tr.t("Save picture")
                    enabled: win.done
                    onClicked: Ui.run("falcon-region", "save", win.result)
                }
                TranslateButton {
                    icon: "close"
                    tip: Tr.t("Close")
                    onClicked: win.close()
                }
            }
        }

        onClosed: Ui.translateClose()
    }
}
