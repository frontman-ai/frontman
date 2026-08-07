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

@new
external make: (~title: string, ~options: notificationOptions=?) => t = "Notification"

include EventTarget.Impl({type t = t})

@scope("Notification")
external requestPermission: (
  ~deprecatedCallback: notificationPermissionCallback=?,
) => promise<notificationPermission> = "requestPermission"

@send
external close: t => unit = "close"

@scope("Notification") @val
external permission: notificationPermission = "permission"

module Types = NotificationTypes
