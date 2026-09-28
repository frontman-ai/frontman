type clientQueryOptions = {
  mutable includeUncontrolled?: bool,
  @as("type") mutable type_?: string,
}

/**
Returns a `Promise` for a `Client` matching a given id.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clients/get)
*/
@send
external get: (
  ServiceWorkerTypes.clients,
  string,
) => promise<Nullable.t<ServiceWorkerTypes.client>> = "get"

/**
Returns a `Promise` for an array of `Client` objects matching the given options.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clients/matchAll)
*/
@send
external matchAll: (
  ServiceWorkerTypes.clients,
  ~options: clientQueryOptions=?,
) => promise<array<ServiceWorkerTypes.client>> = "matchAll"

/**
Opens a new browser window for a given WebApiURL and returns a `Promise` for the new `WindowClient`.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clients/openWindow)
*/
@send
external openWindow: (
  ServiceWorkerTypes.clients,
  string,
) => promise<ServiceWorkerTypes.windowClient> = "openWindow"

/**
Allows an active service worker to set itself as the controller for all clients within its scope.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clients/claim)
*/
@send
external claim: ServiceWorkerTypes.clients => promise<unit> = "claim"
