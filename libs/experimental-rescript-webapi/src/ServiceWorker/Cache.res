@send
external match: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => Nullable.t<FetchTypes.response> = "match"

@send
external match2: (
  WebWorkersTypes.cache,
  ~request: string,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => Nullable.t<FetchTypes.response> = "match"

@send
external matchAll: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request=?,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<array<FetchTypes.response>> = "matchAll"

@send
external matchAll2: (
  WebWorkersTypes.cache,
  ~request: string=?,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<array<FetchTypes.response>> = "matchAll"

@send
external add: (WebWorkersTypes.cache, FetchTypes.request) => promise<unit> = "add"

@send
external add2: (WebWorkersTypes.cache, string) => promise<unit> = "add"

@send
external addAll: (WebWorkersTypes.cache, array<FetchTypes.requestInfo>) => promise<unit> = "addAll"

@send
external put: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request,
  ~response: FetchTypes.response,
) => promise<unit> = "put"

@send
external put2: (
  WebWorkersTypes.cache,
  ~request: string,
  ~response: FetchTypes.response,
) => promise<unit> = "put"

@send
external delete: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<bool> = "delete"

@send
external delete2: (
  WebWorkersTypes.cache,
  ~request: string,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<bool> = "delete"

@send
external keys: (
  WebWorkersTypes.cache,
  ~request: FetchTypes.request=?,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<array<FetchTypes.request>> = "keys"

@send
external keys2: (
  WebWorkersTypes.cache,
  ~request: string=?,
  ~options: WebWorkersTypes.cacheQueryOptions=?,
) => promise<array<FetchTypes.request>> = "keys"
