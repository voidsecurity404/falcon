import QtQuick
import qs.components
import qs.services

// A text field of the phone window. Enter fires `accepted`.
Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool multiline: false

    signal accepted

    function focusField() {
        input.forceActiveFocus();
    }

    implicitHeight: 40
    radius: 14
    color: Qt.alpha(Theme.text, 0.07)
    border.width: 1
    border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.8) : Qt.alpha(Theme.text, 0.06)

    Behavior on border.color {
        ColorAnimation {
            duration: 160
        }
    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Qt.alpha(Theme.accent, 0.5)
        font.family: Theme.sans
        font.pixelSize: Math.round(13 * Theme.fontScale)
        clip: true
        onAccepted: root.accepted()

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: input.text === "" && root.placeholder !== ""
            text: root.placeholder
            color: Qt.alpha(Theme.text, 0.4)
            size: 13
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: mouse => {
            input.forceActiveFocus();
            mouse.accepted = false;
        }
    }
}
