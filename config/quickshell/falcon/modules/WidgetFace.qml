import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.components
import qs.services

// What you see: widgets and the music waves in niri's backdrop, which never slides, so they stay still
// while workspaces switch. This layer takes no input, DesktopWidgets holds the clickable copies.
PanelWindow {
    id: root

    property string outputName: ""

    readonly property var workspace: Niri.activeWorkspaceOn(outputName)
    readonly property bool wanted: Widgets.enabled && Widgets.loaded && (!Widgets.firstOnly || (!!workspace && workspace.idx === 1))
    // Only a window nothing shows through hides the desktop.
    readonly property bool covered: Niri.desktopHiddenOn(outputName, width, height)
    // Caffeine counts as active by itself: this monitor still reports idle with its inhibitor held.
    readonly property bool seen: wanted && !covered && (Caffeine.enabled || !idle.isIdle)
    readonly property bool contentOn: seen || keepAlive.running
    // After this long without input the session is locked, so nothing here can be seen.
    readonly property int lockAfter: Settings.get(UPower.onBattery ? "idle.battery.lock" : "idle.lock", 300)
    readonly property bool wavesSeen: Widgets.wavesEnabled && !covered && !Niri.overview && (Caffeine.enabled || !lockIdle.isIdle)
    readonly property bool behindGlass: !covered && Niri.coveredOn(outputName, width, height)
    readonly property int topInset: Widgets.topInset
    readonly property int bottomInset: Widgets.bottomInset

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: (wanted || Widgets.wavesEnabled) && !Widgets.restacking
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "falcon-widgets-face"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onSeenChanged: {
        if (seen)
            keepAlive.stop();
        else
            keepAlive.restart();
    }
    onContentOnChanged: Widgets.setLive(outputName, contentOn)
    onWavesSeenChanged: Spectrum.setWatching(outputName, wavesSeen)
    Component.onCompleted: {
        Widgets.setLive(outputName, contentOn);
        Spectrum.setWatching(outputName, wavesSeen);
    }
    Component.onDestruction: {
        Widgets.setLive(outputName, false);
        Spectrum.setWatching(outputName, false);
    }

    // Ko'rinmay qolgach yarim daqiqa kutadi: oyna bir lahzaga yopsa, vidjet qayta qurilmaydi.
    Timer {
        id: keepAlive

        interval: 30000
    }
    IdleMonitor {
        id: idle

        timeout: 300
        respectInhibitors: true
    }
    IdleMonitor {
        id: lockIdle

        enabled: root.lockAfter > 0
        timeout: Math.max(root.lockAfter, 1)
        respectInhibitors: true
    }

    // The overview shows the backdrop around the workspaces, so widgets leave it there. The blur must go too.
    BackgroundEffect.blurRegion: Region {
        // In edit mode the clickable copies draw the glass; a face's blur left behind would stay at the
        // old place while a widget is dragged.
        regions: Niri.overview || !root.wanted || Widgets.editMode ? [] : blurs.instances
    }
    Variants {
        id: blurs

        model: Widgets.ids.filter(id => {
            const w = Widgets.get(id);
            const i = w ? Widgets.info(w.type) : null;
            return !!i && i.plate;
        })

        Region {
            required property string modelData

            readonly property int index: Widgets.ids.indexOf(modelData)

            item: hosts.count > index && index >= 0 ? hosts.itemAt(index) : null
            radius: item ? 22 * item.factor : 22
        }
    }

    // The floor of the desktop, under the widgets. It has no place of its own to change.
    SpectrumBars {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: Widgets.wavesHeight
        active: root.wavesSeen
        style: Settings.get("waves.style", "bars")
        color: Settings.get("waves.fromCover", false) && !!Media.player ? Media.artAccent : (Settings.get("waves.color", "") || Theme.accent)
        // Blur behind a see-through window spreads the light thin, so it takes more of it.
        topAlpha: root.behindGlass ? 1 : Settings.get("waves.opacity", 0.8)
        bottomAlpha: root.behindGlass ? Settings.get("waves.opacity", 0.8) : topAlpha * 0.1
        bars: ({ thick: 40, medium: 72, thin: 120 })[Settings.get("waves.thickness", "medium")] || 72
        mirrored: Settings.get("waves.mirror", true)
        gain: Settings.get("waves.gain", 1)
        smoothing: Settings.get("waves.smoothing", 70)
        opacity: Niri.overview ? 0 : 1
        visible: Widgets.wavesEnabled && !field.drawsIt && opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
    }
    // The looks drawn by a shader: ribbon and segments in the same strip, aura along all the
    // edges of the screen, ring and orb in the middle, sized by the height setting.
    SpectrumField {
        id: field

        readonly property bool drawsIt: looks.indexOf(Widgets.wavesStyle) >= 0
        readonly property bool strip: Widgets.wavesStyle === "ribbon" || Widgets.wavesStyle === "segments"
        readonly property bool round: Widgets.wavesStyle === "ring" || Widgets.wavesStyle === "orb"
        readonly property real side: Math.min(parent.width, parent.height) * Math.min(0.9, 0.35 + Widgets.wavesHeight / 600)

        x: round ? (parent.width - side) / 2 : 0
        y: strip ? parent.height - height : round ? (parent.height - side) / 2 : 0
        width: round ? side : parent.width
        height: strip ? Widgets.wavesHeight : round ? side : parent.height
        active: root.wavesSeen && drawsIt
        style: Widgets.wavesStyle
        color: Settings.get("waves.fromCover", false) && !!Media.player ? Media.artAccent : (Settings.get("waves.color", "") || Theme.accent)
        alpha: root.behindGlass ? 1 : Settings.get("waves.opacity", 0.8)
        bars: Widgets.wavesStyle === "ring" ? 64 : (({ thick: 40, medium: 72, thin: 120 })[Settings.get("waves.thickness", "medium")] || 72)
        mirrored: Settings.get("waves.mirror", true)
        gain: Settings.get("waves.gain", 1)
        smoothing: Settings.get("waves.smoothing", 70)
        opacity: Niri.overview ? 0 : 1
        visible: Widgets.wavesEnabled && drawsIt && opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.wanted
        opacity: Widgets.editMode || Niri.overview ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }

        Repeater {
            id: hosts

            model: Widgets.ids

            delegate: WidgetHost {
                required property string modelData

                widgetId: modelData
                areaWidth: root.width - 32
                areaHeight: root.height - root.bottomInset
                topInset: root.topInset
                role: "face"
                contentOn: root.contentOn
            }
        }
    }
}
