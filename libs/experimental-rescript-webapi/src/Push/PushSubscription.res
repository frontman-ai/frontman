@send
external getKey: (PushTypes.pushSubscription, PushTypes.pushEncryptionKeyName) => ArrayBuffer.t =
  "getKey"

@send
external unsubscribe: PushTypes.pushSubscription => promise<bool> = "unsubscribe"

@send
external toJSON: PushTypes.pushSubscription => PushTypes.pushSubscriptionJSON = "toJSON"
