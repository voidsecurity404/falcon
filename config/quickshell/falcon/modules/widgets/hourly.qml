import QtQuick
import qs.components
import qs.services

// The temperature of the next 24 hours as a soft curve.
Item {
    id: root

    readonly property var points: Weather.hourly.filter((h, i) => i % 3 === 0).slice(0, 8)
    readonly property int low: points.length ? Math.min(...points.map(p => p.temp)) : 0
    readonly property int high: points.length ? Math.max(...points.map(p => p.temp)) : 1
    readonly property real pad: 34
    readonly property real gap: points.length > 1 ? (width - pad * 2) / (points.length - 1) : 0

    function yOf(temp) {
        const span = Math.max(3, high - low);
        return 112 - (temp - low) / span * 56;
    }

    onPointsChanged: chart.requestPaint()

    Label {
        anchors.centerIn: parent
        visible: root.points.length === 0
        text: Tr.t("No weather data")
        color: Theme.muted
    }
    Canvas {
        id: chart

        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const p = root.points;
            if (p.length < 2)
                return;
            const line = () => {
                ctx.moveTo(root.pad, root.yOf(p[0].temp));
                for (let i = 1; i < p.length; i++) {
                    const x0 = root.pad + (i - 1) * root.gap;
                    const x1 = root.pad + i * root.gap;
                    ctx.bezierCurveTo((x0 + x1) / 2, root.yOf(p[i - 1].temp), (x0 + x1) / 2, root.yOf(p[i].temp), x1, root.yOf(p[i].temp));
                }
            };
            const fill = ctx.createLinearGradient(0, 40, 0, 136);
            fill.addColorStop(0, Qt.alpha(Theme.accent, 0.38));
            fill.addColorStop(1, Qt.alpha(Theme.accent, 0));
            ctx.beginPath();
            line();
            ctx.lineTo(root.pad + (p.length - 1) * root.gap, 136);
            ctx.lineTo(root.pad, 136);
            ctx.closePath();
            ctx.fillStyle = fill;
            ctx.fill();
            ctx.beginPath();
            line();
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.strokeStyle = Theme.accent;
            ctx.stroke();
        }

        Connections {
            target: Theme
            function onAccentChanged() {
                chart.requestPaint();
            }
        }
    }
    Repeater {
        model: root.points

        delegate: Item {
            id: mark

            required property var modelData
            required property int index

            x: root.pad + index * root.gap
            width: 0
            height: root.height

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.yOf(mark.modelData.temp) - 26
                text: mark.modelData.temp + "°"
                size: 13
                font.weight: Font.DemiBold
            }
            Rectangle {
                x: -3.5
                y: root.yOf(mark.modelData.temp) - 3.5
                width: 7
                height: 7
                radius: 3.5
                color: Theme.accent
                border.width: 1.5
                border.color: Theme.pill
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.height - 36
                text: mark.index === 0 ? Tr.t("Now") : Ui.pad(new Date(mark.modelData.time).getHours())
                color: Theme.muted
                size: 12
            }
        }
    }
}
