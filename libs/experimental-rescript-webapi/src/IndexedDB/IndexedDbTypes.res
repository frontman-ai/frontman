@@warning("-30")

type idbTransactionMode =
  | @as("readonly") Readonly
  | @as("readwrite") Readwrite
  | @as("versionchange") Versionchange

type idbTransactionDurability =
  | @as("default") Default
  | @as("relaxed") Relaxed
  | @as("strict") Strict

type idbRequestReadyState =
  | @as("done") Done
  | @as("pending") Pending

type idbCursorDirection =
  | @as("next") Next
  | @as("nextunique") Nextunique
  | @as("prev") Prev
  | @as("prevunique") Prevunique

@editor.completeFrom(IDBFactory)
type idbFactory = private {}

@editor.completeFrom(IDBDatabase)
type idbDatabase = private {
  ...EventTypes.eventTarget,
  name: string,
  version: int,
  objectStoreNames: DOM.domStringList,
}

@editor.completeFrom(IDBTransaction)
type idbTransaction = private {
  ...EventTypes.eventTarget,
  objectStoreNames: DOM.domStringList,
  mode: idbTransactionMode,
  durability: idbTransactionDurability,
  db: idbDatabase,
  error: Null.t<DOM.domException>,
}

type idbRequest<'t> = {
  ...EventTypes.eventTarget,
  result: 't,
  error: Null.t<DOM.domException>,
  source: unknown,
  transaction: Null.t<idbTransaction>,
  readyState: idbRequestReadyState,
}

type idbOpenDBRequest = {
  ...idbRequest<idbDatabase>,
}

@editor.completeFrom(IDBObjectStore)
type idbObjectStore = {
  mutable name: string,
  keyPath: string,
  indexNames: DOM.domStringList,
  transaction: idbTransaction,
  autoIncrement: bool,
}

@editor.completeFrom(IDBIndex)
type idbIndex = {
  mutable name: string,
  objectStore: idbObjectStore,
  keyPath: string,
  multiEntry: bool,
  unique: bool,
}

type idbValidKey = unknown

type idbDatabaseInfo = {
  mutable name?: string,
  mutable version?: int,
}

type idbTransactionOptions = {mutable durability?: idbTransactionDurability}

type idbObjectStoreParameters = {
  mutable keyPath?: Null.t<unknown>,
  mutable autoIncrement?: bool,
}

type idbIndexParameters = {
  mutable unique?: bool,
  mutable multiEntry?: bool,
}
