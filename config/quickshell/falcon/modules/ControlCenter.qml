import QtQuick
import Quickshell
import qs.components
import qs.services

// The control center's frame: its glass, the way it opens, and the Wi-Fi, Bluetooth and
// recording pages. What the main page looks like belongs to the panel layout (style), each one
// its own file: FalconControls, HaloControls, RailControls, StudioControls, WinControls,
// MacControls, TermControls, OrbitControls. The frame grows its own size, never a scale,
// because the blur region follows that.
Rectangle {
    id: root

    property bool shown: false
    property real reveal: 0
    // Inside another glass (the halo capsule, the studio sidebar) it draws no glass of its own and
    // keeps its full size: the host grows and fades it.
    property bool embedded: false
    // The page sits at the bottom while the panel grows, so it seems to come up from below.
    property bool growUp: Settings.bottom
    readonly property string style: Settings.layout
    readonly property bool onMain: Ui.controlPage === ""
    // The orbit's main page is a circle, its other pages a rounded card.
    readonly property bool round: style === "orbit" && onMain
    readonly property int panelWidth: ({
            falcon: 430,
            halo: 400,
            rail: 396,
            studio: 446,
            windows: 372,
            macos: 336,
            terminal: 470,
            orbit: 420
        })[style] || 430
    readonly property int padding: onMain ? (({
                windows: 0,
                macos: 10,
                terminal: 0,
                orbit: 0
            })[style] ?? 16) : 16
    readonly property int baseRadius: ({
            windows: 12,
            macos: 18,
            terminal: 6,
            rail: 22
        })[style] ?? 28
    readonly property real pageHeight: (onMain ? content.height : pageLoader.implicitHeight) + padding * 2
    property real shownHeight: pageHeight
    // How far below its place it still is, for the layouts that slide it up into place.
    readonly property real offsetY: embedded ? 0 : style === "windows" ? (1 - reveal) * 40 : style === "macos" ? -(1 - reveal) * 10 : 0

    onShownChanged: {
        if (embedded) {
            reveal = shown ? 1 : 0;
            if (!shown)
                pageReset.restart();
            return;
        }
        revealAnimation.stop();
        revealAnimation.to = shown ? 1 : 0;
        // Each layout opens in its own way: falcon and rail drop and settle, windows slides up
        // quickly, macos pops, the console unrolls line by line, the orbit blooms from its middle.
        const timing = ({
                windows: [260, 160, [0.1, 0.9, 0.2, 1, 1, 1], [0.7, 0, 1, 0.5, 1, 1]],
                macos: [240, 150, [0.3, 1.25, 0.4, 1, 1, 1], [0.4, 0, 1, 1, 1, 1]],
                terminal: [300, 180, [0, 0, 1, 1, 1, 1], [0, 0, 1, 1, 1, 1]],
                orbit: [620, 260, [0.2, 1.3, 0.35, 1, 1, 1], [0.5, 0, 0.9, 0.3, 1, 1]]
            })[style] || [420, 220, [0.2, 0, 0, 1, 1, 1], [0.3, 0, 0.8, 0.15, 1, 1]];
        revealAnimation.duration = shown ? timing[0] : timing[1];
        revealAnimation.easing.bezierCurve = shown ? timing[2] : timing[3];
        revealAnimation.start();
    }
    onHeightChanged: Ui.controlHeight = height

    signal releaseFocus

    Timer {
        id: pageReset

        interval: 420
        onTriggered: {
            if (!root.shown)
                Ui.controlPage = "";
        }
    }

    Gradient {
        id: glass

        GradientStop {
            position: 0
            color: root.style === "orbit" ? Qt.alpha(Qt.tint(Theme.glassBase, Qt.alpha(Theme.accent, 0.16)), Math.max(0.74, Theme.glassOpacity)) : Qt.alpha(Theme.glassBase, Math.max(root.style === "windows" ? 0.86 : root.style === "terminal" ? 0.93 : root.style === "macos" ? 0.62 : 0.7, Theme.glassOpacity))
        }
        GradientStop {
            position: 1
            color: Qt.alpha(Theme.glassBase, Math.max(root.style === "windows" ? 0.84 : root.style === "terminal" ? 0.93 : root.style === "macos" ? 0.56 : 0.58, Theme.glassOpacity))
        }
    }

    // How big the frame is at this point of opening.
    readonly property real growWidth: {
        if (round)
            return panelWidth * reveal;
        if (style === "macos")
            return panelWidth * (0.94 + 0.06 * reveal);
        if (style === "windows" || style === "terminal")
            return panelWidth;
        return panelWidth - 28 * (1 - reveal);
    }
    readonly property real growHeight: {
        if (round)
            return panelWidth * reveal;
        if (style === "windows")
            return shownHeight;
        if (style === "macos")
            return shownHeight * (0.88 + 0.12 * reveal);
        // The console unrolls a line of text at a time.
        if (style === "terminal")
            return reveal >= 1 ? shownHeight : Math.min(shownHeight, Math.ceil(reveal * shownHeight / 22) * 22);
        return shownHeight * reveal;
    }

    width: embedded ? panelWidth : growWidth
    height: embedded ? shownHeight : growHeight
    clip: true
    radius: round ? width / 2 : baseRadius
    border.width: embedded ? 0 : 1
    border.color: style === "terminal" ? Qt.alpha(Theme.accent, 0.7) : style === "macos" ? Qt.alpha(Theme.text, 0.2) : Theme.panelEdge
    color: "transparent"
    // Stays dark enough for its text over a white window, whatever the panel opacity is.
    gradient: embedded ? null : glass
    opacity: embedded ? 1 : style === "windows" || style === "macos" ? reveal : Math.min(1, reveal * 2.5)
    visible: embedded || reveal > 0

    NumberAnimation {
        id: revealAnimation

        target: root
        property: "reveal"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (!root.shown)
                Ui.controlPage = "";
        }
    }

    Behavior on shownHeight {
        enabled: root.reveal >= 1 && !root.embedded

        NumberAnimation {
            duration: 380
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 1.1, 0.35, 1, 1, 1]
        }
    }

    // Panel ichidagi bosish orqadagi catcher'ga o'tib ketmasin.
    MouseArea {
        anchors.fill: parent
        enabled: !root.embedded
    }

    // Keeps its size while the panel grows, so nothing inside reflows.
    Item {
        x: (root.width - width) / 2
        y: root.round ? (root.height - height) / 2 : root.growUp ? root.height - height : 0
        width: root.panelWidth
        height: root.pageHeight

        // Wi-Fi and Bluetooth lists and the recording choices open in place of the main page.
        Loader {
            id: pageLoader

            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            active: Ui.controlPage !== ""
            source: Ui.controlPage === "wifi" ? "WifiPage.qml" : Ui.controlPage === "bluetooth" ? "BluetoothPage.qml" : Ui.controlPage === "record" ? "RecordPage.qml" : ""
            opacity: status === Loader.Ready ? 1 : 0
            transform: Translate {
                x: pageLoader.status === Loader.Ready ? 0 : 28

                Behavior on x {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.25, 1.2, 0.35, 1, 1, 1]
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        Connections {
            target: pageLoader.item
            ignoreUnknownSignals: true

            function onReleaseFocus() {
                root.releaseFocus();
            }
        }

        // The main page of this layout.
        Loader {
            id: content

            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            height: item ? item.implicitHeight : 0
            visible: opacity > 0
            opacity: root.onMain ? 1 : 0
            sourceComponent: ({
                    halo: haloPage,
                    rail: railPage,
                    studio: studioPage,
                    windows: winPage,
                    macos: macPage,
                    terminal: termPage,
                    orbit: orbitPage
                })[root.style] || falconPage
            transform: Translate {
                x: root.onMain ? 0 : -28

                Behavior on x {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }
    }

    Component {
        id: falconPage

        FalconControls {
            shown: root.shown
        }
    }
    Component {
        id: haloPage

        HaloControls {
            shown: root.shown
        }
    }
    Component {
        id: railPage

        RailControls {
            shown: root.shown
        }
    }
    Component {
        id: studioPage

        StudioControls {
            shown: root.shown
        }
    }
    Component {
        id: winPage

        WinControls {
            shown: root.shown
        }
    }
    Component {
        id: macPage

        MacControls {
            shown: root.shown
        }
    }
    Component {
        id: termPage

        TermControls {
            shown: root.shown
            reveal: root.reveal
        }
    }
    Component {
        id: orbitPage

        OrbitControls {
            shown: root.shown
            reveal: root.reveal
            size: root.panelWidth
        }
    }
}
