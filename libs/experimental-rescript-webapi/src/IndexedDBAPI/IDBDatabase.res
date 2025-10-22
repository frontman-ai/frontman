open IndexedDBAPI

include EventTarget.Impl({type t = idbDatabase})

/**
Returns a new transaction with the given mode ("readonly" or "readwrite") and scope which can be a single object store name or an array of names.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/transaction)
*/
@send
external transaction: (
  idbDatabase,
  ~storeNames: string,
  ~mode: idbTransactionMode=?,
  ~options: idbTransactionOptions=?,
) => idbTransaction = "transaction"

/**
Returns a new transaction with the given mode ("readonly" or "readwrite") and scope which can be a single object store name or an array of names.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/transaction)
*/
@send
external transaction2: (
  idbDatabase,
  ~storeNames: array<string>,
  ~mode: idbTransactionMode=?,
  ~options: idbTransactionOptions=?,
) => idbTransaction = "transaction"

/**
Closes the connection once all running transactions have finished.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/close)
*/
@send
external close: idbDatabase => unit = "close"

/**
Creates a new object store with the given name and options and returns a new IDBObjectStore.

Throws a "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/createObjectStore)
*/
@send
external createObjectStore: (
  idbDatabase,
  ~name: string,
  ~options: idbObjectStoreParameters=?,
) => idbObjectStore = "createObjectStore"

/**
Deletes the object store with the given name.

Throws a "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/deleteObjectStore)
*/
@send
external deleteObjectStore: (idbDatabase, string) => unit = "deleteObjectStore"
