/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CacheStorage/match)
*/
@send
external match: (
  WebWorkersTypes.cacheStorage,
  ~request: FetchTypes.request,
  ~options: WebWorkersTypes.multiCacheQueryOptions=?,
) => Nullable.t<FetchTypes.response> = "match"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CacheStorage/match)
*/
@send
external match2: (
  WebWorkersTypes.cacheStorage,
  ~request: string,
  ~options: WebWorkersTypes.multiCacheQueryOptions=?,
) => Nullable.t<FetchTypes.response> = "match"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CacheStorage/has)
*/
@send
external has: (WebWorkersTypes.cacheStorage, string) => promise<bool> = "has"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CacheStorage/open)
*/
@send
external open_: (WebWorkersTypes.cacheStorage, string) => promise<WebWorkersTypes.cache> = "open"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CacheStorage/delete)
*/
@send
external delete: (WebWorkersTypes.cacheStorage, string) => promise<bool> = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CacheStorage/keys)
*/
@send
external keys: WebWorkersTypes.cacheStorage => promise<array<string>> = "keys"
