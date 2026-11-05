import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// Processor load of the last two minutes, filling the widget from below. Forms: wide, compact.
Item {
    id: root

    property string form: "wide"
    readonly property bool compact: form === "compact"

    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"

        Canvas {
            id: graph

            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const values = Sys.history;
                if (values.length < 2)
                    return;
                const slots = 59;
                const span = height * 0.72;
                const xOf = i => width - (values.length - 1 - i) * width / slots;
                const yOf = v => height - 2 - Math.max(0.02, v / 100) * span;
                const fill = ctx.createLinearGradient(0, height - span, 0, height);
                fill.addColorStop(0, Qt.alpha(Theme.accent, 0.5));
                fill.addColorStop(1, Qt.alpha(Theme.accent, 0.04));
                const path = () => {
                    ctx.moveTo(xOf(0), yOf(values[0]));
                    for (let i = 1; i < values.length; i++) {
                        const mid = (xOf(i - 1) + xOf(i)) / 2;
                        ctx.bezierCurveTo(mid, yOf(values[i - 1]), mid, yOf(values[i]), xOf(i), yOf(values[i]));
                    }
                };
                ctx.beginPath();
                path();
                ctx.lineTo(width, height);
                ctx.lineTo(xOf(0), height);
                ctx.closePath();
                ctx.fillStyle = fill;
                ctx.fill();
                ctx.beginPath();
                path();
                ctx.lineWidth = 2.5;
                ctx.strokeStyle = Theme.accent;
                ctx.stroke();
            }

            Connections {
                target: Sys
                function onHistoryChanged() {
                    graph.requestPaint();
                }
            }
        }
    }
    Row {
        x: 20
        y: root.compact ? 12 : 16
        spacing: 10

        Label {
            id: figure

            text: Sys.cpu + "%"
            size: root.compact ? 30 : 42
            font.family: Theme.display
            font.weight: Font.Medium
        }
        Label {
            anchors.baseline: figure.baseline
            text: Tr.t("Processor")
            color: Theme.muted
            size: 13
        }
    }
}
