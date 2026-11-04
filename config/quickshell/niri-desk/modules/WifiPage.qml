import QtQuick
import Quickshell
import Quickshell.Networking
import qs.components
import qs.services

// Wi-Fi networks in the control center. The list scans only while this page is open.
Column {
    id: root

    signal releaseFocus

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property bool radioOn: Networking.wifiEnabled
    readonly property var networks: {
        if (!device || !radioOn)
            return [];
        return device.networks.values.filter(n => n.name !== "").sort((a, b) => Number(b.connected) - Number(a.connected) || Number(b.known) - Number(a.known) || Math.round(b.signalStrength * 4) - Math.round(a.signalStrength * 4) || a.name.localeCompare(b.name));
    }

    // Kept outside the list: the list rebuilds on every scan and must not lose a typed password.
    property var asking: null
    property var attempt: null
    property string failure: ""

    function isOpen(network) {
        return network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe;
    }

    function isEnterprise(network) {
        return [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.DynamicWep, WifiSecurityType.Leap].includes(network.security);
    }

    function openTool() {
        Ui.popup = "";
        Quickshell.execDetached(["kitty", "--class", "niri-desk-tool", "nmtui"]);
    }

    function choose(network) {
        if (network.connected)
            return;
        failure = "";
        if (isEnterprise(network) && !network.known) {
            openTool();
        } else if (network.known || isOpen(network)) {
            attempt = network;
            asking = null;
            network.connect();
        } else {
            asking = network;
            password.text = "";
            password.forceActiveFocus();
        }
    }

    function submitPassword() {
        if (password.text.length < 8) {
            failure = Tr.t("At least 8 characters");
            return;
        }
        failure = "";
        attempt = asking;
        attempt.connectWithPsk(password.text);
        password.text = "";
    }

    function cancelPassword() {
        asking = null;
        password.text = "";
        failure = "";
        root.releaseFocus();
    }

    width: parent.width
    spacing: 10

    onDeviceChanged: {
        if (device)
            device.scannerEnabled = true;
    }
    Component.onCompleted: {
        if (device)
            device.scannerEnabled = true;
    }
    Component.onDestruction: {
        password.text = "";
        if (device)
            device.scannerEnabled = false;
    }

    Connections {
        target: root.attempt
        ignoreUnknownSignals: true

        function onConnectionFailed(reason) {
            const wrong = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout;
            root.failure = wrong ? Tr.t("Wrong password") : Tr.t("Could not connect");
            if (wrong && root.attempt && !root.attempt.known) {
                root.asking = root.attempt;
                password.forceActiveFocus();
            }
        }
        function onConnectedChanged() {
            if (root.attempt && root.attempt.connected) {
                root.asking = null;
                root.failure = "";
                root.attempt = null;
                root.releaseFocus();
            }
        }
    }

    PageHeader {
        title: Tr.t("Wi-Fi")
        on: root.radioOn
        switchEnabled: Networking.wifiHardwareEnabled
        onBack: {
            root.releaseFocus();
            Ui.controlPage = "";
        }
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    // Password for the chosen network
    Rectangle {
        width: parent.width
        height: visible ? askColumn.implicitHeight + 20 : 0
        visible: root.asking !== null
        radius: 11
        color: Qt.alpha(Theme.text, 0.05)

        Column {
            id: askColumn

            x: 10
            y: 10
            width: parent.width - 20
            spacing: 8

            Label {
                width: parent.width
                text: root.asking ? root.asking.name : ""
                size: 13
                font.weight: Font.Medium
            }
            Rectangle {
                width: parent.width
                height: 34
                radius: 8
                color: Qt.alpha(Theme.text, 0.07)
                border.width: password.activeFocus ? 1 : 0
                border.color: Theme.accent

                TextInput {
                    id: password

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.family: Theme.sans
                    font.pixelSize: 13
                    clip: true
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    Keys.onReturnPressed: root.submitPassword()
                    Keys.onEnterPressed: root.submitPassword()
                    Keys.onEscapePressed: root.cancelPassword()

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text === ""
                        text: Tr.t("Password")
                        color: Theme.muted
                        size: 13
                    }
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 14

                Label {
                    text: Tr.t("Cancel")
                    color: cancelArea.containsMouse ? Theme.text : Theme.muted
                    size: 12

                    MouseArea {
                        id: cancelArea

                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancelPassword()
                    }
                }
                Label {
                    text: Tr.t("Connect")
                    color: Theme.accent
                    size: 12

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitPassword()
                    }
                }
            }
        }
    }

    Label {
        width: parent.width
        visible: root.failure !== ""
        text: root.failure
        color: Theme.error
        size: 12
    }

    Label {
        width: parent.width
        visible: root.networks.length === 0
        text: !root.device ? Tr.t("No Wi-Fi adapter") : !Networking.wifiHardwareEnabled ? Tr.t("Wi-Fi is blocked by a hardware switch") : !root.radioOn ? Tr.t("Wi-Fi is off") : Tr.t("Searching…")
        color: Theme.muted
        size: 13
    }

    Flickable {
        width: parent.width
        height: Math.min(list.implicitHeight, 340)
        visible: root.networks.length > 0
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list

            width: parent.width
            spacing: 2

            Repeater {
                model: root.networks

                delegate: ChoiceRow {
                    id: row

                    required property var modelData

                    icon: "wifi"
                    iconOpacity: 0.35 + 0.65 * modelData.signalStrength
                    title: modelData.name
                    current: modelData.connected
                    locked: !root.isOpen(modelData) && !modelData.known && !modelData.connected
                    note: Math.round(modelData.signalStrength * 100) + "%"
                    sub: modelData.stateChanging ? Tr.t("Connecting…") : modelData.connected ? Tr.t("Connected") : modelData.known ? Tr.t("Saved") : ""
                    actions: {
                        const out = [];
                        if (modelData.connected)
                            out.push({
                                label: Tr.t("Disconnect"),
                                run: () => row.modelData.disconnect()
                            });
                        if (modelData.known)
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
        text: Tr.t("Network settings")
        color: toolArea.containsMouse ? Theme.text : Theme.muted
        size: 12

        MouseArea {
            id: toolArea

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openTool()
        }
    }
}
