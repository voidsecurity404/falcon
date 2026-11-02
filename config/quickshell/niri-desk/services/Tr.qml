pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Interfeys tili. Manba matn inglizcha, ruscha tarjima i18n-ru.json katalogida.
Singleton {
    id: root

    readonly property string language: {
        const chosen = Settings.get("appearance.language", "auto");
        if (chosen === "en" || chosen === "ru")
            return chosen;
        const env = Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "";
        return String(env).startsWith("ru") ? "ru" : "en";
    }
    readonly property var locale: Qt.locale(language === "ru" ? "ru_RU" : "en_US")
    property var catalog: ({})

    function t(text) {
        if (language !== "ru")
            return text;
        const found = catalog[text];
        return found === undefined ? text : found;
    }

    function capitalized(text) {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    FileView {
        id: file

        path: Settings.dir + "i18n-ru.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.catalog = JSON.parse(text());
            } catch (e) {
                console.warn("Could not read i18n-ru.json:", e);
            }
        }
    }
}
