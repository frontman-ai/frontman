/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushManager/subscribe)
*/
@send
external subscribe: (
  PushTypes.pushManager,
  ~options: PushTypes.pushSubscriptionOptionsInit=?,
) => promise<PushTypes.pushSubscription> = "subscribe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushManager/getSubscription)
*/
@send
external getSubscription: PushTypes.pushManager => promise<PushTypes.pushSubscription> =
  "getSubscription"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushManager/permissionState)
*/
@send
external permissionState: (
  PushTypes.pushManager,
  ~options: PushTypes.pushSubscriptionOptionsInit=?,
) => promise<PushTypes.permissionState> = "permissionState"
