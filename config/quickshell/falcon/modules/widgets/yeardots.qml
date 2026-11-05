import QtQuick
import Quickshell
import qs.components
import qs.services

// One dot per day of the year: gone, today, still ahead. Forms: wide, tall.
Item {
    id: root

    property string form: "wide"
    readonly property bool tall: form === "tall"
    readonly property int year: clock.date.getFullYear()
    readonly property int total: new Date(year, 1, 29).getMonth() === 1 ? 366 : 365
    readonly property int today: Math.round((new Date(year, clock.date.getMonth(), clock.date.getDate()) - new Date(year, 0, 1)) / 86400000)

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    Column {
        x: 20
        y: 14
        spacing: 0

        Label {
            text: root.year
            size: 20
            font.family: Theme.display
            font.weight: Font.Bold
        }
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 20
        text: Tr.t("{n} days left").replace("{n}", root.total - root.today - 1)
        color: Theme.muted
        size: 12
    }
    Canvas {
        id: dots

        readonly property int across: root.tall ? 16 : 32
        readonly property real step: root.tall ? 11 : 11

        x: (parent.width - across * step) / 2
        y: 52
        width: across * step
        height: parent.height - y - 10
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const done = Qt.alpha(Theme.text, 0.82);
            const ahead = Qt.alpha(Theme.text, 0.14);
            for (let i = 0; i < root.total; i++) {
                const col = i % across;
                const row = Math.floor(i / across);
                ctx.beginPath();
                ctx.fillStyle = i === root.today ? Theme.accent : i < root.today ? done : ahead;
                ctx.arc(col * step + step / 2, row * step + step / 2, i === root.today ? 5 : 3.6, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        Connections {
            target: root
            function onTodayChanged() {
                dots.requestPaint();
            }
        }
        Connections {
            target: Theme
            function onAccentChanged() {
                dots.requestPaint();
            }
            function onTextChanged() {
                dots.requestPaint();
            }
        }
    }
}
