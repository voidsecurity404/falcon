import QtQuick
import qs.services

// A round button on the glass bar: an icon, or any content placed inside, with a soft hover.
// `lit` keeps the highlight while the popup it opens is open.
Item {
    id: root

    property string icon: ""
    property real iconSize: 17
    property color color: Theme.text
    property bool lit: false
    property int padding: 7
    default property alias content: holder.data
    readonly property bool hovered: area.containsMouse
    signal clicked(var mouse)

    implicitWidth: (icon !== "" ? iconSize : holder.childrenRect.width) + padding * 2
    implicitHeight: BarLayout.buttonHeight
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Theme.text, root.lit ? 0.14 : area.containsMouse ? 0.09 : 0)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }
    Icon {
        anchors.centerIn: parent
        visible: root.icon !== ""
        name: root.icon
        size: root.iconSize
        color: root.color
    }
    Item {
        id: holder

        x: root.padding
        width: childrenRect.width
        height: parent.height
    }
    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
    }
}
