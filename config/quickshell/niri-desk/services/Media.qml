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
    readonly property real progress: player && player.lengthSupported && player.length > 0 ? player.position / player.length : 0

    // Mpris position o'zi yangilanmaydi: ijro paytida so'rab turamiz.
    Timer {
        interval: 1000
        repeat: true
        running: !!root.player && root.player.isPlaying && (Ui.topPanelOpen || Widgets.musicLive)
        onTriggered: root.player.positionChanged()
    }
}
