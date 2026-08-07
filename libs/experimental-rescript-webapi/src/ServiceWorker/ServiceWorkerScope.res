type t = ServiceWorkerTypes.serviceWorkerGlobalScope = private {
  ...ServiceWorkerTypes.serviceWorkerGlobalScope,
}

include Worker.Impl({type t = t})

@send
external skipWaiting: t => promise<unit> = "skipWaiting"
