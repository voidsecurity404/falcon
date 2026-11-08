import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Top of the Telegram bot page: what the bot is doing now, and the first steps when it is not set up.
Rectangle {
    id: root

    property var status: ({ state: "stopped" })
    readonly property string phase: status.state || "stopped"
    readonly property bool on: Settings.get("remote.enabled", false)
    readonly property bool good: on && phase === "ready"
    readonly property bool warn: on && ["bad-token", "no-cloudflared", "error", "offline"].indexOf(phase) >= 0

    readonly property string headline: {
        if (!root.on)
            return Tr.t("The bot is off");
        switch (root.phase) {
        case "ready":
            return Tr.t("Working: @{bot}").replace("{bot}", status.bot || "");
        case "no-token":
            return Tr.t("Step 1: paste the bot token below");
        case "no-owner":
            return Tr.t("Step 2: put your Telegram ID below");
        case "bad-token":
            return Tr.t("Telegram does not accept this token");
        case "no-cloudflared":
            return Tr.t("cloudflared is not installed");
        case "offline":
            return Tr.t("No internet, trying again");
        case "tunnel":
        case "connecting":
        case "starting":
            return Tr.t("Connecting…");
        case "error":
            return Tr.t("Something went wrong");
        }
        return Tr.t("Starting…");
    }
    readonly property string detail: {
        if (!root.on)
            return Tr.t("Control this computer from the phone: system, terminal, windows, processes and clipboard, in a Telegram mini app.");
        switch (root.phase) {
        case "ready":
            return Tr.t("Open the bot in Telegram and press the Computer button next to the message field.");
        case "no-token":
            return Tr.t("In Telegram, open @BotFather, send /newbot, choose a name, and copy the token it gives.");
        case "no-owner":
            return Tr.t("Write /start to @{bot}: it answers with your ID. Only that account can use the bot.").replace("{bot}", status.bot || "");
        case "no-cloudflared":
            return Tr.t("Install it with: sudo pacman -S cloudflared");
        case "bad-token":
            return Tr.t("Check that the whole token was copied, or make a new one in @BotFather.");
        }
        return status.error || "";
    }

    implicitHeight: body.implicitHeight + 30
    radius: 18
    color: Qt.alpha(warn ? Theme.error : good ? Theme.accent : Theme.text, warn || good ? 0.13 : 0.05)

    Behavior on color {
        ColorAnimation {
            duration: 250
        }
    }

    Process {
        id: reader

        command: ["falcon-remote", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text);
                } catch (e) {
                    root.status = { state: "stopped" };
                }
            }
        }
    }
    Timer {
        interval: 1500
        repeat: true
        triggeredOnStart: true
        running: root.visible && Ui.settingsOpen
        onTriggered: reader.running = true
    }

    Row {
        id: body

        x: 16
        y: 15
        width: parent.width - 32
        spacing: 14

        Rectangle {
            width: 42
            height: 42
            radius: 14
            color: root.warn ? Theme.error : root.good ? Theme.accent : Qt.alpha(Theme.text, 0.1)

            Icon {
                anchors.centerIn: parent
                name: "send"
                size: 20
                color: root.warn || root.good ? Theme.accentText : Theme.text
            }
        }
        Column {
            width: body.width - 56 - (buttons.visible ? buttons.width + 14 : 0)
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: root.headline
                size: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: root.detail
                color: Theme.muted
                size: 12
                wrapMode: Text.WordWrap
            }
        }
        Row {
            id: buttons

            visible: root.on && (root.status.bot || "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Repeater {
                model: [
                    { text: Tr.t("Open in Telegram"), run: () => Quickshell.execDetached(["xdg-open", "https://t.me/" + root.status.bot]) },
                    { text: Tr.t("Restart"), run: () => Quickshell.execDetached(["systemctl", "--user", "restart", "falcon-remote.service"]) }
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: buttonText.implicitWidth + 26
                    height: 34
                    radius: 17
                    color: buttonArea.containsMouse ? Qt.alpha(Theme.text, 0.16) : Qt.alpha(Theme.text, 0.09)

                    Label {
                        id: buttonText

                        anchors.centerIn: parent
                        text: parent.modelData.text
                        size: 12
                    }
                    MouseArea {
                        id: buttonArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.modelData.run()
                    }
                }
            }
        }
    }
}
