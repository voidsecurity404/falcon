import QtQuick
import qs.services

// The glass under a widget, on the desktop and in the widget gallery.
Rectangle {
    // The widget's own glass; the common widgets.opacity unless it has one.
    property real glass: Widgets.glass

    border.width: 1
    border.color: Theme.panelEdge
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.alpha(Theme.glassBase, Math.max(0.05, glass - 0.08))
        }
        GradientStop {
            position: 1
            color: Qt.alpha(Theme.glassBase, glass)
        }
    }
}
