@send
external get: (IndexedDbTypes.idbIndex, unknown) => IndexedDbTypes.idbRequest<JSON.t> = "get"

@send
external getKey: (IndexedDbTypes.idbIndex, unknown) => IndexedDbTypes.idbRequest<unknown> = "getKey"

@send
external getAll: (
  IndexedDbTypes.idbIndex,
  ~query: unknown=?,
  ~count: int=?,
) => IndexedDbTypes.idbRequest<array<JSON.t>> = "getAll"

@send
external getAllKeys: (
  IndexedDbTypes.idbIndex,
  ~query: unknown=?,
  ~count: int=?,
) => IndexedDbTypes.idbRequest<array<IndexedDbTypes.idbValidKey>> = "getAllKeys"

@send
external count: (IndexedDbTypes.idbIndex, ~query: unknown=?) => IndexedDbTypes.idbRequest<int> =
  "count"

@send
external openCursor: (
  IndexedDbTypes.idbIndex,
  ~query: unknown=?,
  ~direction: IndexedDbTypes.idbCursorDirection=?,
) => IndexedDbTypes.idbRequest<unknown> = "openCursor"

@send
external openKeyCursor: (
  IndexedDbTypes.idbIndex,
  ~query: unknown=?,
  ~direction: IndexedDbTypes.idbCursorDirection=?,
) => IndexedDbTypes.idbRequest<unknown> = "openKeyCursor"
