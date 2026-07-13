import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root
    visible: false

    property alias trackedNotifications: server.trackedNotifications
    signal received(var notification)

    function clear(): void {
        const copy = server.trackedNotifications.values.slice();
        for (const notification of copy)
            notification.dismiss();
    }

    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true
        onNotification: notification => {
            notification.tracked = true;
            notification.receivedAt = Date.now();
            Qt.callLater(() => {
                const tracked = server.trackedNotifications.values;
                while (tracked.length > 100)
                    tracked[0].dismiss();
            });
            root.received(notification);
        }
    }
}
