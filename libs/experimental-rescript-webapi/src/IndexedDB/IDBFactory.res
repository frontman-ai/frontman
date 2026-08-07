@send
external open_: (
  IndexedDbTypes.idbFactory,
  ~name: string,
  ~version: int=?,
) => IndexedDbTypes.idbOpenDBRequest = "open"

@send
external deleteDatabase: (IndexedDbTypes.idbFactory, string) => IndexedDbTypes.idbOpenDBRequest =
  "deleteDatabase"

@send
external databases: IndexedDbTypes.idbFactory => promise<array<IndexedDbTypes.idbDatabaseInfo>> =
  "databases"

@send
external cmp: (IndexedDbTypes.idbFactory, ~first: JSON.t, ~second: JSON.t) => int = "cmp"
