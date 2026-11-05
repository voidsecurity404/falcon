import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// What you see: widgets in niri's backdrop, which never slides, so they stay still while workspaces
// switch. This layer takes no input, DesktopWidgets holds the clickable copies.
PanelWindow {
    id: root

    property string outputName: ""

    readonly property var workspace: Niri.activeWorkspaceOn(outputName)
    readonly property bool wanted: Widgets.enabled && Widgets.loaded && (!Widgets.firstOnly || (!!workspace && workspace.idx === 1))
    readonly property bool covered: Niri.coveredOn(outputName, width, height)
    readonly property bool seen: wanted && !covered && !idle.isIdle
    readonly property bool contentOn: seen || keepAlive.running
    readonly property int topInset: Settings.bottom ? 16 : 56
    readonly property int bottomInset: Settings.bottom ? 56 : 16

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: wanted && !Widgets.restacking
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "niri-desk-widgets-face"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onSeenChanged: {
        if (seen)
            keepAlive.stop();
        else
            keepAlive.restart();
    }
    onContentOnChanged: Widgets.setLive(outputName, contentOn)
    Component.onCompleted: Widgets.setLive(outputName, contentOn)
    Component.onDestruction: Widgets.setLive(outputName, false)

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

    // The overview shows the backdrop around the workspaces, so widgets leave it there. The blur must go too.
    BackgroundEffect.blurRegion: Region {
        regions: Niri.overview ? [] : blurs.instances
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
            radius: 22
        }
    }

    Item {
        anchors.fill: parent
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
