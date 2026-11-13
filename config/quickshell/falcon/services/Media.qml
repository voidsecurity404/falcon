pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property var player: {
        const list = players;
        return list.find(p => p.isPlaying) || (list.length > 0 ? list[0] : null);
    }
    // A player going away briefly reports undefined position and length.
    readonly property real progress: {
        const p = player;
        try {
            if (!p || !p.lengthSupported)
                return 0;
            const length = Number(p.length) || 0;
            const position = Number(p.position) || 0;
            return length > 0 ? Math.max(0, Math.min(1, position / length)) : 0;
        } catch (e) {
            return 0;
        }
    }
    readonly property string art: player ? player.trackArtUrl : ""
    // Browsers put the artist into the title as well: "Artist - Song".
    readonly property string title: {
        if (!player)
            return "";
        const prefix = player.trackArtist + " - ";
        return player.trackArtist && player.trackTitle.startsWith(prefix) ? player.trackTitle.slice(prefix.length) : player.trackTitle;
    }

    // The liveliest color of the cover, made readable over the panel. The theme accent without a cover.
    readonly property color artAccent: {
        const colors = quantizer.colors;
        if (art === "" || !colors || colors.length === 0)
            return Theme.accent;
        let best = colors[0];
        for (const c of colors) {
            if (c.hslSaturation * Math.sqrt(c.hslLightness) > best.hslSaturation * Math.sqrt(best.hslLightness))
                best = c;
        }
        const dark = Theme.text.hslLightness > 0.5;
        return Qt.hsla(best.hslHue < 0 ? 0 : best.hslHue, Math.min(0.85, Math.max(0.35, best.hslSaturation)), dark ? 0.74 : 0.34, 1);
    }
    readonly property color artAccentText: artAccent.hslLightness > 0.5 ? "#10141a" : "#ffffff"

    ColorQuantizer {
        id: quantizer

        source: Ui.topPanelOpen || Widgets.musicLive ? root.art : ""
        depth: 3
        rescaleSize: 64
    }

    // Mpris position o'zi yangilanmaydi: ijro paytida so'rab turamiz.
    Timer {
        interval: 1000
        repeat: true
        running: !!root.player && root.player.isPlaying && (Ui.topPanelOpen || Widgets.musicLive || (!Ui.zen && BarLayout.has("media")))
        onTriggered: root.player.positionChanged()
    }
}
