import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Shows a selected area with its text translated on the picture itself. The original is seen while
// the work goes on, then the result fades in. Reading and drawing are done by niri-desk-image-translate.
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

        function close() {
            Ui.translateClose();
        }

        title: "niri-desk translate"
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
            command: [Ui.binDir + "niri-desk-image-translate", win.source, win.result]
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
                    } else if (message.stage === "error") {
                        Toasts.show(Tr.t("Translation failed"), Tr.t("Check the internet"), "alert");
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
            Image {
                id: translated

                anchors.centerIn: parent
                width: original.width
                height: original.height
                cache: false
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                mipmap: win.pictureScale < 1
                opacity: status === Image.Ready && !win.showOriginal ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // A band of light passes over the picture while it is being read.
            Rectangle {
                id: scan

                readonly property real travel: original.height + height

                visible: !win.done
                x: original.x
                width: original.width
                height: Math.min(120, original.height * 0.6)
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Theme.accent, 0)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Theme.accent, 0.4)
                    }
                }

                NumberAnimation on y {
                    running: !win.done
                    loops: Animation.Infinite
                    from: original.y - scan.height
                    to: original.y + original.height
                    duration: 1500
                    easing.type: Easing.InOutSine
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
                    onClicked: Ui.run("niri-desk-region", "save", win.result)
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
