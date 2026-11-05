import QtQuick
import qs.services

// The glass under a widget, on the desktop and in the widget gallery.
Rectangle {
    border.width: 1
    border.color: Theme.panelEdge
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.alpha(Theme.glassBase, Math.max(0.05, Widgets.glass - 0.08))
        }
        GradientStop {
            position: 1
            color: Qt.alpha(Theme.glassBase, Widgets.glass)
        }
    }
}
