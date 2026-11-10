import QtQuick
import qs.services

// The sound looks drawn by one shader (shaders/spectrum.frag): ribbon, segments, aura, ring, orb.
// The 36 bands are smoothed here and handed over as nine vec4. Spectrum must be told someone is
// watching. When the sound stops the look sinks and the frame loop stops.
Item {
    id: root

    property bool active: true
    // ribbon, segments, aura, ring, orb
    property string style: "ribbon"
    property color color: Theme.accent
    property real alpha: 0.8
    property bool mirrored: true
    property real gain: 1
    property int smoothing: 70
    // Columns of segments, bars around the ring.
    property int bars: 72

    readonly property var looks: ["ribbon", "segments", "aura", "ring", "orb"]
    property var shown: []
    property real bass: 0
    property real time: 0
    property bool settled: true

    function step(seconds) {
        const levels = Spectrum.levels;
        const hearing = active && levels.length > 0;
        const k = 1 - Math.exp(-seconds * 1000 / (hearing ? Math.max(1, smoothing) : 170));
        const next = new Array(36);
        let busy = hearing;
        for (let i = 0; i < 36; i++) {
            const want = hearing ? Math.min(1, (levels[Math.min(levels.length - 1, i)] || 0) / 100 * gain) : 0;
            const was = shown.length === 36 ? shown[i] : 0;
            next[i] = was + (want - was) * k;
            if (next[i] > 0.003)
                busy = true;
        }
        shown = next;
        bass = (next[0] + next[1] + next[2] + next[3]) / 4;
        time += seconds;
        if (!busy)
            settled = true;
    }

    function part(i) {
        const s = shown;
        return Qt.vector4d(s[i * 4] || 0, s[i * 4 + 1] || 0, s[i * 4 + 2] || 0, s[i * 4 + 3] || 0);
    }

    onActiveChanged: settled = false
    onStyleChanged: settled = false

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

    ShaderEffect {
        anchors.fill: parent
        visible: !root.settled
        blending: true

        property vector4d b0: root.part(0)
        property vector4d b1: root.part(1)
        property vector4d b2: root.part(2)
        property vector4d b3: root.part(3)
        property vector4d b4: root.part(4)
        property vector4d b5: root.part(5)
        property vector4d b6: root.part(6)
        property vector4d b7: root.part(7)
        property vector4d b8: root.part(8)
        property color color1: root.color
        property color color2: Theme.hueShift(root.color, 0.06)
        property color color3: Theme.hueShift(root.color, -0.08)
        property vector2d size: Qt.vector2d(width, height)
        property real look: Math.max(0, root.looks.indexOf(root.style))
        property real time: root.time
        property real alpha: root.alpha
        property real mirrored: root.mirrored ? 1 : 0
        property real bars: root.bars
        property real bass: root.bass
        fragmentShader: Qt.resolvedUrl("../shaders/spectrum.frag.qsb")
    }
}
