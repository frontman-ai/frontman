@send
external subscribe: (
  PushTypes.pushManager,
  ~options: PushTypes.pushSubscriptionOptionsInit=?,
) => promise<PushTypes.pushSubscription> = "subscribe"

@send
external getSubscription: PushTypes.pushManager => promise<PushTypes.pushSubscription> =
  "getSubscription"

@send
external permissionState: (
  PushTypes.pushManager,
  ~options: PushTypes.pushSubscriptionOptionsInit=?,
) => promise<PushTypes.permissionState> = "permissionState"
