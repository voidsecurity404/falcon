import QtQuick
import qs.services

// CPU load over the last two minutes: a thin line with a soft fill. Hover reads a value.
Item {
    id: root

    property var values: []
    property int stepSeconds: 2

    readonly property int hoverIndex: area.containsMouse && values.length > 1 ? Math.max(0, Math.min(values.length - 1, Math.round(area.mouseX / width * (values.length - 1)))) : -1

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
            const x = i => i / (v.length - 1) * width;
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
            ctx.lineTo(0, height);
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
        x: root.hoverIndex / Math.max(1, root.values.length - 1) * root.width
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
            text: root.hoverIndex >= 0 ? Math.round(root.values[root.hoverIndex]) + "% · " + Tr.t("{n} s ago").replace("{n}", (root.values.length - 1 - root.hoverIndex) * root.stepSeconds) : ""
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
