import QtQuick
import qs.components
import qs.services

// The phone's media player: cover, title, a seek bar, the buttons and its volume.
PhonePage {
    id: root

    readonly property var m: Phone.media
    // The phone reports the position only on changes, so it is counted on here while playing.
    property real basePosition: m ? m.position : 0
    property real baseTime: Date.now()
    property real now: Date.now()
    readonly property real position: m ? Math.min(m.length, basePosition + (m.playing ? now - baseTime : 0)) : 0

    onMChanged: {
        basePosition = m ? m.position : 0;
        baseTime = Date.now();
        now = baseTime;
    }

    function clock(ms) {
        const s = Math.max(0, Math.floor(ms / 1000));
        const h = Math.floor(s / 3600);
        const mm = Math.floor(s % 3600 / 60);
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(mm).padStart(2, "0") + ":" + ss : mm + ":" + ss;
    }

    title: Tr.t("Media")
    subtitle: m ? m.player : ""

    Component.onCompleted: Phone.send("mediaRefresh")

    Timer {
        interval: 500
        repeat: true
        running: !!root.m && root.m.playing && root.visible
        onTriggered: root.now = Date.now()
    }

    Column {
        width: parent.width
        spacing: 16
        visible: !!root.m

        // Players on the phone, when there are several.
        Flow {
            width: parent.width
            spacing: 6
            visible: root.m && root.m.players.length > 1

            Repeater {
                model: root.m ? root.m.players : []

                delegate: PhoneButton {
                    required property string modelData

                    text: modelData
                    implicitHeight: 30
                    primary: root.m && root.m.player === modelData
                    onClicked: Phone.send("mediaPlayer", {
                        player: modelData
                    })
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 250)
            height: width
            radius: 30
            color: Qt.alpha(Theme.accent, 0.16)
            clip: true

            Icon {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                name: "music"
                size: 64
                color: Qt.alpha(Theme.accent, 0.8)
            }
            Image {
                id: cover

                anchors.fill: parent
                source: root.m ? root.m.art : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        Column {
            width: parent.width
            spacing: 3

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.m && root.m.title !== "" ? root.m.title : Tr.t("Nothing is playing")
                size: 16
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                text: root.m ? [root.m.artist, root.m.album].filter(s => s).join(" · ") : ""
                size: 12
                color: Theme.muted
            }
        }

        Column {
            width: parent.width
            spacing: 2
            visible: !!root.m && root.m.length > 0

            SliderBar {
                width: parent.width
                value: root.m && root.m.length > 0 ? root.position / root.m.length : 0
                enabled: !!root.m && root.m.canSeek
                onMoved: v => {
                    const target = Math.round(v * root.m.length);
                    Phone.send("mediaSeek", {
                        value: target
                    });
                    root.basePosition = target;
                    root.baseTime = Date.now();
                    root.now = root.baseTime;
                }
            }
            Item {
                width: parent.width
                height: 16

                Label {
                    text: root.clock(root.position)
                    size: 11
                    color: Theme.muted
                }
                Label {
                    anchors.right: parent.right
                    text: root.m ? root.clock(root.m.length) : ""
                    size: 11
                    color: Theme.muted
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22

            Repeater {
                model: [
                    {
                        icon: "previous",
                        action: "Previous",
                        big: false
                    },
                    {
                        icon: root.m && root.m.playing ? "pause" : "play",
                        action: "PlayPause",
                        big: true
                    },
                    {
                        icon: "next",
                        action: "Next",
                        big: false
                    }
                ]

                delegate: Rectangle {
                    id: control

                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: modelData.big ? 68 : 50
                    height: width
                    radius: width / 2
                    color: modelData.big ? Theme.accent : Qt.alpha(Theme.text, controlArea.containsMouse ? 0.12 : 0.07)
                    scale: controlArea.pressed ? 0.9 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutBack
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: control.modelData.icon
                        size: control.modelData.big ? 26 : 19
                        filled: control.modelData.icon !== "pause"
                        color: control.modelData.big ? Theme.accentText : Theme.text
                    }
                    MouseArea {
                        id: controlArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Phone.mediaAction(control.modelData.action)
                    }
                }
            }
        }

        // The player's volume on the phone.
        Row {
            width: parent.width
            spacing: 10

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "volume"
                size: 17
                color: Theme.muted
            }
            SliderBar {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 60
                value: root.m ? root.m.volume / 100 : 0
                onMoved: v => Phone.send("mediaVolume", {
                        value: Math.round(v * 100)
                    })
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.m ? root.m.volume : ""
                size: 11
                color: Theme.muted
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: !root.m
        text: Tr.t("Nothing is playing on the phone")
        color: Theme.muted
        size: 12
    }
}
