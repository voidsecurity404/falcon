pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Foydalanuvchi tahrirlaydigan ro'yxatlar: snippetlar va ish profillari.
Singleton {
    id: root

    property var snippets: []
    property var profiles: []
    property string error: ""

    property var writes: []

    // Qaydlarda parol bo'lishi mumkin: fayl faqat egasiga ochiq, matn jarayon argumentlarida ko'rinmaydi.
    function saveText(folder, path, text) {
        writes = writes.filter(w => w.path !== path).concat([
            {
                folder: folder,
                path: path,
                text: text
            }
        ]);
        pump();
    }

    function pump() {
        if (writer.running || writes.length === 0)
            return;
        writer.current = writes[0];
        writes = writes.slice(1);
        writer.command = ["sh", "-c", 'umask 077; mkdir -p "$1" && cat > "$2.tmp" && mv "$2.tmp" "$2"', "sh", writer.current.folder, writer.current.path];
        writer.running = true;
    }

    Process {
        id: writer

        property var current: null

        stdinEnabled: true
        onStarted: {
            write(current.text);
            stdinEnabled = false;
        }
        onExited: {
            stdinEnabled = true;
            root.pump();
        }
    }

    function parseList(file, assign) {
        try {
            const value = JSON.parse(file.text() || "[]");
            assign(Array.isArray(value) ? value : []);
            error = "";
        } catch (e) {
            error = file.path;
            Toasts.show(Tr.t("Could not read a file"), Tr.t("{file} is invalid").replace("{file}", file.path.split("/").pop()), "alert");
        }
    }

    FileView {
        id: snippetFile

        path: Settings.dir + "snippets.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parseList(snippetFile, v => root.snippets = v)
    }

    FileView {
        id: profileFile

        path: Settings.dir + "profiles.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parseList(profileFile, v => root.profiles = v)
    }

    // Oynalar holati daqiqada bir marta saqlanadi.
    Process {
        id: saver

        command: [Ui.binDir + "niri-desk-session", "save"]
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: saver.running = true
    }
}
