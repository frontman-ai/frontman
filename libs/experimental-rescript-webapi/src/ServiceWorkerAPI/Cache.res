open FetchAPI
open WebWorkersAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/match)
*/
@send
external match: (cache, ~request: request, ~options: cacheQueryOptions=?) => Nullable.t<response> =
  "match"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/match)
*/
@send
external match2: (cache, ~request: string, ~options: cacheQueryOptions=?) => Nullable.t<response> =
  "match"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/matchAll)
*/
@send
external matchAll: (
  cache,
  ~request: request=?,
  ~options: cacheQueryOptions=?,
) => promise<array<response>> = "matchAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/matchAll)
*/
@send
external matchAll2: (
  cache,
  ~request: string=?,
  ~options: cacheQueryOptions=?,
) => promise<array<response>> = "matchAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/add)
*/
@send
external add: (cache, request) => promise<unit> = "add"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/add)
*/
@send
external add2: (cache, string) => promise<unit> = "add"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/addAll)
*/
@send
external addAll: (cache, array<requestInfo>) => promise<unit> = "addAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/put)
*/
@send
external put: (cache, ~request: request, ~response: response) => promise<unit> = "put"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/put)
*/
@send
external put2: (cache, ~request: string, ~response: response) => promise<unit> = "put"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/delete)
*/
@send
external delete: (cache, ~request: request, ~options: cacheQueryOptions=?) => promise<bool> =
  "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/delete)
*/
@send
external delete2: (cache, ~request: string, ~options: cacheQueryOptions=?) => promise<bool> =
  "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/keys)
*/
@send
external keys: (
  cache,
  ~request: request=?,
  ~options: cacheQueryOptions=?,
) => promise<array<request>> = "keys"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/keys)
*/
@send
external keys2: (
  cache,
  ~request: string=?,
  ~options: cacheQueryOptions=?,
) => promise<array<request>> = "keys"
