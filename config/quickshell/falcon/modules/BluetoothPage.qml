import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.components
import qs.services

// Bluetooth devices in the control center. Discovery runs only while this page is open.
Column {
    id: root

    signal releaseFocus

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool radioOn: !!adapter && adapter.enabled
    readonly property var devices: {
        if (!radioOn)
            return [];
        // Unnamed new devices show only an address and cannot be told apart.
        const named = d => d.paired || d.connected || !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(d.name);
        return adapter.devices.values.filter(named).sort((a, b) => Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired) || a.name.localeCompare(b.name));
    }

    property var pairing: null
    property string failure: ""

    function choose(device) {
        if (device.connected)
            return;
        failure = "";
        if (device.paired) {
            device.connect();
        } else {
            pairing = device;
            pairTimeout.restart();
            device.pair();
        }
    }

    function setDiscovery(on) {
        if (adapter && adapter.enabled)
            adapter.discovering = on;
    }

    width: parent.width
    spacing: 10

    onRadioOnChanged: setDiscovery(radioOn)
    Component.onCompleted: setDiscovery(true)
    Component.onDestruction: setDiscovery(false)

    Connections {
        target: root.pairing
        ignoreUnknownSignals: true

        function onPairedChanged() {
            if (root.pairing && root.pairing.paired) {
                const device = root.pairing;
                root.pairing = null;
                pairTimeout.stop();
                device.trusted = true;
                device.connect();
            }
        }
    }

    Timer {
        id: pairTimeout

        interval: 30000
        onTriggered: {
            if (root.pairing && !root.pairing.paired) {
                root.pairing.cancelPair();
                root.failure = Tr.t("Could not pair. This device may need a PIN, open Bluetooth devices below");
                root.pairing = null;
            }
        }
    }

    PageHeader {
        title: Tr.t("Bluetooth")
        on: root.radioOn
        switchEnabled: !!root.adapter
        onBack: {
            root.releaseFocus();
            Ui.controlPage = "";
        }
        onToggled: root.adapter.enabled = !root.adapter.enabled
    }

    Label {
        width: parent.width
        visible: root.failure !== ""
        text: root.failure
        color: Theme.error
        size: 12
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Label {
        width: parent.width
        visible: root.devices.length === 0
        text: !root.adapter ? Tr.t("No Bluetooth adapter") : !root.radioOn ? Tr.t("Bluetooth is off") : Tr.t("Searching…")
        color: Theme.muted
        size: 13
    }

    Flickable {
        width: parent.width
        height: Math.min(list.implicitHeight, 340)
        visible: root.devices.length > 0
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list

            width: parent.width
            spacing: 2

            Repeater {
                model: root.devices

                delegate: ChoiceRow {
                    id: row

                    required property var modelData

                    icon: "bluetooth"
                    title: modelData.name
                    current: modelData.connected
                    note: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                    sub: modelData.pairing ? Tr.t("Pairing…") : modelData.state === BluetoothDeviceState.Connecting ? Tr.t("Connecting…") : modelData.connected ? (modelData.batteryAvailable ? Tr.t("Connected") + " · " + Math.round(modelData.battery * 100) + "%" : Tr.t("Connected")) : modelData.paired ? Tr.t("Paired") : ""
                    actions: {
                        const out = [];
                        if (modelData.connected)
                            out.push({
                                label: Tr.t("Disconnect"),
                                run: () => row.modelData.disconnect()
                            });
                        if (modelData.paired)
                            out.push({
                                label: Tr.t("Forget"),
                                run: () => row.modelData.forget()
                            });
                        return out;
                    }
                    onClicked: root.choose(modelData)
                }
            }
        }
    }

    Label {
        text: Tr.t("Bluetooth devices")
        color: toolArea.containsMouse ? Theme.text : Theme.muted
        size: 12

        MouseArea {
            id: toolArea

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Ui.popup = "";
                Quickshell.execDetached(["kitty", "--class", "falcon-tool", "bluetui"]);
            }
        }
    }
}
