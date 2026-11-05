import QtQuick
import QtQuick.Shapes
import qs.services

// Moves with the sound: bars, dots, a filled wave or a line. Spectrum must be told someone is watching.
Item {
    id: root

    // Off means the shapes sink and stop, so a hidden copy costs nothing.
    property bool active: true
    property string style: "bars"
    property color color: Theme.accent
    property real topAlpha: 0.55
    property real bottomAlpha: 0.04
    property int gap: 4
    // Bars or dots across the width. A wave or line always takes a point every few pixels.
    property int bars: Spectrum.count * 2
    // From the middle to both sides, otherwise low notes on the left.
    property bool mirrored: true
    property real gain: 1
    // How long a change takes to arrive, in ms.
    property int smoothing: 70

    readonly property bool drawn: style === "wave" || style === "line"
    readonly property int points: drawn ? Math.max(2, Math.ceil(width / 8) + 1) : bars
    readonly property real barWidth: (width - gap * (bars - 1)) / Math.max(1, bars)
    property var shown: []
    property var outline: []
    property bool settled: true

    function target(i) {
        if (!active || Spectrum.levels.length === 0)
            return 0;
        const last = Spectrum.levels.length - 1;
        const along = points > 1 ? i / (points - 1) : 0;
        const x = (mirrored ? Math.abs(along * 2 - 1) : along) * last;
        const low = Math.floor(x);
        const high = Math.min(last, low + 1);
        // Cosine between bands, or a wave would show their corners.
        const t = (1 - Math.cos((x - low) * Math.PI)) / 2;
        return Math.min(1, (Spectrum.levels[low] * (1 - t) + Spectrum.levels[high] * t) / 100 * gain);
    }

    function step(seconds) {
        const hearing = active && Spectrum.levels.length > 0;
        // It follows the sound as set, and sinks slowly once the music stops.
        const k = 1 - Math.exp(-seconds * 1000 / (hearing ? Math.max(1, smoothing) : 170));
        const h = height;
        const n = points;
        const before = shown;
        const next = new Array(n);
        let busy = hearing;
        for (let i = 0; i < n; i++) {
            const was = before.length === n ? before[i] : 0;
            const value = was + (target(i) - was) * k;
            next[i] = value;
            if (value > 0.003)
                busy = true;
        }
        shown = next;
        if (drawn) {
            const line = new Array(n);
            for (let i = 0; i < n; i++)
                line[i] = Qt.point(i * width / (n - 1), h - next[i] * h);
            outline = line;
        }
        if (!busy)
            settled = true;
    }

    onActiveChanged: settled = false
    onStyleChanged: settled = false
    onBarsChanged: settled = false

    Connections {
        target: Spectrum

        function onLevelsChanged() {
            root.settled = false;
        }
    }

    FrameAnimation {
        running: root.visible && !root.settled
        onTriggered: root.step(Math.min(frameTime, 0.1))
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.height
        spacing: root.gap
        visible: !root.drawn

        Repeater {
            model: root.drawn ? 0 : root.bars

            delegate: Item {
                id: slot

                required property int index
                readonly property real level: root.shown[index] || 0

                width: root.barWidth
                height: root.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: slot.level * root.height
                    visible: root.style === "bars" && height > 1
                    topLeftRadius: width / 2
                    topRightRadius: width / 2
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.alpha(root.color, root.topAlpha)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(root.color, root.bottomAlpha)
                        }
                    }
                }
                Rectangle {
                    readonly property real size: Math.min(parent.width, 16)

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.height - size - slot.level * (root.height - size)
                    width: size
                    height: size
                    radius: size / 2
                    visible: root.style === "dots" && slot.level > 0.01
                    color: Qt.alpha(root.color, root.topAlpha)
                }
            }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.drawn && !root.settled
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height
                GradientStop {
                    position: 0
                    color: root.style === "wave" ? Qt.alpha(root.color, root.topAlpha) : "transparent"
                }
                GradientStop {
                    position: 1
                    color: root.style === "wave" ? Qt.alpha(root.color, root.bottomAlpha) : "transparent"
                }
            }
            startX: 0
            startY: root.height

            PathPolyline {
                path: root.outline
            }
            PathLine {
                x: root.width
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
        }
        ShapePath {
            strokeColor: Qt.alpha(root.color, Math.min(1, root.topAlpha + 0.15))
            strokeWidth: 3
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            PathPolyline {
                path: root.outline
            }
        }
    }
}
