@send
external match: (
  WebWorkersTypes.cacheStorage,
  ~request: FetchTypes.request,
  ~options: WebWorkersTypes.multiCacheQueryOptions=?,
) => Nullable.t<FetchTypes.response> = "match"

@send
external match2: (
  WebWorkersTypes.cacheStorage,
  ~request: string,
  ~options: WebWorkersTypes.multiCacheQueryOptions=?,
) => Nullable.t<FetchTypes.response> = "match"

@send
external has: (WebWorkersTypes.cacheStorage, string) => promise<bool> = "has"

@send
external open_: (WebWorkersTypes.cacheStorage, string) => promise<WebWorkersTypes.cache> = "open"

@send
external delete: (WebWorkersTypes.cacheStorage, string) => promise<bool> = "delete"

@send
external keys: WebWorkersTypes.cacheStorage => promise<array<string>> = "keys"
