import QtQuick
import Quickshell
import qs.components
import qs.services

// One thought for each day, from a list kept here. Forms: wide, tall.
Item {
    id: root

    property string form: "wide"
    readonly property var quotes: [
        ["The only way to do great work is to love what you do.", "Steve Jobs"],
        ["Stay hungry, stay foolish.", "Stewart Brand"],
        ["The journey of a thousand miles begins with a single step.", "Lao Tzu"],
        ["He who has a why to live can bear almost any how.", "Friedrich Nietzsche"],
        ["We are what we repeatedly do.", "Will Durant"],
        ["Talk is cheap. Show me the code.", "Linus Torvalds"],
        ["Premature optimization is the root of all evil.", "Donald Knuth"],
        ["Imagination is more important than knowledge.", "Albert Einstein"],
        ["Fortune favors the bold.", "Virgil"],
        ["Time is what we want most, but what we use worst.", "William Penn"],
        ["You miss 100% of the shots you don't take.", "Wayne Gretzky"],
        ["Beauty will save the world.", "Fyodor Dostoevsky"],
        ["Manuscripts don't burn.", "Mikhail Bulgakov"],
        ["I think, therefore I am.", "René Descartes"],
        ["The unexamined life is not worth living.", "Socrates"],
        ["Whoever fights monsters should see to it that he does not become a monster.", "Friedrich Nietzsche"],
        ["Done is better than perfect.", "Sheryl Sandberg"],
        ["Waste no more time arguing what a good man should be. Be one.", "Marcus Aurelius"],
        ["While we are postponing, life speeds by.", "Seneca"],
        ["The best way to predict the future is to invent it.", "Alan Kay"],
        ["Make it work, make it right, make it fast.", "Kent Beck"],
        ["What does not kill me makes me stronger.", "Friedrich Nietzsche"]
    ]
    readonly property int day: Math.floor((clock.date.getTime() - clock.date.getTimezoneOffset() * 60000) / 86400000)
    readonly property var today: quotes[day % quotes.length]

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    Label {
        x: 16
        y: -2
        text: "“"
        color: Qt.alpha(Theme.accent, 0.5)
        size: 72
        font.family: Theme.display
        font.weight: Font.Bold
    }
    Column {
        x: 24
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 8
        width: parent.width - 48
        spacing: 10

        Label {
            width: parent.width
            text: Tr.t(root.today[0])
            size: root.today[0].length > 55 ? 16 : 19
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
            lineHeight: 1.12
            maximumLineCount: 7
        }
        Label {
            width: parent.width
            text: "— " + Tr.t(root.today[1])
            color: Theme.accent
            size: 12
            font.weight: Font.Medium
        }
    }
}
