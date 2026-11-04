import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Butun ekranni egallaydigan shaffof qatlam. Bosishlar faqat mask ichidagi elementlarga tushadi,
// panel ochiq bo'lganda catcher ekranning qolgan qismidagi bosishni ham ushlab panelni yopadi.
PanelWindow {
    id: root

    readonly property bool isFocusedScreen: !!screen && (Niri.focusedOutput === "" || Niri.focusedOutput === screen.name)
    readonly property bool panelHere: Ui.topPanelOpen && isFocusedScreen

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "niri-desk-top"
    WlrLayershell.keyboardFocus: panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Faqat panellar orqasi xiralashadi, qolgan ekran toza qoladi.
    BackgroundEffect.blurRegion: Region {
        Region {
            item: ribbon
            radius: 11
        }
        Region {
            item: status
            radius: 11
        }
        Region {
            item: island.body
            bottomLeftRadius: Settings.bottom ? 0 : island.body.animatedRadius
            bottomRightRadius: Settings.bottom ? 0 : island.body.animatedRadius
            topLeftRadius: Settings.bottom ? island.body.animatedRadius : 0
            topRightRadius: Settings.bottom ? island.body.animatedRadius : 0
        }
    }

    mask: Region {
        Region {
            item: catcher
        }
        Region {
            item: ribbon
        }
        Region {
            item: status
        }
        Region {
            item: island.body
        }
    }

    // Kofe rejimi: fokuslangan ekrandagi shu oyna tizimni uyg'oq ushlab turadi.
    IdleInhibitor {
        enabled: Caffeine.enabled && root.isFocusedScreen
        window: root
    }

    MouseArea {
        id: catcher

        width: root.panelHere ? parent.width : 0
        height: root.panelHere ? parent.height : 0
        onClicked: Ui.popup = ""
    }

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: root.panelHere
        // Esc steps back from a Wi-Fi or Bluetooth list before it closes the panel.
        Keys.onEscapePressed: {
            if (Ui.controlPage !== "")
                Ui.controlPage = "";
            else
                Ui.popup = "";
        }
    }

    Item {
        anchors.fill: parent
        opacity: Ui.zen ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }

        Ribbon {
            id: ribbon

            x: 14
            y: Settings.bottom ? parent.height - height - 10 : 10
            screenInfo: root.screen
        }

        StatusPill {
            id: status

            anchors.right: parent.right
            anchors.rightMargin: 14
            y: Settings.bottom ? parent.height - height - 10 : 10
        }

        Island {
            id: island

            anchors.horizontalCenter: parent.horizontalCenter
            y: Settings.bottom ? parent.height - height : 0
            showDashboard: root.panelHere && Ui.popup === "dashboard"
        }

        TrayMenu {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: Settings.bottom ? parent.height - height - 52 : 52
            shown: root.panelHere && Ui.popup === "tray"
        }

        ClaudePanel {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: Settings.bottom ? parent.height - height - 52 : 52
            shown: root.panelHere && Ui.popup === "claude"
        }

        ControlCenter {
            id: control

            anchors.right: parent.right
            anchors.rightMargin: 14
            y: Settings.bottom ? parent.height - height - 52 : 52
            shown: root.panelHere && Ui.popup === "control"
            onReleaseFocus: keyScope.forceActiveFocus()
        }
    }
}
