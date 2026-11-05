import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// The shell's lock screen, used when session.lockScreen is "shell".
Scope {
    WlSessionLock {
        locked: Lock.active

        WlSessionLockSurface {
            color: "black"

            LockContent {
                id: content

                anchors.fill: parent
                Component.onCompleted: focusField()
            }
        }
    }

    // A look at the same screen that locks nothing.
    LazyLoader {
        active: Lock.preview

        PanelWindow {
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "falcon-lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockContent {
                anchors.fill: parent
                preview: true
                Component.onCompleted: focusField()
            }
        }
    }
}
