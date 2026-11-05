import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Top of the Time Machine page: the state of the backups and what can be done now.
Column {
    id: root

    spacing: 10

    onVisibleChanged: {
        if (visible)
            Backups.refresh();
    }

    Process {
        id: passwordRead

        command: [Ui.binDir + "niri-desk-timemachine", "password"]
        stdout: StdioCollector {
            onStreamFinished: {
                Quickshell.clipboardText = text.trim();
                Toasts.show(Tr.t("Password copied"), Tr.t("Keep it outside this computer, backups cannot be read without it"), "lock");
            }
        }
    }

    Rectangle {
        width: parent.width
        height: words.implicitHeight + 28
        radius: 18
        color: Qt.alpha(Theme.text, 0.045)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.06)

        Column {
            id: words

            x: 16
            y: 14
            width: parent.width - 32
            spacing: 10

            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                size: 13
                text: !Backups.status.installed ? Tr.t("Backups need restic. Install it on the Devices page.") : Backups.repo.trim() === "" ? Tr.t("Choose a folder below, best on an external disk. A folder on this disk does not survive losing the disk.") : Backups.running ? Tr.t("A backup is running now") : !Backups.status.reachable ? Tr.t("The backup disk is not connected") : Backups.status.lastError ? Tr.t("Last attempt failed: {e}").replace("{e}", Backups.status.lastError) : Tr.t("Last backup: {t}").replace("{t}", Backups.lastText)
            }
            Row {
                spacing: 8
                visible: !!Backups.status.installed

                PillButton {
                    text: Tr.t("Back up now")
                    accent: true
                    enabledLook: !Backups.running && Backups.repo.trim() !== ""
                    onClicked: {
                        if (enabledLook)
                            Backups.runNow();
                    }
                }
                PillButton {
                    text: Tr.t("Browse and restore")
                    icon: "history"
                    enabledLook: !!Backups.status.ready
                    onClicked: {
                        if (enabledLook)
                            Ui.backupsOpen = true;
                    }
                }
                PillButton {
                    text: Tr.t("Copy the password")
                    icon: "lock"
                    onClicked: passwordRead.running = true
                }
            }
        }
    }
}
