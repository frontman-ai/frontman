@@warning("-30")

open EventAPI

type permissionState =
  | @as("denied") Denied
  | @as("granted") Granted
  | @as("prompt") Prompt

type pushEncryptionKeyName =
  | @as("auth") Auth
  | @as("p256dh") P256dh

/**
This Push API interface provides a way to receive notifications from third-party servers as well as request URLs for push notifications.
[See PushManager on MDN](https://developer.mozilla.org/docs/Web/API/PushManager)
*/
@editor.completeFrom(PushManager)
type pushManager = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushManager/supportedContentEncodings_static)
    */
  supportedContentEncodings: array<string>,
}

type applicationServerKey

/**
[See PushSubscriptionOptions on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscriptionOptions)
*/
type pushSubscriptionOptions = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscriptionOptions/userVisibleOnly)
    */
  userVisibleOnly: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscriptionOptions/applicationServerKey)
    */
  applicationServerKey: applicationServerKey,
}

/**
This Push API interface provides a subcription's URL endpoint and allows unsubscription from a push service.
[See PushSubscription on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscription)
*/
@editor.completeFrom(PushSubscription)
type pushSubscription = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscription/endpoint)
    */
  endpoint: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscription/expirationTime)
    */
  expirationTime: Null.t<int>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscription/options)
    */
  options: pushSubscriptionOptions,
}

type pushSubscriptionOptionsInit = {
  mutable userVisibleOnly?: bool,
  mutable applicationServerKey?: applicationServerKey,
}

type pushSubscriptionJSONKeys = {
  /** Base64URL-encoded ArrayBuffer value */
  p256dh: string,
  /** Base64URL-encoded ArrayBuffer value */
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
type pushEvent = {
  ...extendableEvent,
  /**
   [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushEvent/data)
   */
  data?: pushMessageData,
}
