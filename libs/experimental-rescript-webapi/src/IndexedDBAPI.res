@@warning("-30")

open Prelude
open EventAPI

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

/**
In the following code snippet, we make a request to open a database, and include handlers for the success and error cases. For a full working example, see our To-do Notifications app (view example live.)
[See IDBFactory on MDN](https://developer.mozilla.org/docs/Web/API/IDBFactory)
*/
@editor.completeFrom(IDBFactory)
type idbFactory = {}

/**
This IndexedDB API interface provides a connection to a database; you can use an IDBDatabase object to open a transaction on your database then create, manipulate, and delete objects (data) in that database. The interface provides the only way to get and manage versions of the database.
[See IDBDatabase on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase)
*/
@editor.completeFrom(IDBDatabase)
type idbDatabase = {
  ...eventTarget,
  /**
    Returns the name of the database.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/name)
    */
  name: string,
  /**
    Returns the version of the database.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/version)
    */
  version: int,
  /**
    Returns a list of the names of object stores in the database.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/objectStoreNames)
    */
  objectStoreNames: domStringList,
}

/**
[See IDBTransaction on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction)
*/
@editor.completeFrom(IDBTransaction)
type idbTransaction = {
  ...eventTarget,
  /**
    Returns a list of the names of object stores in the transaction's scope. For an upgrade transaction this is all object stores in the database.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/objectStoreNames)
    */
  objectStoreNames: domStringList,
  /**
    Returns the mode the transaction was created with ("readonly" or "readwrite"), or "versionchange" for an upgrade transaction.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/mode)
    */
  mode: idbTransactionMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/durability)
    */
  durability: idbTransactionDurability,
  /**
    Returns the transaction's connection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/db)
    */
  db: idbDatabase,
  /**
    If the transaction was aborted, returns the error (a DOMException) providing the reason.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/error)
    */
  error: Null.t<domException>,
}

/**
The request object does not initially contain any information about the result of the operation, but once information becomes available, an event is fired on the request, and the information becomes available through the properties of the IDBRequest instance.
[See IDBRequest on MDN](https://developer.mozilla.org/docs/Web/API/IDBRequest)
*/
type idbRequest<'t> = {
  ...eventTarget,
  /**
    When a request is completed, returns the result, or undefined if the request failed. Throws a "InvalidStateError" DOMException if the request is still pending.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBRequest/result)
    */
  result: 't,
  /**
    When a request is completed, returns the error (a DOMException), or null if the request succeeded. Throws a "InvalidStateError" DOMException if the request is still pending.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBRequest/error)
    */
  error: Null.t<domException>,
  /**
    Returns the IDBObjectStore, IDBIndex, or IDBCursor the request was made against, or null if is was an open request.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBRequest/source)
    */
  source: unknown,
  /**
    Returns the IDBTransaction the request was made within. If this as an open request, then it returns an upgrade transaction while it is running, or null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBRequest/transaction)
    */
  transaction: Null.t<idbTransaction>,
  /**
    Returns "pending" until a request is complete, then returns "done".
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBRequest/readyState)
    */
  readyState: idbRequestReadyState,
}

/**
Also inherits methods from its parents IDBRequest and EventTarget.
[See IDBOpenDBRequest on MDN](https://developer.mozilla.org/docs/Web/API/IDBOpenDBRequest)
*/
type idbOpenDBRequest = {
  ...idbRequest<idbDatabase>,
}

/**
This example shows a variety of different uses of object stores, from updating the data structure with IDBObjectStore.createIndex inside an onupgradeneeded function, to adding a new item to our object store with IDBObjectStore.add. For a full working example, see our To-do Notifications app (view example live.)
[See IDBObjectStore on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore)
*/
@editor.completeFrom(IDBObjectStore)
type idbObjectStore = {
  /**
    Returns the name of the store.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/name)
    */
  mutable name: string,
  /**
    Returns the key path of the store, or null if none.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/keyPath)
    */
  keyPath: string,
  /**
    Returns a list of the names of indexes in the store.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/indexNames)
    */
  indexNames: domStringList,
  /**
    Returns the associated transaction.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/transaction)
    */
  transaction: idbTransaction,
  /**
    Returns true if the store has a key generator, and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/autoIncrement)
    */
  autoIncrement: bool,
}

/**
IDBIndex interface of the IndexedDB API provides asynchronous access to an index in a database. An index is a kind of object store for looking up records in another object store, called the referenced object store. You use this interface to retrieve data.
[See IDBIndex on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex)
*/
@editor.completeFrom(IDBIndex)
type idbIndex = {
  /**
    Returns the name of the index.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/name)
    */
  mutable name: string,
  /**
    Returns the IDBObjectStore the index belongs to.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/objectStore)
    */
  objectStore: idbObjectStore,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/keyPath)
    */
  keyPath: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/multiEntry)
    */
  multiEntry: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/unique)
    */
  unique: bool,
}

type idbValidKey = any

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
