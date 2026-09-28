/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/match)
*/
@send
external match: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => Nullable.t<FetchTypes.response> = "match"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/match)
*/
@send
external match2: (
  WebWorkersTypes.cache,
  ~request: string,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => Nullable.t<FetchTypes.response> = "match"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/matchAll)
*/
@send
external matchAll: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request=?,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<array<FetchTypes.response>> = "matchAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/matchAll)
*/
@send
external matchAll2: (
  WebWorkersTypes.cache,
  ~request: string=?,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<array<FetchTypes.response>> = "matchAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/add)
*/
@send
external add: (WebWorkersTypes.cache, FetchTypes.request) => promise<unit> = "add"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/add)
*/
@send
external add2: (WebWorkersTypes.cache, string) => promise<unit> = "add"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/addAll)
*/
@send
external addAll: (WebWorkersTypes.cache, array<FetchTypes.requestInfo>) => promise<unit> = "addAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/put)
*/
@send
external put: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request,
  ~response: FetchTypes.response,
) => promise<unit> = "put"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/put)
*/
@send
external put2: (
  WebWorkersTypes.cache,
  ~request: string,
  ~response: FetchTypes.response,
) => promise<unit> = "put"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/delete)
*/
@send
external delete: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<bool> = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/delete)
*/
@send
external delete2: (
  WebWorkersTypes.cache,
  ~request: string,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<bool> = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/keys)
*/
@send
external keys: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request=?,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<array<FetchTypes.request>> = "keys"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Cache/keys)
*/
@send
external keys2: (
  WebWorkersTypes.cache,
  ~request: string=?,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<array<FetchTypes.request>> = "keys"
