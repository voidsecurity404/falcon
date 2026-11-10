import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// Choosing a part of the screen, modeled on end-4's region selector. The screen is pictured first
// and shown frozen, so the selection is cut from exactly what is seen. Dragging selects an area,
// a click takes the window under the pointer, and the action in the toolbar runs on release.
PanelWindow {
    id: root

    readonly property string outputName: screen ? screen.name : ""
    readonly property string picture: Ui.regionDir + "/" + outputName + ".ppm"
    readonly property bool live: Ui.regionPhase === "select" && image.status === Image.Ready
    readonly property real pixelScale: width > 0 ? image.implicitWidth / width : 1

    property var targets: []
    property int targeted: -1
    property bool dragging: false
    property bool pointerSeen: false
    property real startX: 0
    property real startY: 0
    property real pointerX: 0
    property real pointerY: 0
    property var lasso: []
    property real shown: 0

    readonly property real selX: lassoBox ? lassoBox.x : Math.min(startX, pointerX)
    readonly property real selY: lassoBox ? lassoBox.y : Math.min(startY, pointerY)
    readonly property real selW: lassoBox ? lassoBox.w : Math.abs(pointerX - startX)
    readonly property real selH: lassoBox ? lassoBox.h : Math.abs(pointerY - startY)
    readonly property bool hasArea: dragging && selW > 3 && selH > 3
    readonly property var lassoBox: {
        if (!Ui.regionLasso || lasso.length < 2)
            return null;
        const xs = lasso.map(p => p.x);
        const ys = lasso.map(p => p.y);
        const x = Math.min(...xs);
        const y = Math.min(...ys);
        return { x: x, y: y, w: Math.max(...xs) - x, h: Math.max(...ys) - y };
    }
    readonly property var target: targeted >= 0 && !hasArea ? targets[targeted] : null

    readonly property var actions: [
        { id: "copy", icon: "screenshot", name: Tr.t("Screenshot"), hint: Tr.t("Left click copies, right click edits") },
        { id: "search", icon: "google", name: Tr.t("Google"), hint: Tr.t("Search on Google") },
        { id: "ocr", icon: "ocr", name: Tr.t("Text"), hint: Tr.t("Copy the text") },
        { id: "translate", icon: "translate", name: Tr.t("Translate"), hint: Tr.t("Translate the text on the picture") },
        { id: "pin", icon: "pin", name: Tr.t("Pin"), hint: Tr.t("Keep the picture on top of the windows") },
        { id: "record", icon: "record", name: Tr.t("Record"), hint: Tr.t("Record this area") }
    ]
    readonly property var currentAction: actions.find(a => a.id === Ui.regionAction) || actions[0]

    function findTarget(x, y) {
        return targets.findIndex(t => x >= t.x && x < t.x + t.w && y >= t.y && y < t.y + t.h);
    }

    function finish(x, y, w, h, button) {
        const left = Math.max(0, Math.round(x));
        const top = Math.max(0, Math.round(y));
        const right = Math.min(width, Math.round(x + w));
        const bottom = Math.min(height, Math.round(y + h));
        if (right - left < 2 || bottom - top < 2)
            return;
        const action = Ui.regionAction === "copy" && button === Qt.RightButton ? "edit" : Ui.regionAction;
        const s = pixelScale;
        Ui.regionFinished();
        Ui.run("falcon-region", action, picture,
            String(Math.round(left * s)), String(Math.round(top * s)),
            String(Math.round((right - left) * s)), String(Math.round((bottom - top) * s)),
            `${screen.x + left},${screen.y + top} ${right - left}x${bottom - top}`);
    }

    visible: live
    color: "black"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "falcon-region"
    WlrLayershell.keyboardFocus: live ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    onLiveChanged: {
        if (live) {
            shown = 1;
            keys.forceActiveFocus();
        } else {
            shown = 0;
            dragging = false;
            pointerSeen = false;
            lasso = [];
            targets = [];
            targeted = -1;
        }
    }

    Behavior on shown {
        NumberAnimation {
            duration: root.shown > 0 ? 220 : 0
            easing.type: Easing.OutCubic
        }
    }

    // A new picture for each opening: first the file, then the window once it is decoded.
    Connections {
        target: Ui

        function onRegionPhaseChanged() {
            if (Ui.regionPhase === "grab") {
                image.source = "";
                grab.running = true;
            } else if (Ui.regionPhase === "") {
                image.source = "";
            }
        }
        function onRegionPicked(x, y, w, h, done) {
            root.startX = x;
            root.startY = y;
            root.pointerX = x + w;
            root.pointerY = y + h;
            root.dragging = !done;
            if (done)
                root.finish(x, y, w, h, Qt.LeftButton);
        }
    }

    Process {
        id: grab

        command: ["sh", "-c", 'mkdir -p "$(dirname "$2")" && exec grim -t ppm -o "$1" "$2"', "sh", root.outputName, root.picture]
        onExited: code => {
            if (code !== 0) {
                Ui.regionGrabbed(false);
                return;
            }
            image.source = "file://" + root.picture + "?" + Date.now();
        }
    }

    Process {
        id: locate

        command: [Ui.binDir + "falcon-region-windows", root.picture, root.outputName]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.targets = JSON.parse(text);
                } catch (e) {
                    root.targets = [];
                }
                if (root.pointerSeen)
                    root.targeted = root.findTarget(root.pointerX, root.pointerY);
            }
        }
    }

    Image {
        id: image

        anchors.fill: parent
        cache: false
        asynchronous: true
        smooth: false
        onStatusChanged: {
            if (status === Image.Ready) {
                Ui.regionGrabbed(true);
                locate.running = true;
            } else if (status === Image.Error) {
                Ui.regionGrabbed(false);
            }
        }
    }

    // The darkness around the selection is one thick border, as in end-4's.
    Rectangle {
        readonly property real thick: Math.max(root.width, root.height)
        readonly property bool open: root.hasArea && !Ui.regionLasso
        readonly property real holeX: open ? root.selX : root.target ? root.target.x : root.width / 2
        readonly property real holeY: open ? root.selY : root.target ? root.target.y : root.height / 2
        readonly property real holeW: open ? root.selW : root.target ? root.target.w : 0
        readonly property real holeH: open ? root.selH : root.target ? root.target.h : 0

        x: holeX - thick
        y: holeY - thick
        width: holeW + thick * 2
        height: holeH + thick * 2
        color: "transparent"
        border.color: Qt.rgba(0, 0, 0, 0.45)
        border.width: thick
        opacity: root.shown
    }

    // The other windows can be seen as choices.
    Repeater {
        model: root.dragging ? [] : root.targets

        delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property bool active: root.targeted === index

            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            radius: Settings.get("windows.radius", 12)
            color: active ? Qt.alpha(Theme.accent, 0.1) : "transparent"
            border.width: active ? 2 : 1
            border.color: active ? Theme.accent : Qt.alpha(Theme.accent, 0.3)
            opacity: root.shown

            Rectangle {
                visible: parent.active
                x: 12
                y: 12
                width: Math.min(parent.width - 24, appName.implicitWidth + 20)
                height: 28
                radius: 14
                color: Theme.accent

                Label {
                    id: appName

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 20)
                    text: modelData.app
                    color: Theme.accentText
                    size: 12
                }
            }
        }
    }

    // Aim lines
    Rectangle {
        visible: root.pointerSeen && !root.dragging && !toolbarHover.hovered
        x: Math.round(root.pointerX)
        width: 1
        height: parent.height
        color: Theme.accent
        opacity: 0.35
    }
    Rectangle {
        visible: root.pointerSeen && !root.dragging && !toolbarHover.hovered
        y: Math.round(root.pointerY)
        width: parent.width
        height: 1
        color: Theme.accent
        opacity: 0.35
    }

    // The selection
    Item {
        visible: root.hasArea && !Ui.regionLasso
        x: root.selX
        y: root.selY
        width: root.selW
        height: root.selH

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.width: 1
            border.color: Theme.accent
        }
        Repeater {
            model: 4

            delegate: Item {
                required property int index
                readonly property bool onRight: index % 2 === 1
                readonly property bool onBottom: index > 1
                readonly property int arm: Math.min(18, Math.min(root.selW, root.selH) / 2)

                x: onRight ? parent.width - arm + 2 : -2
                y: onBottom ? parent.height - arm + 2 : -2
                width: arm
                height: arm

                Rectangle {
                    width: parent.width
                    height: 3
                    y: parent.onBottom ? parent.height - 3 : 0
                    radius: 1.5
                    color: Theme.accent
                }
                Rectangle {
                    width: 3
                    height: parent.height
                    x: parent.onRight ? parent.width - 3 : 0
                    radius: 1.5
                    color: Theme.accent
                }
            }
        }
    }

    // Freehand: the darkness stays whole and the line shows the shape, its box is what gets taken.
    Rectangle {
        anchors.fill: parent
        visible: Ui.regionLasso && root.dragging
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Canvas {
        id: lassoCanvas

        anchors.fill: parent
        visible: Ui.regionLasso && root.dragging
        renderStrategy: Canvas.Threaded
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const points = root.lasso;
            if (points.length < 2)
                return;
            ctx.strokeStyle = String(Theme.accent);
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            ctx.moveTo(points[0].x, points[0].y);
            for (let i = 1; i < points.length; i++)
                ctx.lineTo(points[i].x, points[i].y);
            ctx.stroke();
        }
    }

    // Size of the selection
    Rectangle {
        readonly property bool below: root.selY + root.selH + height + 8 < root.height

        visible: root.hasArea
        x: Math.max(4, Math.min(root.width - width - 4, root.selX + root.selW - width))
        y: below ? root.selY + root.selH + 8 : Math.max(4, root.selY - height - 8)
        width: sizeText.implicitWidth + 18
        height: 24
        radius: 12
        color: Qt.alpha(Theme.pill, 0.9)

        Label {
            id: sizeText

            anchors.centerIn: parent
            text: `${Math.round(root.selW * root.pixelScale)} × ${Math.round(root.selH * root.pixelScale)}`
            size: 11
        }
    }

    Item {
        id: keys

        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Ui.regionCancel();
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: mouse => {
            root.pointerSeen = true;
            root.pointerX = mouse.x;
            root.pointerY = mouse.y;
            if (!root.dragging) {
                root.targeted = root.findTarget(mouse.x, mouse.y);
                return;
            }
            if (Ui.regionLasso) {
                const last = root.lasso[root.lasso.length - 1];
                if (!last || Math.hypot(last.x - mouse.x, last.y - mouse.y) >= 3) {
                    root.lasso = root.lasso.concat([{ x: mouse.x, y: mouse.y }]);
                    lassoCanvas.requestPaint();
                }
            }
        }
        onPressed: mouse => {
            root.startX = mouse.x;
            root.startY = mouse.y;
            root.pointerX = mouse.x;
            root.pointerY = mouse.y;
            root.lasso = [];
            root.dragging = true;
        }
        onReleased: mouse => {
            const area = root.hasArea;
            const x = root.selX;
            const y = root.selY;
            const w = root.selW;
            const h = root.selH;
            root.dragging = false;
            if (area) {
                root.finish(x, y, w, h, mouse.button);
                return;
            }
            root.lasso = [];
            const t = root.targets[root.findTarget(mouse.x, mouse.y)];
            if (t)
                root.finish(t.x, t.y, t.w, t.h, mouse.button);
        }
    }

    // What the action is, beside the pointer. The words go after a moment and the icon stays.
    Rectangle {
        id: guide

        property bool wordy: true

        readonly property real anchorX: root.dragging && !Ui.regionLasso ? root.selX + root.selW : root.pointerX
        readonly property real anchorY: root.dragging && !Ui.regionLasso ? root.selY + root.selH : root.pointerY

        visible: root.pointerSeen && !toolbarHover.hovered && root.shown > 0
        x: anchorX + 14 + width > root.width ? anchorX - width - 14 : anchorX + 14
        y: anchorY + 14 + height > root.height ? anchorY - height - 14 : anchorY + 14
        width: wordy ? guideRow.implicitWidth + 22 : 34
        height: 34
        radius: 17
        topLeftRadius: 5
        clip: true
        color: Theme.accent

        Behavior on width {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Timer {
            id: guideWords

            interval: 1400
            running: root.live
            onTriggered: guide.wordy = false
        }
        Connections {
            target: Ui

            function onRegionActionChanged() {
                guide.wordy = true;
                guideWords.restart();
            }
            function onRegionPhaseChanged() {
                guide.wordy = true;
            }
        }

        Row {
            id: guideRow

            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.currentAction.icon
                size: 18
                color: Theme.accentText
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentAction.hint
                color: Theme.accentText
                size: 12
            }
        }
    }

    // The toolbar: the action, the way of selecting, and a way out.
    Rectangle {
        id: toolbar

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - (height + 18) * root.shown
        width: toolRow.implicitWidth + 16
        height: 60
        radius: 30
        color: Qt.alpha(Theme.glassBase, 0.92)
        border.width: 1
        border.color: Theme.panelEdge
        opacity: root.dragging ? 0 : root.shown

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        HoverHandler {
            id: toolbarHover
        }
        // Catches presses so that they do not start a selection underneath.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            enabled: !root.dragging
        }

        Row {
            id: toolRow

            anchors.centerIn: parent
            spacing: 6

            RegionSegments {
                anchors.verticalCenter: parent.verticalCenter
                items: root.actions
                current: root.actions.indexOf(root.currentAction)
                onChosen: index => Ui.regionAction = root.actions[index].id
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 26
                color: Theme.panelEdge
            }
            RegionSegments {
                anchors.verticalCenter: parent.verticalCenter
                items: [
                    { icon: "selectRect", name: Tr.t("Rectangle") },
                    { icon: "lasso", name: Tr.t("Freehand") }
                ]
                current: Ui.regionLasso ? 1 : 0
                onChosen: index => Ui.regionLasso = index === 1
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                color: closeArea.containsMouse ? Qt.alpha(Theme.text, 0.14) : "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 18
                }
                MouseArea {
                    id: closeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.regionCancel()
                }
            }
        }
    }
}
