import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Qiyshiq kartalar: fon tanlanganda ranglar ham undan olinadi.
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

        readonly property real cardHeight: Math.min(620, height * 0.62)
        readonly property real skew: 0.12

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
            const image = Wallpapers.imageFiles.indexOf(Wallpapers.currentImage);
            placing = true;
            marks = [Math.max(0, live), Math.max(0, image)];
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
            if (!path)
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

            // One capsule holds both tabs. The colored piece stretches on its way across: its front
            // edge goes ahead and its back edge catches up, and the labels change color exactly where it passes.
            Item {
                id: tabStrip

                readonly property var items: [
                    { label: Tr.t("Live wallpapers"), icon: "play" },
                    { label: Tr.t("Wallpapers"), icon: "wallpaper" }
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

            Item {
                id: stage

                anchors.centerIn: parent
                width: parent.width
                height: root.cardHeight

                // Each tab keeps its own carousel, so it comes back where it was left. The live one
                // waits off to the left of the plain one, and they cross as one wave.
                Repeater {
                    model: 2

                    delegate: Item {
                        id: deck

                        required property int index
                        readonly property var files: root.filesOf(index)
                        // -1 for the carousel on the left, 1 for the one on the right.
                        readonly property int side: index === 0 ? -1 : 1
                        readonly property bool gone: Math.abs(root.travel - index) >= 1

                        anchors.fill: parent
                        enabled: root.tab === index
                        // Not "visible": a hidden list would only find its place once it is shown.
                        opacity: gone ? 0 : 1

                        Label {
                            anchors.centerIn: parent
                            visible: deck.files.length === 0
                            opacity: Math.max(0, 1 - Math.abs(root.travel - deck.index) * 2.5)
                            text: Tr.t("No wallpapers found:") + " " + (deck.index === 0 ? root.liveDir : Settings.wallpaperDir)
                            color: "white"
                            size: 18
                        }

                        // Fonlar ko'p: tanlangani doim o'rtada, qolganlari yonga suriladi.
                        // The whole carousel follows one number, the fractional index at the middle of
                        // the screen. Every card's place and width are computed from it, so nothing is
                        // laid out again while it moves, and a press in the middle of a move carries on
                        // from the same speed.
                        Item {
                            id: carousel

                            anchors.fill: parent
                            readonly property int target: root.markOf(deck.index)
                            // Not bound to target: a binding would carry every change across at once.
                            property real pos: 0
                            // Each move eases out from where the carousel is to the new target, so a
                            // press during a move turns it from its current place.
                            property real from: 0
                            property real elapsed: duration
                            readonly property real duration: 0.42
                            readonly property real stepWidth: 328
                            readonly property real activeExtra: 50
                            readonly property int near: Math.round(pos)
                            readonly property int reach: Math.ceil(width / 2 / stepWidth) + 2
                            readonly property var shown: {
                                const list = [];
                                for (let i = Math.max(0, near - reach); i <= Math.min(deck.files.length - 1, near + reach); i++)
                                    list.push(i);
                                return list;
                            }

                            function place() {
                                pos = target;
                                from = target;
                                elapsed = duration;
                            }

                            Component.onCompleted: place()

                            // Before the first press the place only follows the lists and the current wallpaper.
                            onTargetChanged: {
                                if (!root.moved) {
                                    place();
                                    return;
                                }
                                from = pos;
                                elapsed = 0;
                            }

                            FrameAnimation {
                                running: carousel.elapsed < carousel.duration
                                onTriggered: {
                                    carousel.elapsed = Math.min(carousel.duration, carousel.elapsed + root.frameStep(frameTime));
                                    const u = 1 - carousel.elapsed / carousel.duration;
                                    carousel.pos = carousel.from + (carousel.target - carousel.from) * (1 - u * u * u);
                                }
                            }

                            Repeater {
                                model: ScriptModel {
                                    values: carousel.shown
                                }

                                delegate: Item {
                                    id: card

                                    // The place of this card's file in the list.
                                    required property int modelData
                                    readonly property int slot: modelData
                                    readonly property string path: deck.files[slot] || ""
                                    // Distance from the middle of the screen, in cards.
                                    readonly property real offset: slot - carousel.pos
                                    readonly property real nearness: Math.max(0, 1 - Math.abs(offset))

                                    readonly property string title: path.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]/g, " ")
                                    // Cards rise one after another, from the selected one outwards.
                                    property real appear: root.opening ? 0 : 1
                                    // How far this card is on its way to its place during a tab change, 1 when there.
                                    // The wave reaches cards on the left first. At rest nothing here reads the
                                    // carousel's position, so scrolling does not recompute it.
                                    readonly property real arrived: {
                                        const t = root.travel;
                                        if (t === deck.index)
                                            return 1;
                                        if (Math.abs(t - deck.index) >= 1)
                                            return 0;
                                        const place = Math.max(0, Math.min(1, (x + width / 2) / carousel.width));
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

                                    opacity: Math.min(1, appear) * Math.min(1, way / 0.5)

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
                                            duration: (6 - Math.min(6, Math.abs(card.slot - carousel.target))) * 16
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
                                            duration: 40 + Math.min(6, Math.abs(card.slot - carousel.target)) * 55
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

                                    // A later card lies over an earlier one where they meet, as in a list.
                                    z: 1 + nearness + slot / (deck.files.length + 1) * 0.01
                                    // The card at the middle is wider. Its neighbours make room for it on both
                                    // sides, and both change gradually as the carousel moves.
                                    width: 340 + 100 * nearness
                                    height: root.cardHeight
                                    x: carousel.width / 2 + offset * carousel.stepWidth + Math.max(-1, Math.min(1, offset)) * carousel.activeExtra - width / 2

                                    transform: [
                                        Matrix4x4 {
                                            matrix: Qt.matrix4x4(1, -root.skew, 0, root.skew * root.cardHeight / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                        },
                                        Rotation {
                                            origin.x: card.width / 2
                                            origin.y: card.height / 2
                                            axis { x: 0; y: 1; z: 0 }
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

                                    ClippingRectangle {
                                        anchors.fill: parent
                                        radius: 15
                                        color: Theme.pill

                                        Image {
                                            anchors.centerIn: parent
                                            width: parent.width + root.cardHeight * root.skew + 8
                                            height: parent.height
                                            source: Wallpapers.thumbOf(card.path)
                                            // The same size as in the service: this finds the picture already in memory.
                                            sourceSize: Wallpapers.thumbSize
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            transform: Matrix4x4 {
                                                matrix: Qt.matrix4x4(1, root.skew, 0, -root.skew * root.cardHeight / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                            }
                                        }

                                        // Nom yorug' rasm ustida ham o'qilsin.
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 96
                                            gradient: Gradient {
                                                GradientStop {
                                                    position: 0
                                                    color: "transparent"
                                                }
                                                GradientStop {
                                                    position: 1
                                                    color: Qt.rgba(0, 0, 0, 0.62)
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 15
                                        color: "transparent"
                                        // The frame follows the card into the middle instead of jumping to it.
                                        border.width: 1 + 2 * card.nearness
                                        border.color: Qt.rgba(1, 1, 1, Math.max(card.nearness, cardHover.containsMouse ? 0.6 : 0.14))
                                    }

                                    Label {
                                        x: 26
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 18
                                        width: parent.width - 52
                                        text: card.title
                                        color: "white"
                                        size: 17
                                        font.weight: Font.Medium
                                    }

                                    MouseArea {
                                        id: cardHover

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.apply(card.slot)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
