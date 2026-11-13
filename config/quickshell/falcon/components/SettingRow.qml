import QtQuick
import qs.services

// One row of a settings card: toggle, slider, segmented choice, chips, color, text, secret or action.
Item {
    id: root

    property var item: ({})

    readonly property string type: item.type || ""
    readonly property var value: item.key ? Settings.get(item.key, item.fallback) : undefined
    readonly property bool below: type === "color" || (type === "choice" && item.layout === "chips")
    readonly property real headHeight: item.hint ? 62 : 54

    function display(v) {
        const n = Number(v);
        const rounded = Math.round(n * 100) / 100;
        switch (item.unit) {
        case "percent":
            return Math.round(n * 100) + " %";
        case "px":
            return Tr.t("{n} px").replace("{n}", rounded);
        case "ms":
            return Tr.t("{n} ms").replace("{n}", rounded);
        case "lines":
            return rounded >= 1000 ? Math.round(rounded / 1000) + " k" : String(rounded);
        case "kelvin":
            return rounded + " K";
        case "scale":
            return "×" + rounded;
        case "lineHeight":
            return rounded + " %";
        case "sec":
            return Tr.t("{n} s").replace("{n}", rounded);
        case "time":
            if (n === 0)
                return Tr.t("Off");
            return n < 60 ? Tr.t("{n} s").replace("{n}", n) : Tr.t("{n} min").replace("{n}", Math.round(n / 60));
        }
        return String(rounded);
    }

    implicitHeight: headHeight + (below ? belowArea.implicitHeight + 14 : 0)

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -8
        anchors.rightMargin: -8
        radius: 12
        color: Qt.alpha(Theme.text, hover.hovered ? 0.045 : 0)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }
    HoverHandler {
        id: hover
    }

    Column {
        y: (root.headHeight - height) / 2
        width: root.below ? root.width : Math.max(120, root.width - control.width - 18)
        spacing: 2

        Label {
            width: parent.width
            text: root.item.label || ""
            size: 14
        }
        Label {
            width: parent.width
            visible: !!root.item.hint
            text: root.item.hint || ""
            color: Theme.muted
            size: 12
        }
    }

    // The control on the right. Its width sets how much room the title gets.
    Item {
        id: control

        anchors.right: parent.right
        y: (root.headHeight - height) / 2
        width: {
            switch (root.type) {
            case "action":
                return actionButton.width;
            case "toggle":
                return toggleTrack.width;
            case "slider":
                return sliderRow.implicitWidth;
            case "choice":
                return root.below ? 0 : segments.width;
            case "text":
            case "number":
            case "secret":
                return field.width;
            }
            return 0;
        }
        height: 36

        // Action button. "danger" adds a second press to confirm.
        Rectangle {
            id: actionButton

            property bool armed: false
            readonly property bool danger: !!root.item.danger

            visible: root.type === "action"
            anchors.verticalCenter: parent.verticalCenter
            width: actionLabel.implicitWidth + 30
            height: 34
            radius: 11
            color: {
                if (danger)
                    return armed ? Theme.error : Qt.alpha(Theme.error, actionArea.containsMouse ? 0.28 : 0.16);
                return actionArea.containsMouse ? Theme.accent : Qt.alpha(Theme.accent, 0.2);
            }
            scale: actionArea.pressed ? 0.96 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 110
                }
            }

            Label {
                id: actionLabel

                anchors.centerIn: parent
                text: actionButton.armed ? root.item.confirm : (root.item.text || "")
                size: 13
                color: {
                    if (actionButton.danger)
                        return actionButton.armed ? Theme.pill : Theme.error;
                    return actionArea.containsMouse ? Theme.accentText : Theme.accent;
                }
            }
            MouseArea {
                id: actionArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (actionButton.danger && !actionButton.armed) {
                        actionButton.armed = true;
                        disarm.restart();
                        return;
                    }
                    actionButton.armed = false;
                    root.item.run();
                }
            }
            Timer {
                id: disarm

                interval: 4000
                onTriggered: actionButton.armed = false
            }
        }

        // Toggle
        Rectangle {
            id: toggleTrack

            visible: root.type === "toggle"
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 26
            radius: 13
            color: root.value === true ? Theme.accent : Qt.alpha(Theme.text, 0.14)

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }

            Rectangle {
                x: root.value === true ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: switchArea.pressed ? 24 : 20
                height: 20
                radius: 10
                color: root.value === true ? Theme.accentText : Theme.text

                Behavior on x {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.3, 1.5, 0.4, 1, 1, 1]
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
            MouseArea {
                id: switchArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Settings.set(root.item.key, root.value !== true)
            }
        }

        // Slider with its value in a small chip
        Row {
            id: sliderRow

            visible: root.type === "slider"
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            SliderBar {
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                handle: true
                value: root.type === "slider" ? (Number(root.value) - root.item.min) / (root.item.max - root.item.min) : 0
                onMoved: fraction => {
                    const raw = root.item.min + fraction * (root.item.max - root.item.min);
                    const stepped = Math.round(raw / root.item.step) * root.item.step;
                    Settings.set(root.item.key, Math.round(stepped * 1000) / 1000);
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 62
                height: 26
                radius: 8
                color: Qt.alpha(Theme.text, 0.07)

                Label {
                    anchors.centerIn: parent
                    text: root.type === "slider" ? root.display(root.value) : ""
                    size: 12
                }
            }
        }

        // Segmented choice: the highlight slides between options.
        Rectangle {
            id: segments

            visible: root.type === "choice" && !root.below
            anchors.verticalCenter: parent.verticalCenter
            width: segmentRow.implicitWidth + 6
            height: 34
            radius: 11
            color: Qt.alpha(Theme.text, 0.07)

            Rectangle {
                id: thumb

                y: 3
                height: parent.height - 6
                radius: 8
                color: Theme.accent
                visible: width > 0

                Behavior on x {
                    enabled: thumb.width > 0

                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.3, 1.25, 0.4, 1, 1, 1]
                    }
                }
                Behavior on width {
                    enabled: thumb.width > 0

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                id: segmentRow

                x: 3
                y: 3

                Repeater {
                    model: root.type === "choice" && !root.below ? root.item.options.length : 0

                    delegate: Item {
                        id: segment

                        required property int index

                        readonly property var optionValue: root.item.options[index]
                        readonly property bool selected: root.value === optionValue

                        function place() {
                            if (selected) {
                                thumb.x = x + 3;
                                thumb.width = width;
                            }
                        }

                        width: segmentLabel.implicitWidth + 22
                        height: 28
                        onSelectedChanged: place()
                        onXChanged: place()
                        onWidthChanged: place()
                        Component.onCompleted: place()

                        Label {
                            id: segmentLabel

                            anchors.centerIn: parent
                            text: root.item.names ? root.item.names[segment.index] : String(segment.optionValue)
                            color: segment.selected ? Theme.accentText : Theme.text
                            size: 13

                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.set(root.item.key, segment.optionValue)
                        }
                    }
                }
            }
        }

        // Text, number or secret: saved on Enter or when focus leaves.
        Rectangle {
            id: field

            readonly property bool secret: root.type === "secret"

            visible: root.type === "text" || root.type === "number" || secret
            anchors.verticalCenter: parent.verticalCenter
            width: root.item.width || 260
            height: 34
            radius: 10
            color: Qt.alpha(Theme.text, input.activeFocus ? 0.1 : 0.07)
            border.width: 1
            border.color: input.activeFocus ? Theme.accent : "transparent"

            Behavior on border.color {
                ColorAnimation {
                    duration: 180
                }
            }

            TextInput {
                id: input

                function commit() {
                    if (root.type !== "text" && root.type !== "number")
                        return;
                    const next = root.type === "number" ? Number(text) : text;
                    if (root.type === "number" && isNaN(next))
                        return;
                    if (next !== root.value)
                        Settings.set(root.item.key, next);
                }

                // Too long to fit while not being edited: the label below shows it shortened instead.
                readonly property bool overflows: !activeFocus && !field.secret && contentWidth > width - leftPadding - rightPadding

                anchors.fill: parent
                leftPadding: 11
                rightPadding: 11
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: overflows ? "transparent" : Theme.text
                font.family: Theme.mono
                font.pixelSize: 13
                selectByMouse: true
                echoMode: field.secret ? TextInput.Password : TextInput.Normal
                text: root.value === undefined ? "" : String(root.value)

                onAccepted: {
                    if (field.secret) {
                        root.item.run(text);
                        text = "";
                    } else {
                        commit();
                    }
                }
                onEditingFinished: commit()
                Keys.onEscapePressed: Ui.settingsOpen = false

                // Typing breaks the binding above, so outside changes such as a reset are copied here.
                Connections {
                    target: root
                    function onValueChanged() {
                        if (!input.activeFocus && root.value !== undefined)
                            input.text = String(root.value);
                    }
                }
            }
            // A long path cut in the middle of a word looked broken: keep its end, mark the cut.
            Text {
                x: 11
                width: parent.width - 22
                anchors.verticalCenter: parent.verticalCenter
                visible: input.overflows
                text: input.text
                elide: Text.ElideLeft
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: 13
            }
            Label {
                x: 11
                anchors.verticalCenter: parent.verticalCenter
                visible: field.secret && input.text === ""
                text: root.item.placeholder || ""
                color: Qt.alpha(Theme.text, 0.4)
                size: 13
            }
        }
    }

    // Controls too wide for the right side go under the title.
    Item {
        id: belowArea

        y: root.headHeight - 4
        width: root.width
        implicitHeight: root.type === "color" ? colorRow.implicitHeight : chips.implicitHeight
        visible: root.below

        Flow {
            id: chips

            width: parent.width
            spacing: 6
            visible: root.type === "choice"

            Repeater {
                model: root.type === "choice" && root.below ? root.item.options.length : 0

                delegate: Rectangle {
                    id: chip

                    required property int index

                    readonly property var optionValue: root.item.options[index]
                    readonly property bool selected: root.value === optionValue

                    width: chipLabel.implicitWidth + 24
                    height: 32
                    radius: selected ? 10 : 16
                    color: selected ? Theme.accent : Qt.alpha(Theme.text, chipArea.containsMouse ? 0.13 : 0.07)
                    scale: chipArea.pressed ? 0.96 : 1

                    Behavior on radius {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 110
                        }
                    }

                    Label {
                        id: chipLabel

                        anchors.centerIn: parent
                        text: root.item.names ? root.item.names[chip.index] : String(chip.optionValue)
                        color: chip.selected ? Theme.accentText : Theme.text
                        size: 13
                    }
                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.set(root.item.key, chip.optionValue)
                    }
                }
            }
        }

        // Wallpaper color, ready colors or any #rrggbb.
        Row {
            id: colorRow

            visible: root.type === "color"
            spacing: 8

            Rectangle {
                readonly property bool selected: String(root.value || "") === ""

                anchors.verticalCenter: parent.verticalCenter
                width: autoLabel.implicitWidth + 24
                height: 32
                radius: selected ? 10 : 16
                color: selected ? Theme.accent : Qt.alpha(Theme.text, autoArea.containsMouse ? 0.13 : 0.07)

                Label {
                    id: autoLabel

                    anchors.centerIn: parent
                    text: root.item.autoText || ""
                    color: parent.selected ? Theme.accentText : Theme.text
                    size: 13
                }
                MouseArea {
                    id: autoArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.set(root.item.key, "")
                }
            }

            Repeater {
                model: root.type === "color" ? root.item.colors : []

                delegate: Rectangle {
                    id: swatch

                    required property var modelData

                    readonly property bool selected: String(root.value || "").toLowerCase() === modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: modelData
                    border.width: selected ? 2 : 0
                    border.color: Theme.text
                    scale: swatchArea.containsMouse ? 1.14 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 140
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: swatch.selected
                        name: "check"
                        size: 15
                        color: "#10131a"
                    }
                    MouseArea {
                        id: swatchArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.set(root.item.key, swatch.modelData)
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 104
                height: 32
                radius: 10
                color: Qt.alpha(Theme.text, hexInput.activeFocus ? 0.1 : 0.07)
                border.width: 1
                border.color: hexInput.activeFocus ? Theme.accent : "transparent"

                TextInput {
                    id: hexInput

                    function commit() {
                        if (root.type === "color" && text !== String(root.value || ""))
                            Settings.set(root.item.key, text);
                    }

                    anchors.fill: parent
                    leftPadding: 10
                    rightPadding: 10
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 13
                    maximumLength: 7
                    text: String(root.value || "")
                    onAccepted: commit()
                    onEditingFinished: commit()
                    Keys.onEscapePressed: Ui.settingsOpen = false

                    Connections {
                        target: root
                        function onValueChanged() {
                            if (!hexInput.activeFocus)
                                hexInput.text = String(root.value || "");
                        }
                    }
                }
                Label {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hexInput.text === ""
                    text: "#rrggbb"
                    color: Qt.alpha(Theme.text, 0.4)
                    size: 13
                }
            }
        }
    }
}
