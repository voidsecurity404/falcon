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
        title: Tr.t("From the phone")
        items: Phone.history.map(n => ({
                        id: n.id,
                        app: n.app || Tr.t("Phone"),
                        title: n.title || n.app,
                        sub: n.text,
                        time: n.time,
                        date: n.date,
                        replyId: n.active ? n.replyId : ""
                    }))
        emptyText: Tr.t("No notifications from the phone yet")
        emptyIcon: "phone"
        forgetIds: ids => Phone.forget(ids)
        timeOf: row => Toasts.timeLabel(row)
        replyTo: (row, text) => Phone.reply(row.replyId, text)
    }
}
