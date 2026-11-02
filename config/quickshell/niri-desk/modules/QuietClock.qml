import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Bo'sh workspace'dagi yagona vidjet: karta emas, fon ustidagi matn.
PanelWindow {
    id: root

    property string outputName: ""

    readonly property var workspace: Niri.activeWorkspaceOn(outputName)
    readonly property bool empty: !!workspace && !Niri.hasWindows(workspace.id)

    anchors {
        bottom: true
        left: true
    }
    margins {
        left: 56
        bottom: Settings.bottom ? 76 : 48
    }
    implicitWidth: 640
    implicitHeight: 250
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: empty && !Niri.overview && Settings.get("panel.quietClock", true)
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "niri-desk-clock"

    onVisibleChanged: Sys.quietVisible = visible

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Column {
        anchors.bottom: parent.bottom
        spacing: 8

        Label {
            text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
            color: "white"
            size: 132
            font.weight: Font.Light
            font.letterSpacing: -3
        }
        Label {
            leftPadding: 6
            text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, Tr.language === "ru" ? "dddd, d MMMM" : "dddd, MMMM d"))
            color: Qt.rgba(1, 1, 1, 0.84)
            size: 21
        }
        Label {
            leftPadding: 6
            text: {
                let line = "cpu " + Sys.cpu + "% · ram " + Sys.ramGb.toFixed(1) + "G";
                if (Sys.hasBattery)
                    line += " · " + Tr.t("Battery").toLowerCase() + " " + Sys.batteryPercent + "%";
                return line;
            }
            color: Qt.rgba(1, 1, 1, 0.66)
            font.family: Theme.mono
            size: 14
        }
    }
}
