import QtQuick
import qs.components
import qs.services

// The phone's notifications inside the phone window; the same list as the bell's Phone tab.
PhonePage {
    id: root

    title: Tr.t("Notifications")
    subtitle: Tr.t("{n} on the phone").replace("{n}", Phone.notifications.length)

    NotificationList {
        anchors.fill: parent
        anchors.bottomMargin: 4
        title: Tr.t("On the phone")
        items: Phone.notifications.map(n => ({
                    id: n.id,
                    app: n.app || Tr.t("Phone"),
                    title: n.title || n.app,
                    sub: n.text,
                    time: Qt.formatTime(new Date(n.time * 1000), "hh:mm"),
                    replyId: n.replyId
                }))
        emptyText: Tr.t("No notifications on the phone")
        emptyIcon: "phone"
        forgetIds: ids => Phone.dismiss(ids)
        timeOf: row => row.time
        replyTo: (row, text) => Phone.reply(row.replyId, text)
    }
}
