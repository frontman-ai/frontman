open ServiceWorkerAPI
open NotificationAPI

include EventTarget.Impl({type t = serviceWorkerRegistration})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/update)
*/
@send
external update: serviceWorkerRegistration => promise<unit> = "update"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/unregister)
*/
@send
external unregister: serviceWorkerRegistration => promise<bool> = "unregister"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/showNotification)
*/
@send
external showNotification: (
  serviceWorkerRegistration,
  ~title: string,
  ~options: notificationOptions=?,
) => promise<unit> = "showNotification"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/getNotifications)
*/
@send
external getNotifications: (
  serviceWorkerRegistration,
  ~filter: getNotificationOptions=?,
) => promise<array<notification>> = "getNotifications"
