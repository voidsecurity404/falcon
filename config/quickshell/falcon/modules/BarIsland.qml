import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// One glass island of the bar holding the parts BarLayout gives it, in that order. Any part can
// be in any island: Settings → Panel moves them. A thin line separates the parts marked `sep`
// from their neighbours. Parts with nothing to show (no timer, no music) take no room, and an
// island with nothing to show is hidden by TopLayer.
// With `preview` it is the copy in Settings → Panel (BarStudio): its parts take no clicks or
// wheel, a part with nothing to show now is drawn as its faint icon, and pressing a part starts
// dragging it in `studio`.
GlassIsland {
    id: root

    property string zone: "left"
    property var screenInfo: null
    property bool preview: false
    property var studio: null
    readonly property string output: screenInfo ? screenInfo.name : Niri.focusedOutput
    // Long titles are shortened in the preview, so the whole bar fits in the window.
    readonly property int titleCap: preview ? Math.min(60, BarLayout.titleWidth) : BarLayout.titleWidth
    readonly property int mediaCap: preview ? Math.min(56, BarLayout.mediaWidth) : BarLayout.mediaWidth
    readonly property var parts: BarLayout[zone] || []
    // Bumped when a part appears or goes, so the lines between parts follow.
    property int rev: 0
    readonly property bool hasContent: {
        rev;
        for (let i = 0; i < repeater.count; i++) {
            const d = repeater.itemAt(i);
            if (d && d.shown)
                return true;
        }
        return false;
    }

    // The visible part with this objectName inside the island, or null.
    function find(name) {
        const walk = item => {
            if (!item || !item.visible)
                return null;
            if (item.objectName === name)
                return item;
            for (const child of item.children) {
                const hit = walk(child);
                if (hit)
                    return hit;
            }
            return null;
        };
        return walk(root);
    }

    // The slots in order, for the preview's drop place.
    function slots() {
        const out = [];
        for (let i = 0; i < repeater.count; i++) {
            const d = repeater.itemAt(i);
            if (d)
                out.push(d);
        }
        return out;
    }

    function lineBefore(index) {
        rev;
        const me = repeater.itemAt(index);
        if (!me || !me.shown)
            return false;
        for (let j = index - 1; j >= 0; j--) {
            const d = repeater.itemAt(j);
            if (d && d.shown)
                return me.sep || d.sep;
        }
        return false;
    }

    spacing: BarLayout.spacing
    wheelEnabled: !preview
    minWidth: preview && parts.length === 0 ? 150 : 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Repeater {
        id: repeater

        model: root.parts

        delegate: Item {
            id: slot

            required property string modelData
            required property int index
            readonly property bool shown: loader.item ? loader.item.shown : false
            readonly property bool sep: !!(BarLayout.byId[modelData] && BarLayout.byId[modelData].sep)
            readonly property bool drawn: shown || root.preview

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            width: slotRow.implicitWidth
            height: slotRow.implicitHeight
            visible: drawn
            opacity: root.studio && root.studio.dragId === modelData ? 0.3 : 1
            onShownChanged: root.rev++
            Component.onCompleted: root.rev++
            Component.onDestruction: root.rev++

            Row {
                id: slotRow

                spacing: root.spacing

                BarSeparator {
                    visible: root.lineBefore(slot.index)
                    height: Math.round(BarLayout.buttonHeight * 0.6)
                }
                Loader {
                    id: loader

                    anchors.verticalCenter: parent.verticalCenter
                    visible: slot.shown
                    sourceComponent: ({
                            menu: menuPart,
                            workspaces: workspacesPart,
                            window: windowPart,
                            resources: resourcesPart,
                            record: recordPart,
                            timer: timerPart,
                            clock: clockPart,
                            weather: weatherPart,
                            media: mediaPart,
                            tools: toolsPart,
                            tray: trayPart,
                            claude: claudePart,
                            privacy: privacyPart,
                            updates: updatesPart,
                            lang: langPart,
                            phone: phonePart,
                            status: statusPart,
                            bell: bellPart,
                            power: powerPart,
                            network: networkPart
                        })[slot.modelData] || (NetTools.has(slot.modelData) ? netPart : null)
                    onLoaded: {
                        if (item.netTool !== undefined)
                            item.netTool = slot.modelData;
                    }
                }
                // In the preview, a part with nothing to show now is still there to be moved.
                BarButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.preview && !slot.shown
                    icon: (BarLayout.byId[slot.modelData] || {}).icon || "panel"
                    opacity: 0.45
                }
            }

            // In the preview the part is only moved: this takes every press before the part sees it.
            MouseArea {
                id: grab

                property point start: Qt.point(0, 0)

                anchors.fill: parent
                anchors.margins: -Math.round(root.spacing / 2)
                visible: root.preview && !!root.studio
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: root.studio && root.studio.dragId !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onContainsMouseChanged: {
                    if (containsMouse)
                        root.studio.hover(slot.modelData, slot);
                    else
                        root.studio.unhover(slot.modelData);
                }
                onPressed: mouse => start = Qt.point(mouse.x, mouse.y)
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    if (root.studio.dragId === "" && Math.hypot(mouse.x - start.x, mouse.y - start.y) > 5)
                        root.studio.begin(slot.modelData);
                    if (root.studio.dragId === slot.modelData)
                        root.studio.moveTo(mapToItem(root.studio, mouse.x, mouse.y));
                }
                onReleased: {
                    if (root.studio.dragId === slot.modelData)
                        root.studio.drop();
                }
                onCanceled: root.studio.cancel()
            }
        }
    }

    // An empty island in the preview says where parts may go.
    Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.preview && root.parts.length === 0
        text: Tr.t("Drop parts here")
        size: 12
        color: Qt.alpha(Theme.text, 0.5)
    }

    Component {
        id: menuPart

        BarButton {
            readonly property bool shown: true

            objectName: "menu"
            icon: "sparkle"
            lit: Ui.popup === "menu"
            onClicked: Ui.togglePopup("menu")
        }
    }

    // A workspace with windows is a bright dot, an empty one a faint dot. In the "pills" style the
    // current one stretches into a pill with its number, "dots" leaves the number out, "numbers"
    // shows every number in a circle.
    Component {
        id: workspacesPart

        Row {
            id: dots

            readonly property bool shown: true
            readonly property bool hideEmpty: Settings.get("panel.hideEmpty", false)
            readonly property string style: BarLayout.workspaceStyle

            objectName: "workspaces"
            spacing: 0

            // The model holds plain workspace ids, so a switch keeps every chip alive and its
            // width, size and color animate; a list of objects rebuilt the chips on each switch.
            Repeater {
                model: ScriptModel {
                    values: Niri.workspacesOn(root.output).map(w => w.id)
                }

                delegate: Item {
                    id: chip

                    required property var modelData
                    readonly property var ws: Niri.workspaces.find(w => w.id === chip.modelData) || ({ idx: 0, is_active: false, is_urgent: false })

                    readonly property bool active: ws.is_active
                    readonly property bool occupied: Niri.hasWindows(chip.modelData)
                    readonly property bool numbers: dots.style === "numbers"
                    readonly property int box: Math.max(18, BarLayout.buttonHeight - 8)

                    objectName: "dot" + ws.idx
                    visible: active || occupied || !dots.hideEmpty
                    // Follows the dot's own animated width, so the pill never overlaps its neighbour.
                    width: visible ? dot.width + (numbers ? 4 : 6) : 0
                    height: BarLayout.buttonHeight

                    Rectangle {
                        id: dot

                        anchors.centerIn: parent
                        width: chip.numbers ? chip.box : chip.active ? (dots.style === "dots" ? 20 : 28) : 9
                        height: chip.numbers ? chip.box : chip.active ? (dots.style === "dots" ? 9 : 18) : 9
                        radius: height / 2
                        color: chip.active ? Theme.accent : chip.ws.is_urgent ? Theme.error : chip.numbers ? Qt.alpha(Theme.text, area.containsMouse ? 0.12 : chip.occupied ? 0.07 : 0) : Qt.alpha(Theme.text, chip.occupied ? (area.containsMouse ? 0.85 : 0.62) : (area.containsMouse ? 0.4 : 0.2))

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on height {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            text: chip.ws.idx
                            font.family: Theme.mono
                            size: 11
                            font.weight: Font.Bold
                            color: chip.active || chip.ws.is_urgent ? Theme.accentText : Qt.alpha(Theme.text, chip.occupied ? 0.9 : 0.4)
                            opacity: chip.numbers || (chip.active && dots.style === "pills") ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sticky.active ? Sticky.switchTo(chip.ws.idx) : Niri.focusWorkspace(chip.ws.idx)
                    }
                }
            }
        }
    }

    // The focused window: its app's icon and its title.
    Component {
        id: windowPart

        Row {
            readonly property var focused: {
                const w = Niri.windows[Niri.focusedWindowId];
                return w && w.app_id !== "org.quickshell" ? w : null;
            }
            readonly property var entry: focused ? DesktopEntries.heuristicLookup(focused.app_id) : null
            readonly property bool shown: !!focused

            objectName: "window"
            spacing: 8

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 18
                source: parent.entry ? Quickshell.iconPath(parent.entry.icon, true) : parent.focused ? Quickshell.iconPath(parent.focused.app_id, true) : ""
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.titleCap)
                text: parent.focused ? parent.focused.title || parent.focused.app_id : ""
                elide: Text.ElideRight
                size: 13
                font.weight: Font.Medium
                color: Qt.alpha(Theme.text, 0.88)
            }
            Item {
                width: 2
                height: 1
            }
        }
    }

    // Processor, memory and temperature rings. They open the system menu.
    Component {
        id: resourcesPart

        BarButton {
            readonly property bool shown: true

            objectName: "rings"
            padding: 3
            lit: Ui.popup === "system"
            onClicked: Ui.togglePopup("system")

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                RingMeter {
                    icon: "chip"
                    value: Sys.cpu / 100
                }
                RingMeter {
                    icon: "memory"
                    value: Sys.ram / 100
                }
                RingMeter {
                    icon: "thermo"
                    value: Sys.temperature / 100
                }
            }
        }
    }

    // Recording: a red dot and the time, or the seconds before a delayed one starts. A click stops it.
    Component {
        id: recordPart

        Row {
            readonly property bool shown: Ui.recordBusy

            objectName: "record"
            spacing: 7

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: Theme.error

                SequentialAnimation on opacity {
                    running: Ui.recordBusy
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running)
                            parent.opacity = 1;
                    }
                    NumberAnimation {
                        to: 0.3
                        duration: 600
                    }
                    NumberAnimation {
                        to: 1
                        duration: 600
                    }
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Ui.recording ? Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60) : String(Ui.recordCountdown)
                color: Theme.error
                size: 14
                font.weight: Font.Medium

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.toggleRecording()
                }
            }
        }
    }

    // The timer. A click pauses it, a right click stops it.
    Component {
        id: timerPart

        BarButton {
            readonly property bool shown: Countdown.active

            objectName: "timer"
            padding: 8
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    Countdown.stop();
                else
                    Countdown.togglePause();
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                opacity: Countdown.paused ? 0.5 : 1

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Countdown.icon
                    color: Countdown.left <= 10 && !Countdown.paused ? Theme.error : Theme.accent
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Countdown.text
                    size: 13
                    font.weight: Font.Medium
                }
            }
        }
    }

    // The clock, with the date beside it. Opens the calendar.
    Component {
        id: clockPart

        BarButton {
            id: clockButton

            readonly property bool shown: true
            readonly property bool showSeconds: Settings.get("panel.clockSeconds", false)
            readonly property bool showDate: Settings.get("panel.clockDate", false)
            readonly property bool clock24: Settings.get("panel.clock24", true)

            objectName: "clock"
            padding: 8
            lit: Ui.popup === "calendar"
            onClicked: Ui.togglePopup("calendar")

            SystemClock {
                id: clock

                precision: clockButton.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const hours = clockButton.clock24 ? clock.hours : clock.hours % 12 || 12;
                        return Ui.pad(hours) + ":" + Ui.pad(clock.minutes) + (clockButton.showSeconds ? ":" + Ui.pad(clock.seconds) : "") + (clockButton.clock24 ? "" : clock.hours < 12 ? " AM" : " PM");
                    }
                    font.family: Theme.display
                    size: 15
                    font.weight: Font.DemiBold
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: clockButton.showDate
                    text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "ddd, d MMM"))
                    size: 12
                    color: Theme.muted
                }
            }
        }
    }

    // The weather now. Opens the calendar, which has the days ahead.
    Component {
        id: weatherPart

        BarButton {
            readonly property bool shown: Weather.hasData

            objectName: "weather"
            padding: 8
            lit: Ui.popup === "calendar"
            onClicked: Ui.togglePopup("calendar")

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon(Weather.code, Weather.isDay)
                    size: 16
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.temperature + "°"
                    size: 13
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // The music: play or pause, the title and how far it has played. The title opens the player.
    Component {
        id: mediaPart

        Row {
            readonly property bool shown: !!Media.player

            spacing: 9

            Rectangle {
                objectName: "play"
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: 12
                color: playArea.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent

                Icon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: Media.player && Media.player.isPlaying ? 0 : 1
                    name: Media.player && Media.player.isPlaying ? "pause" : "play"
                    filled: true
                    size: 12
                    color: Theme.accentText
                }
                MouseArea {
                    id: playArea

                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Media.player && Media.player.canTogglePlaying)
                            Media.player.togglePlaying();
                    }
                }
            }
            Item {
                objectName: "media"
                anchors.verticalCenter: parent.verticalCenter
                width: root.mediaCap
                height: 30

                Label {
                    y: 4
                    width: parent.width
                    text: Media.title + (Media.player && Media.player.trackArtist ? " — " + Media.player.trackArtist : "")
                    elide: Text.ElideRight
                    size: 12
                    font.weight: Font.Medium
                    color: mediaArea.containsMouse || Ui.popup === "player" ? Theme.accent : Theme.text
                }
                // No animation on the width: an animated bar repainted the whole layer every frame.
                Rectangle {
                    y: 22
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Qt.alpha(Theme.text, 0.18)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Media.progress))
                        height: parent.height
                        radius: 1.5
                        color: Theme.accent
                    }
                }
                MouseArea {
                    id: mediaArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.togglePopup("player")
                }
            }
        }
    }

    Component {
        id: toolsPart

        Row {
            readonly property bool shown: true

            spacing: root.spacing

            BarButton {
                objectName: "shot"
                icon: "screenshot"
                onClicked: Ui.region("copy")
            }
            BarButton {
                objectName: "color"
                icon: "color"
                onClicked: Ui.run("falcon-color")
            }
        }
    }

    // Tray: a left click opens the app, a right click its menu.
    Component {
        id: trayPart

        Row {
            readonly property bool shown: SystemTray.items.values.length > 0

            objectName: "trayRow"
            spacing: 0

            Repeater {
                model: SystemTray.items

                delegate: BarButton {
                    id: trayItem

                    required property var modelData

                    objectName: "tray"
                    padding: 6
                    lit: Ui.popup === "tray" && Ui.trayItem === modelData
                    onClicked: mouse => {
                        const item = trayItem.modelData;
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (mouse.button === Qt.LeftButton && !item.onlyMenu) {
                            item.activate();
                        } else if (item.hasMenu) {
                            Ui.trayItem = item;
                            Ui.popup = "tray";
                        }
                    }

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16
                        source: trayItem.modelData.icon
                    }
                }
            }
        }
    }

    Component {
        id: claudePart

        BarButton {
            readonly property bool shown: true

            objectName: "claude"
            icon: "claude"
            lit: Ui.popup === "claude"
            color: Qt.alpha(Theme.text, ClaudeUsage.hasData ? 1 : 0.45)
            onClicked: Ui.togglePopup("claude")
        }
    }

    // Who is using the microphone or the camera. A click names the apps.
    Component {
        id: privacyPart

        BarButton {
            readonly property bool shown: Privacy.mic.length > 0 || Privacy.camera.length > 0

            objectName: "privacy"
            onClicked: Privacy.tell()

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Icon {
                    visible: Privacy.mic.length > 0
                    name: Audio.micMuted ? "micOff" : "mic"
                    size: 16
                    color: Audio.micMuted ? Theme.muted : Theme.error
                }
                Icon {
                    visible: Privacy.camera.length > 0
                    name: "camera"
                    size: 16
                    color: Theme.error
                }
            }
        }
    }

    // Waiting system updates. Hidden when there are none.
    Component {
        id: updatesPart

        BarButton {
            readonly property bool shown: Updates.enabled && (Updates.count > 0 || Updates.rebootNeeded)

            objectName: "updates"
            onClicked: Updates.clicked()

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "update"
                    size: 16
                    color: Updates.rebootNeeded && Updates.count === 0 ? Theme.accent : Theme.text
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Updates.count > 0
                    text: Updates.count
                    size: 13
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // Keyboard layout, a click switches it.
    Component {
        id: langPart

        BarButton {
            readonly property bool shown: true

            objectName: "lang"
            onClicked: Niri.nextLayout()

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Niri.layoutLabel
                size: 13
                font.weight: Font.DemiBold
            }
        }
    }

    // Status: network, Bluetooth, volume and battery. A click opens the control center.
    Component {
        id: statusPart

        BarButton {
            id: status

            readonly property bool shown: true
            readonly property var netDevices: Networking.devices.values
            readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
            readonly property bool wifiUp: netDevices.some(d => d.type === DeviceType.Wifi && d.connected)
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property bool btOn: !!adapter && adapter.enabled
            readonly property bool btLinked: btOn && adapter.devices.values.some(d => d.connected)
            readonly property bool showNetwork: Settings.get("panel.wifi", true)
            readonly property bool showVolume: Audio.available && Settings.get("panel.volume", true)
            readonly property bool showBattery: Sys.hasBattery && Settings.get("panel.battery", true)

            objectName: "status"
            lit: Ui.popup === "control"
            onClicked: Ui.togglePopup("control")

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: status.showNetwork
                    name: status.wiredUp ? "ethernet" : (status.wifiUp || Networking.wifiEnabled ? "wifi" : "wifiOff")
                    size: 16
                    opacity: status.wiredUp || status.wifiUp ? 1 : 0.4
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: status.showNetwork && status.btOn
                    name: "bluetooth"
                    size: 16
                    opacity: status.btLinked ? 1 : 0.45
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: status.showVolume
                    spacing: 4

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Audio.muted ? "mute" : "volume"
                        size: 16
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Audio.percent
                        size: 12
                        font.weight: Font.DemiBold
                        font.features: {
                            "tnum": 1
                        }
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: status.showBattery
                    spacing: 5

                    BarBattery {
                        anchors.verticalCenter: parent.verticalCenter
                        value: Sys.batteryPercent / 100
                        charging: Sys.charging
                        color: Sys.batteryPercent <= 15 && !Sys.charging ? Theme.error : Theme.text
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Sys.batteryPercent + "%"
                        size: 12
                        font.weight: Font.DemiBold
                        color: Sys.batteryPercent <= 15 && !Sys.charging ? Theme.error : Theme.text
                        font.features: {
                            "tnum": 1
                        }
                    }
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Caffeine.enabled
                    name: "coffee"
                    size: 16
                    color: Theme.accent
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: GameMode.enabled
                    name: "game"
                    size: 16
                    color: Theme.accent
                }
                // A device with nothing to show still gets something to press.
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !status.showNetwork && !status.showVolume && !status.showBattery && !Caffeine.enabled && !GameMode.enabled
                    name: "sun"
                    size: 16
                }
            }
        }
    }

    // The phone through KDE Connect: a click opens the phone window. A dot shows it is connected,
    // and the number of the phone's notifications not yet seen rides on it.
    // A network or security reading (NetTools): its icon colored by the reading's state, and a
    // short value beside it. A click opens its menu under it.
    Component {
        id: netPart

        BarButton {
            id: netButton

            property string netTool: ""
            readonly property bool shown: true
            readonly property string badge: NetTools.badgeOf(netTool)

            objectName: netTool
            lit: NetTools.menuOpen && NetTools.origin === netTool
            onClicked: NetTools.click(netTool)
            onHoveredChanged: {
                if (root.preview || netTool === "")
                    return;
                if (hovered)
                    NetTools.hoverEnter(netTool);
                else
                    NetTools.hoverExit(netTool);
            }
            onNetToolChanged: {
                if (netTool !== "" && !root.preview)
                    NetTools.watch(netTool, 1);
            }
            Component.onDestruction: {
                if (netTool !== "" && !root.preview)
                    NetTools.watch(netTool, -1);
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: NetTools.iconOf(netButton.netTool)
                    size: 16
                    color: NetTools.colorOf(netButton.netTool)
                    opacity: NetTools.busy[netButton.netTool] && !NetTools.data[netButton.netTool] ? 0.5 : 1
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: netButton.badge !== ""
                    // Traffic changes every 2 s: a steady width keeps the bar from shifting.
                    width: netButton.netTool === "speed" ? Math.max(implicitWidth, 86) : implicitWidth
                    text: netButton.badge
                    size: 11
                    font.family: Theme.mono
                    font.weight: Font.DemiBold
                    color: NetTools.colorOf(netButton.netTool)
                }
            }
        }
    }

    // All network and security readings behind one button: a click drops the hub, a page of
    // tiles like the control center's; pointing only shows its name. A dot warns when ARP, the firewall, the latency, the
    // Wi-Fi or the logins found something.
    Component {
        id: networkPart

        BarButton {
            id: hubButton

            readonly property bool shown: true

            objectName: "network"
            icon: "radar"
            lit: NetTools.menuOpen && NetTools.origin === "network"
            onClicked: NetTools.click("network")
            onHoveredChanged: {
                if (root.preview)
                    return;
                if (hovered)
                    NetTools.hoverEnter("network");
                else
                    NetTools.hoverExit("network");
            }
            Component.onCompleted: {
                if (!root.preview)
                    NetTools.watchHub(1);
            }
            Component.onDestruction: {
                if (!root.preview)
                    NetTools.watchHub(-1);
            }

            Rectangle {
                parent: hubButton
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 5
                anchors.topMargin: 5
                visible: NetTools.alert !== ""
                width: 7
                height: 7
                radius: 3.5
                color: NetTools.stateColor(NetTools.alert)
            }
        }
    }

    Component {
        id: phonePart

        BarButton {
            id: phoneButton

            readonly property bool shown: Phone.installed

            objectName: "phone"
            icon: "phone"
            lit: Ui.popup === "phone"
            color: Qt.alpha(Theme.text, Phone.connected ? 1 : 0.5)
            onClicked: Ui.togglePopup("phone")

            // On the button itself: inside its content it would change the button's width.
            // A count starts at the icon's middle and grows outward, so it never hides the icon.
            Rectangle {
                parent: phoneButton
                x: Phone.unread > 0 ? Math.round(phoneButton.width * 0.5) : phoneButton.width - width - 5
                y: Phone.unread > 0 ? 0 : 5
                visible: Phone.connected
                width: Phone.unread > 0 ? Math.max(13, phoneCount.implicitWidth + 6) : 6
                height: Phone.unread > 0 ? 13 : 6
                radius: height / 2
                color: Phone.unread > 0 ? Theme.accent : Theme.good

                Label {
                    id: phoneCount

                    anchors.centerIn: parent
                    visible: Phone.unread > 0
                    text: Phone.unread > 9 ? "9+" : Phone.unread
                    size: 9
                    font.weight: Font.Bold
                    color: Theme.accentText
                }
            }
        }
    }

    // Notifications: the badge counts the unread ones, a click opens their menu. It swings when a
    // notification card flies into it.
    Component {
        id: bellPart

        BarButton {
            id: bell

            readonly property bool shown: true

            objectName: "bell"
            icon: "bell"
            lit: Ui.popup === "notifications"
            transformOrigin: Item.Top
            onClicked: {
                // It opens on the tab that has something new.
                if (Ui.popup !== "notifications") {
                    if (Toasts.unread === 0 && Phone.unread > 0)
                        Ui.notificationsTab = 1;
                    else if (Phone.unread === 0 && Toasts.unread > 0)
                        Ui.notificationsTab = 0;
                }
                Ui.togglePopup("notifications");
            }

            Connections {
                target: Ui
                function onBellRingsChanged() {
                    ring.restart();
                }
            }
            SequentialAnimation {
                id: ring

                NumberAnimation {
                    target: bell
                    property: "scale"
                    to: 1.25
                    duration: 90
                    easing.type: Easing.OutCubic
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: bell
                        property: "scale"
                        to: 1
                        duration: 420
                        easing.type: Easing.OutBack
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: bell
                            property: "rotation"
                            to: 18
                            duration: 80
                        }
                        NumberAnimation {
                            target: bell
                            property: "rotation"
                            to: -14
                            duration: 110
                        }
                        NumberAnimation {
                            target: bell
                            property: "rotation"
                            to: 8
                            duration: 100
                        }
                        NumberAnimation {
                            target: bell
                            property: "rotation"
                            to: 0
                            duration: 120
                        }
                    }
                }
            }

            // This computer's unread ones and the phone's together.
            Rectangle {
                readonly property int count: Toasts.unread + Phone.unread

                visible: count > 0
                // Grows to the right from the icon's middle: a two-digit count used to cover the bell.
                x: Math.round(bell.width * 0.5)
                y: 0
                width: Math.max(13, badgeLabel.implicitWidth + 6)
                height: 13
                radius: 6.5
                color: Theme.error

                Label {
                    id: badgeLabel

                    anchors.centerIn: parent
                    text: parent.count > 99 ? "99+" : parent.count
                    size: 9
                    font.weight: Font.Bold
                    color: Theme.pill
                }
            }
        }
    }

    Component {
        id: powerPart

        BarButton {
            readonly property bool shown: true

            objectName: "power"
            icon: "power"
            color: Session.red
            lit: Ui.popup === "power"
            onClicked: Ui.togglePopup("power")
        }
    }
}
