include EventTarget.Impl({type t = IndexedDbTypes.idbDatabase})

@send
external transaction: (
  IndexedDbTypes.idbDatabase,
  ~storeNames: string,
  ~mode: IndexedDbTypes.idbTransactionMode=?,
  ~options: IndexedDbTypes.idbTransactionOptions=?,
) => IndexedDbTypes.idbTransaction = "transaction"

@send
external transaction2: (
  IndexedDbTypes.idbDatabase,
  ~storeNames: array<string>,
  ~mode: IndexedDbTypes.idbTransactionMode=?,
  ~options: IndexedDbTypes.idbTransactionOptions=?,
) => IndexedDbTypes.idbTransaction = "transaction"

@send
external close: IndexedDbTypes.idbDatabase => unit = "close"

@send
external createObjectStore: (
  IndexedDbTypes.idbDatabase,
  ~name: string,
  ~options: IndexedDbTypes.idbObjectStoreParameters=?,
) => IndexedDbTypes.idbObjectStore = "createObjectStore"

@send
external deleteObjectStore: (IndexedDbTypes.idbDatabase, string) => unit = "deleteObjectStore"
