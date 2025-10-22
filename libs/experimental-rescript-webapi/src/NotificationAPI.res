@@warning("-30")

open EventAPI

type notificationDirection =
  | @as("auto") Auto
  | @as("ltr") Ltr
  | @as("rtl") Rtl

type notificationPermission =
  | @as("default") Default
  | @as("denied") Denied
  | @as("granted") Granted

/**
This Notifications API interface is used to configure and display desktop notifications to the user.
[See Notification on MDN](https://developer.mozilla.org/docs/Web/API/Notification)
*/
@editor.completeFrom(Notification)
type notification = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/permission_static)
    */
  permission: notificationPermission,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/title)
    */
  title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/dir)
    */
  dir: notificationDirection,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/lang)
    */
  lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/body)
    */
  body: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/tag)
    */
  tag: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/icon)
    */
  icon: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/badge)
    */
  badge: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/silent)
    */
  silent: Null.t<bool>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/requireInteraction)
    */
  requireInteraction: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/data)
    */
  data?: JSON.t,
}

/**
 An array of actions to display in the notification, for which the default is an empty array. 
 [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration/showNotification#actions)
 */
type notificationAction = {
  action: string,
  title: string,
  icon?: string,
}

type notificationOptions = {
  mutable dir?: notificationDirection,
  mutable lang?: string,
  mutable body?: string,
  mutable tag?: string,
  mutable icon?: string,
  mutable badge?: string,
  mutable silent?: Null.t<bool>,
  mutable requireInteraction?: bool,
  mutable data?: JSON.t,
  mutable actions?: array<notificationAction>,
  /**
    [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration/showNotification#vibrate)
  */
  mutable vibrate?: array<int>,
}

type getNotificationOptions = {mutable tag?: string}

type notificationPermissionCallback = notificationPermission => unit

type notificationEvent = {
  ...extendableEvent,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NotificationEvent/action)
  */
  action: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NotificationEvent/notification)
  */
  notification: notification,
}
