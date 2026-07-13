type t = NotificationTypes.notification = private {...NotificationTypes.notification}
type notificationDirection = NotificationTypes.notificationDirection
type notificationPermission = NotificationTypes.notificationPermission
type notificationAction = NotificationTypes.notificationAction = {
  ...NotificationTypes.notificationAction,
}
type notificationOptions = NotificationTypes.notificationOptions = {
  ...NotificationTypes.notificationOptions,
}
type getNotificationOptions = NotificationTypes.getNotificationOptions = {
  ...NotificationTypes.getNotificationOptions,
}
type notificationPermissionCallback = NotificationTypes.notificationPermissionCallback
type notificationEvent = NotificationTypes.notificationEvent = {
  ...NotificationTypes.notificationEvent,
}

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification)
*/
@new
external make: (~title: string, ~options: notificationOptions=?) => t = "Notification"

include EventTarget.Impl({type t = t})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/requestPermission_static)
*/
@scope("Notification")
external requestPermission: (
  ~deprecatedCallback: notificationPermissionCallback=?,
) => promise<notificationPermission> = "requestPermission"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification/close)
*/
@send
external close: t => unit = "close"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Notification/permission_static)
*/
@scope("Notification") @val
external permission: notificationPermission = "permission"

module Types = NotificationTypes
