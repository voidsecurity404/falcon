import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.services

// What every control center shows, in one place: network, Bluetooth, the quick switches, power
// mode and the tools. Each layout's control page draws these in its own way.
QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wifiNet: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) || null : null
    readonly property bool wired: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool btOn: !!adapter && adapter.enabled
    readonly property var btDevice: btOn ? adapter.devices.values.find(d => d.connected) || null : null
    readonly property string wifiText: wifiNet ? wifiNet.name : !wifiOn ? Tr.t("Off") : wired ? Tr.t("Using cable") : Tr.t("Not connected")
    readonly property string btText: btDevice ? btDevice.name : btOn ? Tr.t("Not connected") : Tr.t("Off")

    readonly property var modes: [
        {
            label: Tr.t("Saver"),
            icon: "battery",
            value: PowerProfile.PowerSaver
        },
        {
            label: Tr.t("Balanced"),
            icon: "sparkle",
            value: PowerProfile.Balanced
        },
        {
            label: Tr.t("Performance"),
            icon: "chip",
            value: PowerProfile.Performance
        }
    ]
    readonly property int mode: modes.findIndex(m => m.value === PowerProfiles.profile)

    function usable(index) {
        return modes[index].value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile;
    }
    function setMode(index) {
        if (index >= 0 && index < modes.length && usable(index))
            PowerProfiles.profile = modes[index].value;
    }

    function toggleWifi() {
        if (Networking.wifiHardwareEnabled)
            Networking.wifiEnabled = !Networking.wifiEnabled;
    }
    function toggleBluetooth() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
    function openWifi() {
        Ui.controlPage = "wifi";
    }
    function openBluetooth() {
        if (adapter)
            Ui.controlPage = "bluetooth";
    }
    function toggleCaffeine() {
        Caffeine.enabled = !Caffeine.enabled;
        Toasts.show(Caffeine.enabled ? Tr.t("Caffeine on") : Tr.t("Caffeine off"), Caffeine.enabled ? Tr.t("The screen stays on and unlocked") : Tr.t("It will lock when idle again"), "coffee");
    }
    function toggleLimit() {
        if (Power.needsSetup)
            Ui.popup = "";
        Power.toggleLimit();
    }

    // The quick switches, in the order every layout shows them.
    readonly property var switches: {
        const list = [
            {
                id: "awake",
                icon: "coffee",
                title: Tr.t("Awake"),
                on: Caffeine.enabled
            },
            {
                id: "night",
                icon: "moon",
                title: Tr.t("Night"),
                on: Night.enabled
            },
            {
                id: "silent",
                icon: "bell",
                title: Tr.t("Silent"),
                on: Toasts.doNotDisturb
            },
            {
                id: "game",
                icon: "game",
                title: Tr.t("Game"),
                on: GameMode.enabled
            }
        ];
        if (Power.chargeSupported)
            list.push({
                id: "limit",
                icon: "charging",
                title: Tr.t("Up to {n}%").replace("{n}", Power.limitValue),
                on: Power.limitOn && !Power.needsSetup
            });
        return list;
    }
    function flip(id) {
        if (id === "awake")
            toggleCaffeine();
        else if (id === "night")
            Night.toggle();
        else if (id === "silent")
            Toasts.doNotDisturb = !Toasts.doNotDisturb;
        else if (id === "game")
            GameMode.toggle();
        else if (id === "limit")
            toggleLimit();
        else if (id === "wifi")
            toggleWifi();
        else if (id === "bluetooth")
            toggleBluetooth();
    }

    // The tools, each a region action or a script.
    readonly property var tools: [
        {
            id: "copy",
            icon: "screenshot",
            title: Tr.t("Screenshot")
        },
        {
            id: "search",
            icon: "google",
            title: Tr.t("Google")
        },
        {
            id: "ocr",
            icon: "ocr",
            title: Tr.t("Text")
        },
        {
            id: "translate",
            icon: "translate",
            title: Tr.t("Translate")
        },
        {
            id: "record",
            icon: "record",
            title: Ui.recordBusy ? Tr.t("Stop") : Tr.t("Record")
        },
        {
            id: "color",
            icon: "color",
            title: Tr.t("Color")
        },
        {
            id: "wallpaper",
            icon: "wallpaper",
            title: Tr.t("Wallpaper")
        },
        {
            id: "focus",
            icon: "focus",
            title: Tr.t("Focus")
        },
        {
            id: "pin",
            icon: "pin",
            title: Tr.t("Pin")
        }
    ]
    function use(id) {
        if (id === "record") {
            if (Ui.recordBusy)
                Ui.toggleRecording();
            else
                Ui.controlPage = "record";
        } else if (id === "color" || id === "focus") {
            Ui.popup = "";
            Ui.run(id === "color" ? "falcon-color" : "falcon-zen");
        } else if (id === "wallpaper") {
            Ui.popup = "wallpapers";
        } else {
            Ui.region(id);
        }
    }
}
