include EventTarget.Impl({type t = ServiceWorkerTypes.serviceWorkerRegistration})

@send
external update: ServiceWorkerTypes.serviceWorkerRegistration => promise<unit> = "update"

@send
external unregister: ServiceWorkerTypes.serviceWorkerRegistration => promise<bool> = "unregister"

@send
external showNotification: (
  ServiceWorkerTypes.serviceWorkerRegistration,
  ~title: string,
  ~options: NotificationTypes.notificationOptions=?,
) => promise<unit> = "showNotification"

@send
external getNotifications: (
  ServiceWorkerTypes.serviceWorkerRegistration,
  ~filter: NotificationTypes.getNotificationOptions=?,
) => promise<array<NotificationTypes.notification>> = "getNotifications"
