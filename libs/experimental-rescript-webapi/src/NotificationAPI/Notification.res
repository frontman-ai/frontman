open NotificationAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Notification)
*/
@new
external make: (~title: string, ~options: notificationOptions=?) => notification = "Notification"

include EventTarget.Impl({type t = notification})

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
external close: notification => unit = "close"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Notification/permission_static)
*/
@scope("Notification") @val
external permission: notificationPermission = "permission"
