type t = ServiceWorkerTypes.serviceWorkerGlobalScope = private {
  ...ServiceWorkerTypes.serviceWorkerGlobalScope,
}

include Worker.Impl({type t = t})

/**
Forces the waiting service worker to become the active service worker.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerGlobalScope/skipWaiting)
*/
@send
external skipWaiting: t => promise<unit> = "skipWaiting"
