open FetchAPI
open FileAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request)
*/
@new
external fromURL: (string, ~init: requestInit=?) => request = "Request"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request)
*/
@new
external fromRequest: (request, ~init: requestInit=?) => request = "Request"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/arrayBuffer)
*/
@send
external arrayBuffer: request => promise<ArrayBuffer.t> = "arrayBuffer"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/blob)
*/
@send
external blob: request => promise<blob> = "blob"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/bytes)
*/
@send
external bytes: request => promise<array<int>> = "bytes"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/formData)
*/
@send
external formData: request => promise<formData> = "formData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/json)
*/
@send
external json: request => promise<JSON.t> = "json"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/text)
*/
@send
external text: request => promise<string> = "text"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/clone)
*/
@send
external clone: request => request = "clone"
