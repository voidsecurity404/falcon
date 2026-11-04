import QtQuick
import Quickshell
import qs.components
import qs.services

// Soatni bosganda ochiladigan panel: uchta sahifa yonma-yon turadi va suriladi.
FocusScope {
    id: root

    readonly property var tabs: [Tr.t("Today"), Tr.t("Music"), Tr.t("AI")]
    readonly property int tabWidth: 130
    readonly property int pageGap: 24
    // AI sahifasi ko'ringanda yozish maydoni fokusni oladi: boshqa sahifalar orasida surilganda u ochilmasligi kerak.
    property bool leavingAi: false
    property int lastTab: Ui.dashTab

    function select(index) {
        Ui.dashTab = index;
    }

    // Yashiringan vkladkada fokus qolib ketmasin.
    Connections {
        target: Ui
        function onDashTabChanged() {
            root.leavingAi = root.lastTab === 2;
            root.lastTab = Ui.dashTab;
            if (Ui.dashTab !== 2)
                root.forceActiveFocus();
        }
    }

    focus: true
    Keys.onEscapePressed: Ui.popup = ""
    Keys.onPressed: event => {
        const digit = event.key - Qt.Key_1;
        if (digit >= 0 && digit <= 2) {
            select(digit);
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            select((Ui.dashTab + (event.key === Qt.Key_Tab ? 1 : 2)) % 3);
            event.accepted = true;
        }
    }

    // Qatlam fokusi panel ochilgach o'rnatiladi: shundan keyin olamiz.
    Timer {
        interval: 60
        running: true
        onTriggered: {
            if (Ui.dashTab !== 2)
                root.forceActiveFocus();
        }
    }

    // Vkladkalar: faqat matn, tagidagi chiziq ular orasida sirpanadi.
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: root.tabWidth * root.tabs.length
        height: 38

        Rectangle {
            x: Ui.dashTab * root.tabWidth + (root.tabWidth - width) / 2
            y: 33
            width: 34
            height: 3
            radius: 2
            color: Theme.accent

            Behavior on x {
                NumberAnimation {
                    duration: 460
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.3, 1.5, 0.4, 1, 1, 1]
                }
            }
        }

        Row {
            Repeater {
                model: root.tabs

                delegate: Item {
                    id: tab

                    required property string modelData
                    required property int index

                    readonly property bool current: Ui.dashTab === index

                    width: root.tabWidth
                    height: 38

                    Label {
                        anchors.centerIn: parent
                        text: tab.modelData
                        size: 14
                        color: tab.current || tabArea.containsMouse ? Theme.text : Theme.muted
                        font.weight: tab.current ? Font.DemiBold : Font.Normal
                        scale: tabArea.pressed ? 0.95 : 1

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 110
                            }
                        }
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
    }

    Item {
        id: pager

        x: 24
        y: 58
        width: parent.width - 48
        height: parent.height - 58 - 16
        clip: true

        Item {
            x: -Ui.dashTab * (pager.width + root.pageGap)
            width: pager.width
            height: pager.height

            Behavior on x {
                NumberAnimation {
                    id: slide

                    duration: 480
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.25, 1.08, 0.35, 1, 1, 1]
                }
            }

            DashToday {
                width: pager.width
                height: pager.height
                visible: Ui.dashTab === 0 || slide.running
            }
            DashMusic {
                x: pager.width + root.pageGap
                width: pager.width
                height: pager.height
                visible: Ui.dashTab === 1 || slide.running
            }
            DashAi {
                x: 2 * (pager.width + root.pageGap)
                width: pager.width
                height: pager.height
                visible: Ui.dashTab === 2 || (slide.running && root.leavingAi)
            }
        }
    }
}
