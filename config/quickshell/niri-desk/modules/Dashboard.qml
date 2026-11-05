import QtQuick
import Quickshell
import qs.components
import qs.services

// Soatni bosganda ochiladigan panel: ikkita sahifa yonma-yon turadi va suriladi.
FocusScope {
    id: root

    readonly property var tabs: [Tr.t("Today"), Tr.t("Music"), Tr.t("System"), Tr.t("Time")]
    readonly property int tabWidth: 118
    readonly property int pageGap: 24

    function select(index) {
        Ui.dashTab = index;
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
    onVisibleChanged: {
        if (visible)
            focusLater.restart();
    }

    Timer {
        id: focusLater

        interval: 60
        running: true
        onTriggered: root.forceActiveFocus()
    }

    // Ovozga qarab chayqaladigan pol: panelning butun eni bo'ylab, o'rtadan chetlarga.
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        opacity: Ui.dashTab === 1 ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }

        Repeater {
            model: Spectrum.count * 2

            delegate: Item {
                required property int index

                readonly property int band: index < Spectrum.count ? Spectrum.count - 1 - index : index - Spectrum.count
                readonly property real level: (Spectrum.levels[band] || 0) / 100

                width: (root.width - 2 * 44 - 4 * (Spectrum.count * 2 - 1)) / (Spectrum.count * 2)
                height: 124

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.level * 120
                    visible: height > 1
                    topLeftRadius: width / 2
                    topRightRadius: width / 2
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.alpha(Media.artAccent, 0.55)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(Media.artAccent, 0.04)
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 70
                        }
                    }
                }
            }
        }
    }

    // Vkladkalar: shisha kapsula, ichida rangli kapsula sirpanib yuradi.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        width: root.tabWidth * root.tabs.length + 8
        height: 44
        radius: 22
        color: Qt.alpha(Theme.text, 0.07)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.1)

        Rectangle {
            x: 4 + Ui.dashTab * root.tabWidth
            y: 4
            width: root.tabWidth
            height: 36
            radius: 18
            color: Ui.dashTab === 1 ? Media.artAccent : Theme.text

            Behavior on x {
                NumberAnimation {
                    duration: 460
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.3, 1.4, 0.4, 1, 1, 1]
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 400
                }
            }
        }

        Row {
            x: 4
            y: 4

            Repeater {
                model: root.tabs

                delegate: Item {
                    id: tab

                    required property string modelData
                    required property int index

                    readonly property bool current: Ui.dashTab === index

                    width: root.tabWidth
                    height: 36

                    Label {
                        anchors.centerIn: parent
                        text: tab.modelData
                        size: 14
                        color: tab.current ? (Ui.dashTab === 1 ? Media.artAccentText : Theme.pill) : tabArea.containsMouse ? Theme.text : Theme.muted
                        font.weight: tab.current ? Font.DemiBold : Font.Normal
                        scale: tabArea.pressed ? 0.95 : 1

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
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

        x: 28
        y: 66
        width: parent.width - 56
        height: parent.height - 66 - 20
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
            DashSystem {
                x: 2 * (pager.width + root.pageGap)
                width: pager.width
                height: pager.height
                visible: Ui.dashTab === 2 || slide.running
            }
            DashTime {
                x: 3 * (pager.width + root.pageGap)
                width: pager.width
                height: pager.height
                visible: Ui.dashTab === 3 || slide.running
            }
        }
    }
}
