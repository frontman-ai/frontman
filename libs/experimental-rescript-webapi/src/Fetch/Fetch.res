/**
Starts the process of fetching a resource from the network, returning a promise that is fulfilled once the response is available.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/fetch)
*/
external fetch: (string, ~init: Request.requestInit=?) => promise<Response.t> = "fetch"

/**
Starts the process of fetching a resource from the network, returning a promise that is fulfilled once the response is available.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/fetch)
*/
external fetchWithRequest: (Request.t, ~init: Request.requestInit=?) => promise<Response.t> =
  "fetch"
