open PushAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushManager/subscribe)
*/
@send
external subscribe: (
  pushManager,
  ~options: pushSubscriptionOptionsInit=?,
) => promise<pushSubscription> = "subscribe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushManager/getSubscription)
*/
@send
external getSubscription: pushManager => promise<pushSubscription> = "getSubscription"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushManager/permissionState)
*/
@send
external permissionState: (
  pushManager,
  ~options: pushSubscriptionOptionsInit=?,
) => promise<permissionState> = "permissionState"
