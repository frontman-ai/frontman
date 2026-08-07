@@warning("-30")

type permissionState =
  | @as("denied") Denied
  | @as("granted") Granted
  | @as("prompt") Prompt

type pushEncryptionKeyName =
  | @as("auth") Auth
  | @as("p256dh") P256dh

@editor.completeFrom(PushManager)
type pushManager = private {
  supportedContentEncodings: array<string>,
}

type applicationServerKey

type pushSubscriptionOptions = {
  userVisibleOnly: bool,
  applicationServerKey: applicationServerKey,
}

@editor.completeFrom(PushSubscription)
type pushSubscription = private {
  endpoint: string,
  expirationTime: Null.t<int>,
  options: pushSubscriptionOptions,
}

type pushSubscriptionOptionsInit = {
  mutable userVisibleOnly?: bool,
  mutable applicationServerKey?: applicationServerKey,
}

type pushSubscriptionJSONKeys = {
  p256dh: string,
  auth: string,
}

type pushSubscriptionJSON = {
  mutable endpoint?: string,
  mutable expirationTime?: Null.t<int>,
  mutable keys?: pushSubscriptionJSONKeys,
}

@editor.completeFrom(PushMessageData)
type pushMessageData

@editor.completeFrom(PushEvent)
type pushEvent = private {
  ...EventTypes.extendableEvent,
  data?: pushMessageData,
}
