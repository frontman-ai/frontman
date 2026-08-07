type t = ServiceWorkerTypes.serviceWorker = private {...ServiceWorkerTypes.serviceWorker}

include EventTarget.Impl({type t = t})

@send
external postMessage: (t, ~message: JSON.t, ~transfer: array<Dict.t<string>>) => unit =
  "postMessage"

@send
external postMessage2: (
  t,
  ~message: JSON.t,
  ~options: MessagePort.structuredSerializeOptions=?,
) => unit = "postMessage"

@send
external postMessageWithOptions: (
  t,
  ~message: JSON.t,
  ~options: MessagePort.structuredSerializeOptions=?,
) => unit = "postMessage"

module Cache = Cache
module Clients = Clients
module NavigationPreloadManager = NavigationPreloadManager
module ServiceWorkerContainer = ServiceWorkerContainer
module ServiceWorkerScope = ServiceWorkerScope
module ServiceWorkerRegistration = ServiceWorkerRegistration
module Types = ServiceWorkerTypes
