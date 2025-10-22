open ServiceWorkerAPI
open ChannelMessagingAPI

include EventTarget.Impl({type t = serviceWorker})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorker/postMessage)
*/
@send
external postMessage: (serviceWorker, ~message: JSON.t, ~transfer: array<Dict.t<string>>) => unit =
  "postMessage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorker/postMessage)
*/
@send
external postMessage2: (
  serviceWorker,
  ~message: JSON.t,
  ~options: structuredSerializeOptions=?,
) => unit = "postMessage"
