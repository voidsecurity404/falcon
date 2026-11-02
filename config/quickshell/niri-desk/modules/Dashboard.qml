import QtQuick
import Quickshell
import qs.components
import qs.services

// Soatni bosganda ochiladigan panel: to'rtta alohida vkladka.
FocusScope {
    id: root

    readonly property var tabs: [Tr.t("Today"), Tr.t("Status"), Tr.t("Lab"), Tr.t("AI")]

    function select(index) {
        Ui.dashTab = index;
    }

    // Yashiringan vkladkada fokus qolib ketmasin.
    Connections {
        target: Ui
        function onDashTabChanged() {
            if (Ui.dashTab !== 3)
                root.forceActiveFocus();
        }
    }

    focus: true
    Keys.onEscapePressed: Ui.popup = ""
    Keys.onPressed: event => {
        const digit = event.key - Qt.Key_1;
        if (digit >= 0 && digit <= 3) {
            select(digit);
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            select((Ui.dashTab + (event.key === Qt.Key_Tab ? 1 : 3)) % 4);
            event.accepted = true;
        }
    }

    // Qatlam fokusi panel ochilgach o'rnatiladi: shundan keyin olamiz.
    Timer {
        interval: 60
        running: true
        onTriggered: {
            if (Ui.dashTab !== 3)
                root.forceActiveFocus();
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        spacing: 4

        Repeater {
            model: root.tabs

            delegate: Rectangle {
                id: tab

                required property string modelData
                required property int index

                readonly property bool current: Ui.dashTab === index

                width: 120
                height: 32
                radius: 10
                color: current ? Qt.alpha(Theme.accent, 0.22) : tabArea.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent"

                Label {
                    anchors.centerIn: parent
                    text: tab.modelData
                    color: tab.current ? Theme.accent : Theme.text
                    font.weight: tab.current ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: tabArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.select(tab.index)
                }
            }
        }
    }

    Item {
        x: 24
        y: 58
        width: parent.width - 48
        height: parent.height - 58 - 16

        DashToday {
            anchors.fill: parent
            visible: Ui.dashTab === 0
        }
        DashStatus {
            anchors.fill: parent
            visible: Ui.dashTab === 1
        }
        DashLab {
            anchors.fill: parent
            visible: Ui.dashTab === 2
        }
        DashAi {
            anchors.fill: parent
            visible: Ui.dashTab === 3
        }
    }
}
