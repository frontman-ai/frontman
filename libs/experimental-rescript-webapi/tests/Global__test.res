open WebAPI.Global

let response = await fetch("https://rescript-lang.org/")

let response2 = await fetch(
  "https://rescript-lang.org/",
  ~init={
    headers: HeadersInit.fromDict(
      dict{
        "Content-Type": "application/json",
        "Authorization": "Bearer token",
      },
    ),
    body: BodyInit.fromString(`secret=foo&response=bar`),
  },
)

let response3 = await fetchWithRequest(
  Request.fromURL("https://rescript-lang.org/"),
  ~init={
    method: "POST",
    headers: HeadersInit.fromDict(
      dict{
        "Content-Type": "application/x-www-form-urlencoded",
      },
    ),
    body: BodyInit.fromString(`secret=foo&response=bar`),
  },
)

removeEventListener(Mousedown, MouseEvent.preventDefault, ~options={capture: false})

let registrationResult = await navigator.serviceWorker->ServiceWorkerContainer.register("/sw.js")
let subscription = await registrationResult.pushManager->PushManager.subscribe(
  ~options={
    userVisibleOnly: true,
    applicationServerKey: ApplicationServerKey.fromString("MyPublicKey"),
  },
)

let pushSubscriptionJSON = subscription->PushSubscription.toJSON
let (auth, p256dh) = switch pushSubscriptionJSON.keys {
| None => ("?", "?")
| Some(keys) => (keys.auth, keys.p256dh)
}
Console.log(`For subscription ${subscription.endpoint}, auth is ${auth} and p256dh is ${p256dh}`)
