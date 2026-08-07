@send
external put: (
  IndexedDbTypes.idbObjectStore,
  ~value: JSON.t,
  ~key: IndexedDbTypes.idbValidKey=?,
) => IndexedDbTypes.idbRequest<IndexedDbTypes.idbValidKey> = "put"

@send
external add: (
  IndexedDbTypes.idbObjectStore,
  ~value: JSON.t,
  ~key: IndexedDbTypes.idbValidKey=?,
) => IndexedDbTypes.idbRequest<IndexedDbTypes.idbValidKey> = "add"

@send
external delete: (IndexedDbTypes.idbObjectStore, unknown) => IndexedDbTypes.idbRequest<unit> =
  "delete"

@send
external clear: IndexedDbTypes.idbObjectStore => IndexedDbTypes.idbRequest<unit> = "clear"

@send
external get: (IndexedDbTypes.idbObjectStore, unknown) => IndexedDbTypes.idbRequest<JSON.t> = "get"

@send
external getKey: (IndexedDbTypes.idbObjectStore, unknown) => IndexedDbTypes.idbRequest<unknown> =
  "getKey"

@send
external getAll: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
  ~count: int=?,
) => IndexedDbTypes.idbRequest<array<JSON.t>> = "getAll"

@send
external getAllKeys: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
  ~count: int=?,
) => IndexedDbTypes.idbRequest<array<IndexedDbTypes.idbValidKey>> = "getAllKeys"

@send
external count: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
) => IndexedDbTypes.idbRequest<int> = "count"

@send
external openCursor: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
  ~direction: IndexedDbTypes.idbCursorDirection=?,
) => IndexedDbTypes.idbRequest<unknown> = "openCursor"

@send
external openKeyCursor: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
  ~direction: IndexedDbTypes.idbCursorDirection=?,
) => IndexedDbTypes.idbRequest<unknown> = "openKeyCursor"

@send
external index: (IndexedDbTypes.idbObjectStore, string) => IndexedDbTypes.idbIndex = "index"

@send
external createIndex: (
  IndexedDbTypes.idbObjectStore,
  ~name: string,
  ~keyPath: string,
  ~options: IndexedDbTypes.idbIndexParameters=?,
) => IndexedDbTypes.idbIndex = "createIndex"

@send
external createIndex2: (
  IndexedDbTypes.idbObjectStore,
  ~name: string,
  ~keyPath: array<string>,
  ~options: IndexedDbTypes.idbIndexParameters=?,
) => IndexedDbTypes.idbIndex = "createIndex"

@send
external deleteIndex: (IndexedDbTypes.idbObjectStore, string) => unit = "deleteIndex"
