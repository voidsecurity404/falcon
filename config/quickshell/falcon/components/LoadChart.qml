import QtQuick
import qs.services

// CPU load over the last two minutes: a thin line with a soft fill. Hover reads a value.
// The newest value stands at the right edge, and the line grows to the left as values come in.
Item {
    id: root

    property var values: []
    property int stepSeconds: 2
    property int slots: 60

    readonly property real step: width / (slots - 1)
    readonly property int hoverAge: area.containsMouse && values.length > 1 ? Math.max(0, Math.round((width - area.mouseX) / step)) : -1
    readonly property int hoverIndex: hoverAge >= 0 && hoverAge < values.length ? values.length - 1 - hoverAge : -1

    onValuesChanged: chart.requestPaint()
    onWidthChanged: chart.requestPaint()

    Connections {
        target: Theme
        function onAccentChanged() {
            chart.requestPaint();
        }
    }

    Canvas {
        id: chart

        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const v = root.values;
            if (v.length < 2)
                return;
            const x = i => width - (v.length - 1 - i) * root.step;
            const y = n => height - 2 - (height - 4) * Math.max(0, Math.min(100, n)) / 100;
            ctx.beginPath();
            ctx.moveTo(x(0), y(v[0]));
            for (let i = 1; i < v.length; i++)
                ctx.lineTo(x(i), y(v[i]));
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.strokeStyle = Theme.accent;
            ctx.stroke();
            ctx.lineTo(width, height);
            ctx.lineTo(x(0), height);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.alpha(Theme.accent, 0.26));
            fill.addColorStop(1, Qt.alpha(Theme.accent, 0));
            ctx.fillStyle = fill;
            ctx.fill();
        }
    }

    Rectangle {
        visible: root.hoverIndex >= 0
        x: root.width - root.hoverAge * root.step
        width: 1
        height: root.height
        color: Qt.alpha(Theme.text, 0.35)
    }
    Rectangle {
        visible: root.hoverIndex >= 0
        x: Math.max(0, Math.min(root.width - width, area.mouseX - width / 2))
        y: -2
        width: tip.implicitWidth + 16
        height: 22
        radius: 7
        color: Theme.pill

        Label {
            id: tip

            anchors.centerIn: parent
            text: root.hoverIndex >= 0 ? Math.round(root.values[root.hoverIndex]) + "% · " + Tr.t("{n} s ago").replace("{n}", root.hoverAge * root.stepSeconds) : ""
            size: 11
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
