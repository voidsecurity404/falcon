import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Qiyshiq tilimlar: tanlangani keng ochiladi, fon tanlanganda ranglar ham undan olinadi.
LazyLoader {
    active: Ui.pickerAlive

    // Reading this starts the service with the shell, so the pictures are ready before the first opening.
    readonly property int known: Wallpapers.liveFiles.length + Wallpapers.imageFiles.length

    PanelWindow {
        id: root

        readonly property string liveDir: Settings.wallpaperDir + "/Live"

        // 0: jonli fonlar, 1: oddiy rasmlar. Har biri o'z o'rnini eslab qoladi.
        property int tab: 1
        property var marks: [0, 0]
        // Runs from 0 (live) to 1 (plain). Every part of a tab change is computed from this one
        // value, so another Tab in the middle simply plays the same movement back from there.
        property real travel: tab
        // The share of the change by which the far side of the screen starts later than the near one.
        readonly property real waveDelay: 0.4

        // Choosing the starting tab shows no change. Any press animates, however soon after opening.
        property bool placing: false

        Behavior on travel {
            enabled: !root.placing

            NumberAnimation {
                duration: 320
            }
        }

        // Once the user has moved, a late answer about the current wallpaper must not move the carousel.
        property bool moved: false
        // True during the opening: cards made later, while scrolling, appear without it.
        property bool opening: true
        property real reveal: 0
        readonly property bool closing: Ui.popup !== "wallpapers"

        onClosingChanged: {
            if (closing) {
                fadeIn.stop();
                fadeOut.start();
            } else {
                fadeOut.stop();
                fadeIn.start();
            }
        }
        readonly property var files: filesOf(tab)
        readonly property int selected: markOf(tab)
        onSelectedChanged: Ui.pickerSelected = selected
        onFilesChanged: Ui.pickerFiles = files.length
        onTabChanged: Ui.pickerTab = tab
        Component.onCompleted: {
            startAtCurrent();
            if (Ui.pickerOpenTab >= 0) {
                placing = true;
                tab = Math.min(1, Ui.pickerOpenTab);
                moved = true;
                placing = false;
                Ui.pickerOpenTab = -1;
            }
            Ui.pickerSelected = selected;
            Ui.pickerFiles = files.length;
            Ui.pickerTab = tab;
            Wallpapers.refresh();
            fadeIn.start();
        }

        SequentialAnimation {
            id: fadeIn

            // The surface reaches the screen a moment after it is created.
            PauseAnimation {
                duration: 40
            }
            NumberAnimation {
                target: root
                property: "reveal"
                to: 1
                duration: 460
                easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            id: fadeOut

            NumberAnimation {
                target: root
                property: "reveal"
                to: 0
                duration: 340
                easing.type: Easing.InOutCubic
            }
            ScriptAction {
                script: Ui.pickerAlive = false
            }
        }

        Timer {
            interval: 900
            running: true
            onTriggered: root.opening = false
        }
        // One frame of the screen, learned as the median time between ticks. Frame times are rounded
        // to it, because the time between two ticks wavers a little while frames still reach the
        // screen evenly, and steps taken from the raw times made the cards move unevenly.
        property var ticks: []
        property real frame: 0

        function frameStep(time) {
            ticks.push(time);
            if (ticks.length > 31)
                ticks.shift();
            if (ticks.length >= 9) {
                const sorted = ticks.slice().sort((a, b) => a - b);
                frame = sorted[sorted.length >> 1];
            }
            if (frame <= 0)
                return Math.min(time, 0.05);
            return Math.min(3, Math.max(1, Math.round(time / frame))) * frame;
        }

        // The row of slices: every one narrow, the chosen one as wide as a screen in small.
        readonly property real sliceHeight: Math.round(Math.min(500, height * 0.46))
        readonly property real skewPx: Math.round(sliceHeight * 0.28)
        readonly property real wide: Math.round(Math.min(sliceHeight * 16 / 9, width * 0.48))
        readonly property real narrow: Math.round(sliceHeight * 0.4)
        readonly property real gap: 16
        // How long a spring takes to settle, following the animation speed of the desktop.
        readonly property real motionMs: 260 / Math.max(0.25, Settings.get("windows.animationSpeed", 1))

        function titleOf(path) {
            return path.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]/g, " ");
        }

        // The picture for a wide slice: the original, or a live wallpaper's first frame.
        function fullOf(path, live) {
            if (!live)
                return "file://" + path;
            return "file://" + Wallpapers.stateDir + "/live-posters/" + Wallpapers.nameOf(path).replace(/\.[^.]+$/, "") + ".jpg";
        }

        function choose(index) {
            moved = true;
            const next = marks.slice();
            next[tab] = Math.max(0, Math.min(files.length - 1, index));
            marks = next;
        }

        Connections {
            target: Ui
            function onPickerTabChanged() {
                root.setTab(Ui.pickerTab);
            }
        }

        Connections {
            target: Wallpapers
            function onCurrentChanged() {
                if (!root.moved)
                    root.startAtCurrent();
            }
        }

        // Starts on the tab of the current wallpaper, at that wallpaper.
        function startAtCurrent() {
            const live = Wallpapers.liveFiles.indexOf(Wallpapers.currentLive);
            const lastLive = Wallpapers.liveFiles.indexOf(Wallpapers.lastLive);
            const image = Wallpapers.imageFiles.indexOf(Wallpapers.currentImage);
            placing = true;
            marks = [Math.max(0, live >= 0 ? live : lastLive), Math.max(0, image)];
            tab = live >= 0 ? 0 : 1;
            placing = false;
        }

        function filesOf(which) {
            return which === 0 ? Wallpapers.liveFiles : Wallpapers.imageFiles;
        }

        function markOf(which) {
            return Math.min(marks[which], Math.max(0, filesOf(which).length - 1));
        }

        function step(by) {
            moved = true;
            const next = marks.slice();
            next[tab] = Math.max(0, Math.min(files.length - 1, selected + by));
            marks = next;
        }

        function setTab(next) {
            if (next === tab)
                return;
            moved = true;
            tab = next;
        }

        function apply(index) {
            const path = files[index];
            if (!path || closing)
                return;
            Wallpapers.chosen(path, tab === 0);
            Ui.popup = "";
            Ui.run("falcon-wallpaper", path);
        }

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "falcon-picker"
        WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
        // While it fades away, clicks already go to what is behind it.
        mask: closing ? noInput : null

        Region {
            id: noInput
        }

        // The blurred current wallpaper and a dim layer fade in together. It is already in memory,
        // and it is blurred once into a small texture.
        Item {
            anchors.fill: parent
            opacity: root.reveal

            Image {
                anchors.fill: parent
                source: Wallpapers.thumbOf(Wallpapers.currentLive || Wallpapers.currentImage)
                sourceSize: Wallpapers.thumbSize
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                layer.enabled: true
                layer.textureSize: Qt.size(480, 270)
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                    saturation: 0.1
                }
            }
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.42)
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.popup = ""
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Ui.popup = ""

            // Sensorli panel mayda qadamlar yuboradi, shuning uchun yig'ib hisoblaymiz.
            WheelHandler {
                property real sum: 0

                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    sum += event.angleDelta.y + event.angleDelta.x;
                    if (Math.abs(sum) < 120)
                        return;
                    root.step(sum > 0 ? -1 : 1);
                    sum = 0;
                }
            }

            Keys.onLeftPressed: root.step(-1)
            Keys.onRightPressed: root.step(1)
            Keys.onTabPressed: root.setTab(1 - root.tab)
            Keys.onBacktabPressed: root.setTab(1 - root.tab)
            Keys.onReturnPressed: root.apply(root.selected)
            Keys.onEnterPressed: root.apply(root.selected)
            // Ctrl+D, by the key's place so the Russian layout works too (D is 40 with the evdev offset).
            Keys.onPressed: event => {
                if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_D || event.nativeScanCode === 40)) {
                    Ui.popup = "wallget";
                    event.accepted = true;
                }
            }

            // One capsule holds both tabs. The colored piece stretches on its way across: its front
            // edge goes ahead and its back edge catches up, and the labels change color exactly where it passes.
            Item {
                id: tabStrip

                readonly property var items: [
                    {
                        label: Tr.t("Live wallpapers"),
                        icon: "play"
                    },
                    {
                        label: Tr.t("Wallpapers"),
                        icon: "wallpaper"
                    }
                ]
                readonly property int pad: 5
                readonly property int gap: 2
                property real width0: 0
                property real width1: 0

                function smooth(value) {
                    return value * value * (3 - 2 * value);
                }

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: stage.top
                anchors.bottomMargin: 30 + (1 - root.reveal) * 18
                width: width0 + width1 + gap + pad * 2
                height: 54
                opacity: root.reveal

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(0, 0, 0, 0.45)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                }

                Row {
                    x: tabStrip.pad
                    y: tabStrip.pad
                    spacing: tabStrip.gap

                    Repeater {
                        model: tabStrip.items

                        delegate: Item {
                            id: tabButton

                            required property var modelData
                            required property int index

                            width: tabFace.implicitWidth + 40
                            height: 44

                            Binding {
                                target: tabStrip
                                property: "width" + tabButton.index
                                value: tabButton.width
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: "white"
                                opacity: tabHover.containsMouse && root.tab !== tabButton.index ? 0.12 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 160
                                    }
                                }
                            }

                            Row {
                                id: tabFace

                                anchors.centerIn: parent
                                spacing: 9

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: tabButton.modelData.icon
                                    size: 17
                                    color: "white"
                                }

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tabButton.modelData.label
                                    color: "white"
                                    size: 15
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: tabHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTab(tabButton.index)
                            }
                        }
                    }
                }

                ClippingRectangle {
                    id: tabLight

                    readonly property real start: tabStrip.pad + (tabStrip.width0 + tabStrip.gap) * tabStrip.smooth(Math.pow(root.travel, 1.7))
                    readonly property real end: tabStrip.pad + tabStrip.width0 + (tabStrip.width1 + tabStrip.gap) * tabStrip.smooth(Math.pow(root.travel, 0.6))

                    x: start
                    y: tabStrip.pad
                    width: end - start
                    height: 44
                    radius: height / 2
                    color: Theme.accent

                    // The same labels in the accent's text color, seen only through this piece.
                    Row {
                        x: tabStrip.pad - tabLight.x
                        spacing: tabStrip.gap

                        Repeater {
                            model: tabStrip.items

                            delegate: Item {
                                id: litTab

                                required property var modelData
                                required property int index

                                width: index === 0 ? tabStrip.width0 : tabStrip.width1
                                height: 44

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 9

                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: litTab.modelData.icon
                                        size: 17
                                        color: Theme.accentText
                                    }

                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: litTab.modelData.label
                                        color: Theme.accentText
                                        size: 15
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Opens the download window, beside the tabs.
            Rectangle {
                anchors.left: tabStrip.right
                anchors.leftMargin: 10
                anchors.verticalCenter: tabStrip.verticalCenter
                width: 54
                height: 54
                radius: 27
                color: Qt.rgba(0, 0, 0, downloadArea.containsMouse ? 0.6 : 0.45)
                opacity: root.reveal
                scale: downloadArea.pressed ? 0.92 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: "save"
                    size: 20
                    color: "white"
                }
                MouseArea {
                    id: downloadArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.popup = "wallget"
                }
            }

            Item {
                id: stage

                anchors.centerIn: parent
                anchors.verticalCenterOffset: -20
                width: parent.width
                height: root.sliceHeight

                // Each tab keeps its own row, so it comes back where it was left. The live one
                // waits off to the left of the plain one, and they cross as one wave.
                Repeater {
                    model: 2

                    delegate: Item {
                        id: deck

                        required property int index
                        readonly property var files: root.filesOf(index)
                        // -1 for the row on the left, 1 for the one on the right.
                        readonly property int side: index === 0 ? -1 : 1
                        readonly property bool gone: Math.abs(root.travel - index) >= 1
                        readonly property int target: root.markOf(index)

                        anchors.fill: parent
                        enabled: root.tab === index
                        // Not "visible": a hidden row would only find its place once it is shown.
                        opacity: gone ? 0 : 1

                        // Slices of the row. Every slice is narrow but the chosen one, which opens wide.
                        // Widths, the camera and the frame each follow their own spring: the widths and
                        // the camera are a little loose, so a step lands with a small wobble, and the
                        // camera's speed curls the slices like pages pulled through the air.
                        property var widths: ({})
                        property var marks: ({})
                        property real camera: 0
                        property real cameraSpeed: 0
                        property bool moving: false
                        // Changes once per frame while anything moves, so the slices read the springs again.
                        property int tick: 0
                        property int hovered: -1

                        readonly property real stride: root.narrow + root.gap
                        readonly property real bend: Math.max(-0.75, Math.min(0.75, cameraSpeed / Math.max(1, root.wide * 3.4)))
                        readonly property int near: Math.round(camera / stride)
                        readonly property int reach: Math.ceil(width / 2 / stride) + 2
                        readonly property var shown: {
                            const list = [];
                            for (let i = Math.max(0, near - reach); i <= Math.min(files.length - 1, near + reach); i++)
                                list.push(i);
                            return list;
                        }

                        function widthOf(i) {
                            const s = widths[i];
                            return s ? s.x : (i === target ? root.wide : root.narrow);
                        }
                        function markOf(i) {
                            const s = marks[i];
                            return s ? Math.max(0, Math.min(1, s.x)) : (i === target ? 1 : 0);
                        }
                        // The middle of slice i along the row: every slice before it is narrow, plus
                        // whatever the moving and the chosen ones add.
                        function centerOf(i) {
                            let c = i * stride + widthOf(i) / 2;
                            for (const key in widths) {
                                const j = Number(key);
                                if (j < i)
                                    c += widths[key].x - root.narrow;
                            }
                            if (target < i && !widths[target])
                                c += root.wide - root.narrow;
                            return c;
                        }
                        function goal() {
                            return target * stride + root.wide / 2;
                        }
                        function spring(from, to, velocity) {
                            return {
                                x: from,
                                v: velocity || 0,
                                to: to
                            };
                        }
                        // Everything at rest at the chosen slice. With `unfold` the chosen slice opens from
                        // narrow, which is how the row arrives on opening.
                        function place(unfold) {
                            const w = {};
                            if (unfold)
                                w[target] = spring(root.narrow, root.wide);
                            widths = w;
                            marks = {};
                            camera = goal() - (unfold ? (root.wide - root.narrow) / 2 : 0);
                            cameraSpeed = 0;
                            moving = unfold;
                            tick++;
                        }
                        function retarget(from, to) {
                            const w = Object.assign({}, widths);
                            w[from] = spring(widthOf(from), root.narrow, w[from] ? w[from].v : 0);
                            w[to] = spring(widthOf(to), root.wide, w[to] ? w[to].v : 0);
                            widths = w;
                            const m = Object.assign({}, marks);
                            m[from] = spring(markOf(from), 0, m[from] ? m[from].v : 0);
                            m[to] = spring(markOf(to), 1, m[to] ? m[to].v : 0);
                            marks = m;
                            moving = true;
                        }

                        property int lastTarget: 0
                        Component.onCompleted: {
                            lastTarget = target;
                            place(root.opening && root.tab === index);
                        }
                        onTargetChanged: {
                            const from = lastTarget;
                            lastTarget = target;
                            // Before the first press the place only follows the lists and the current wallpaper.
                            if (!root.moved) {
                                place(false);
                                return;
                            }
                            retarget(from, target);
                        }
                        onFilesChanged: {
                            if (!root.moved)
                                Qt.callLater(place, false);
                        }
                        // The sizes come from the screen, which is known a moment after the window is made.
                        readonly property real geometry: root.wide + stride
                        onGeometryChanged: {
                            if (!moving)
                                Qt.callLater(place, false);
                        }

                        // One step of a spring that settles in `ms` with damping `zeta`, in small steps,
                        // so a slow frame never throws it off. Returns true while it still moves.
                        function advance(s, dt, ms, zeta, epsilon) {
                            const omega = 6.64 / (ms / 1000);
                            const k = omega * omega;
                            const c = 2 * omega * zeta;
                            let left = Math.min(dt, 0.05);
                            while (left > 0) {
                                const h = Math.min(1 / 240, left);
                                s.v += (-k * (s.x - s.to) - c * s.v) * h;
                                s.x += s.v * h;
                                left -= h;
                            }
                            if (Math.abs(s.x - s.to) < epsilon && Math.abs(s.v) < epsilon * 10) {
                                s.x = s.to;
                                s.v = 0;
                                return false;
                            }
                            return true;
                        }

                        FrameAnimation {
                            running: deck.moving
                            onTriggered: {
                                const dt = root.frameStep(frameTime);
                                let busy = false;
                                const w = deck.widths;
                                for (const key in w) {
                                    if (deck.advance(w[key], dt, root.motionMs, 0.5, 0.05))
                                        busy = true;
                                    else
                                        delete w[key];
                                }
                                const m = deck.marks;
                                for (const key in m) {
                                    if (deck.advance(m[key], dt, root.motionMs, 1, 0.002))
                                        busy = true;
                                    else
                                        delete m[key];
                                }
                                // A var property hands out a copy, so the stepped springs are stored back.
                                deck.widths = w;
                                deck.marks = m;
                                const cam = {
                                    x: deck.camera,
                                    v: deck.cameraSpeed,
                                    to: deck.goal()
                                };
                                if (deck.advance(cam, dt, root.motionMs * 1.15, 0.45, 0.05))
                                    busy = true;
                                deck.camera = cam.x;
                                deck.cameraSpeed = cam.v;
                                deck.tick++;
                                deck.moving = busy;
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: deck.files.length === 0
                            opacity: Math.max(0, 1 - Math.abs(root.travel - deck.index) * 2.5)
                            text: Tr.t("No wallpapers found:") + " " + (deck.index === 0 ? root.liveDir : Settings.wallpaperDir)
                            color: "white"
                            size: 18
                        }

                        // The name of the chosen wallpaper and its place in the list, under the row.
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height + 34
                            spacing: 4
                            visible: deck.files.length > 0
                            opacity: root.reveal * Math.max(0, 1 - Math.abs(root.travel - deck.index) * 2)

                            Label {
                                id: nameLabel

                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.titleOf(deck.files[deck.target] || "")
                                color: "white"
                                size: 18
                                font.weight: Font.Medium

                                // A new name rises in place of the old one.
                                onTextChanged: nameSwap.restart()

                                transform: Translate {
                                    id: nameShift
                                }

                                ParallelAnimation {
                                    id: nameSwap

                                    NumberAnimation {
                                        target: nameShift
                                        property: "y"
                                        from: 8
                                        to: 0
                                        duration: 260
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: nameLabel
                                        property: "opacity"
                                        from: 0.2
                                        to: 1
                                        duration: 260
                                    }
                                }
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (deck.target + 1) + " / " + deck.files.length
                                color: Qt.rgba(1, 1, 1, 0.55)
                                size: 13
                                font.family: Theme.mono
                            }
                        }

                        Repeater {
                            model: ScriptModel {
                                values: deck.shown
                            }

                            delegate: Item {
                                id: card

                                // The place of this card's file in the list.
                                required property int modelData
                                readonly property int slot: modelData
                                readonly property string path: deck.files[slot] || ""
                                readonly property bool chosen: slot === deck.target
                                readonly property real w: {
                                    deck.tick;
                                    return deck.widthOf(slot);
                                }
                                readonly property real mark: {
                                    deck.tick;
                                    return deck.markOf(slot);
                                }
                                readonly property real middle: {
                                    deck.tick;
                                    return deck.width / 2 + deck.centerOf(slot) - deck.camera;
                                }
                                // Slices fade out toward the sides, before their edge reaches the screen's.
                                readonly property real edgeFade: {
                                    const half = deck.width / 2;
                                    const dist = Math.abs(middle - half);
                                    const zeroAt = Math.min(half * 1.2, half - w / 2 - root.skewPx / 2 + 40);
                                    const start = Math.min(root.wide / 2 + 2 * deck.stride, zeroAt);
                                    if (dist <= start)
                                        return 1;
                                    if (dist >= zeroAt)
                                        return 0;
                                    return 1 - (dist - start) / Math.max(1, zeroAt - start);
                                }
                                // Room around the slice for its slant, its curl and its shadow.
                                readonly property real padX: w * 0.3 + root.skewPx / 2 + 30
                                readonly property real padY: 44

                                // Cards rise one after another, from the selected one outwards.
                                property real appear: root.opening ? 0 : 1
                                // How far this card is on its way to its place during a tab change, 1 when there.
                                // The wave reaches cards on the left first.
                                readonly property real arrived: {
                                    const t = root.travel;
                                    if (t === deck.index)
                                        return 1;
                                    if (Math.abs(t - deck.index) >= 1)
                                        return 0;
                                    const place = Math.max(0, Math.min(1, middle / deck.width));
                                    const wave = Math.max(0, Math.min(1, (t - root.waveDelay * place) / (1 - root.waveDelay)));
                                    return deck.index === 1 ? wave : 1 - wave;
                                }
                                // The moving part of the way. It starts late, so at the middle of a change the old
                                // card has already slid off and never lies over the new one in the same place.
                                readonly property real way: Math.max(0, (arrived - 0.5) / 0.5)
                                // Goes a little past its place and settles. Played backward, the same curve makes
                                // a leaving card first lean the other way.
                                readonly property real glide: {
                                    const u = way - 1;
                                    return 1 + 1.9 * u * u * u + 0.9 * u * u;
                                }

                                x: middle - width / 2
                                y: -padY
                                width: w + padX * 2
                                height: root.sliceHeight + padY * 2
                                z: chosen ? 1000 : slot === deck.hovered ? 999 : 100 - Math.abs(slot - deck.target)
                                opacity: Math.min(1, appear) * Math.min(1, way / 0.5) * edgeFade
                                visible: opacity > 0.005

                                Component.onCompleted: {
                                    if (root.opening)
                                        rise.start();
                                }

                                Connections {
                                    target: root
                                    function onClosingChanged() {
                                        if (root.closing) {
                                            rise.stop();
                                            fall.start();
                                        } else {
                                            fall.stop();
                                            rise.start();
                                        }
                                    }
                                }

                                // Closing is the opening in reverse: the outer cards leave first.
                                SequentialAnimation {
                                    id: fall

                                    PauseAnimation {
                                        duration: (6 - Math.min(6, Math.abs(card.slot - deck.target))) * 16
                                    }
                                    NumberAnimation {
                                        target: card
                                        property: "appear"
                                        to: 0
                                        duration: 240
                                        easing.type: Easing.InCubic
                                    }
                                }

                                SequentialAnimation {
                                    id: rise

                                    PauseAnimation {
                                        duration: 40 + Math.min(6, Math.abs(card.slot - deck.target)) * 50
                                    }
                                    NumberAnimation {
                                        target: card
                                        property: "appear"
                                        to: 1
                                        duration: 620
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: [0.22, 1.2, 0.36, 1, 1, 1]
                                    }
                                }

                                transform: [
                                    Rotation {
                                        origin.x: card.width / 2
                                        origin.y: card.height / 2
                                        axis {
                                            x: 0
                                            y: 1
                                            z: 0
                                        }
                                        angle: deck.side * (1 - card.glide) * 38
                                    },
                                    Scale {
                                        origin.x: card.width / 2
                                        origin.y: card.height / 2
                                        xScale: 1 - Math.max(0, 1 - card.glide) * 0.14
                                        yScale: xScale
                                    },
                                    Translate {
                                        x: deck.side * (1 - card.glide) * 560
                                        y: (1 - card.appear) * 90
                                    }
                                ]

                                // The small picture every slice starts with. It is already in memory.
                                Image {
                                    id: thumb

                                    visible: false
                                    source: Wallpapers.thumbOf(card.path)
                                    // The same size as in the service: this finds the picture already in memory.
                                    sourceSize: Wallpapers.thumbSize
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                // The full picture, only for the chosen slice, which is too wide for the small one.
                                // A live wallpaper uses its first frame.
                                Image {
                                    id: full

                                    visible: false
                                    // Kept while the slice closes, so its picture fades back to the small one instead of to black.
                                    source: (card.chosen || card.fullMix > 0) && card.path !== "" ? root.fullOf(card.path, deck.index === 0) : ""
                                    sourceSize.width: 1600
                                    asynchronous: true
                                    cache: false
                                }

                                // The video itself plays in the chosen live slice once the row has stopped there.
                                property bool dwelt: false
                                Timer {
                                    interval: 420
                                    running: card.chosen && deck.index === 0 && !root.closing
                                    onTriggered: card.dwelt = true
                                }
                                onChosenChanged: {
                                    if (!chosen)
                                        dwelt = false;
                                }

                                Loader {
                                    id: clip

                                    active: card.dwelt && card.chosen && !root.closing
                                    visible: false
                                    sourceComponent: Video {
                                        width: 1280
                                        height: full.implicitWidth > 0 ? 1280 * full.implicitHeight / full.implicitWidth : 720
                                        source: "file://" + card.path
                                        muted: true
                                        loops: MediaPlayer.Infinite
                                        autoPlay: true
                                        fillMode: VideoOutput.Stretch
                                        property bool started: position > 0
                                    }
                                }
                                ShaderEffectSource {
                                    id: clipTexture

                                    visible: false
                                    sourceItem: clip.item
                                    hideSource: true
                                    live: true
                                }
                                readonly property bool playing: !!clip.item && clip.item.started

                                property real fullMix: (playing || full.status === Image.Ready) && card.chosen ? 1 : 0
                                Behavior on fullMix {
                                    NumberAnimation {
                                        duration: 260
                                    }
                                }

                                ShaderEffect {
                                    anchors.fill: parent

                                    property variant source: thumb
                                    property variant hiSource: card.playing ? clipTexture : full
                                    property size box: Qt.size(width, height)
                                    property size extent: Qt.size(card.w / 2, root.sliceHeight / 2)
                                    property real skew: root.skewPx
                                    property real radius: 16
                                    property real bend: deck.bend
                                    property real dim: (card.slot === deck.hovered ? 0.12 : 0.42) * (1 - card.mark)
                                    property real frame: 1 + 2 * card.mark
                                    property color frameColor: card.mark > 0.5 ? Theme.accent : "white"
                                    property real frameAlpha: card.mark > 0.5 ? card.mark : Math.max(card.slot === deck.hovered ? 0.55 : 0.16, card.mark)
                                    property real texAspect: thumb.implicitHeight > 0 ? thumb.implicitWidth / thumb.implicitHeight : 0.85
                                    property real hiAspect: full.implicitHeight > 0 ? full.implicitWidth / full.implicitHeight : 16 / 9
                                    property real hiMix: card.fullMix
                                    // The picture slides inside its slice as the row passes, a window onto it.
                                    property real shift: Math.max(-1, Math.min(1, (card.middle - deck.width / 2) / (deck.width / 2))) * -0.6
                                    property real shadow: 0.6 + 0.4 * card.mark
                                    property real glow: card.mark
                                    fragmentShader: Qt.resolvedUrl("../shaders/slice.frag.qsb")
                                }

                                // A small play sign marks live wallpapers, until the video itself plays.
                                Rectangle {
                                    visible: deck.index === 0
                                    opacity: card.playing ? 0 : 0.9 * Math.max(0.35, card.mark)
                                    x: card.padX + card.w / 2 - width / 2 - root.skewPx * 0.12
                                    y: card.padY + root.sliceHeight - 54
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: Qt.rgba(0, 0, 0, 0.5)

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }

                                    Icon {
                                        anchors.centerIn: parent
                                        name: "play"
                                        size: 15
                                        color: "white"
                                    }
                                }

                                // Only the slice itself takes the pointer, not the room around it.
                                MouseArea {
                                    x: card.padX
                                    y: card.padY
                                    width: card.w
                                    height: root.sliceHeight
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: {
                                        if (containsMouse)
                                            deck.hovered = card.slot;
                                        else if (deck.hovered === card.slot)
                                            deck.hovered = -1;
                                    }
                                    // The chosen slice applies, another one is brought to the middle first.
                                    onClicked: card.chosen ? root.apply(card.slot) : root.choose(card.slot)
                                    onDoubleClicked: root.apply(card.slot)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
