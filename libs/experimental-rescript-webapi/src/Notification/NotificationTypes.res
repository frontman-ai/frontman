@@warning("-30")

type notificationDirection =
  | @as("auto") Auto
  | @as("ltr") Ltr
  | @as("rtl") Rtl

type notificationPermission =
  | @as("default") Default
  | @as("denied") Denied
  | @as("granted") Granted

@editor.completeFrom(WebApiNotification)
type notification = private {
  ...EventTypes.eventTarget,
  permission: notificationPermission,
  title: string,
  dir: notificationDirection,
  lang: string,
  body: string,
  tag: string,
  icon: string,
  badge: string,
  silent: Null.t<bool>,
  requireInteraction: bool,
  data?: JSON.t,
}

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
  mutable vibrate?: array<int>,
}

type getNotificationOptions = {mutable tag?: string}

type notificationPermissionCallback = notificationPermission => unit

type notificationEvent = {
  ...EventTypes.extendableEvent,
  action: string,
  notification: notification,
}
