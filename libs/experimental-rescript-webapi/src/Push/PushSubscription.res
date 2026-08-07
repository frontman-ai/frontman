/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscription/getKey)
*/
@send
external getKey: (PushTypes.pushSubscription, PushTypes.pushEncryptionKeyName) => ArrayBuffer.t =
  "getKey"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscription/unsubscribe)
*/
@send
external unsubscribe: PushTypes.pushSubscription => promise<bool> = "unsubscribe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushSubscription/toJSON)
*/
@send
external toJSON: PushTypes.pushSubscription => PushTypes.pushSubscriptionJSON = "toJSON"
