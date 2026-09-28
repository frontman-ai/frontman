include EventTarget.Impl({type t = IndexedDbTypes.idbDatabase})

/**
Returns a new transaction with the given mode ("readonly" or "readwrite") and scope which can be a single object store name or an array of names.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/transaction)
*/
@send
external transaction: (
  IndexedDbTypes.idbDatabase,
  ~storeNames: string,
  ~mode: IndexedDbTypes.idbTransactionMode=?,
  ~options: IndexedDbTypes.idbTransactionOptions=?,
) => IndexedDbTypes.idbTransaction = "transaction"

/**
Returns a new transaction with the given mode ("readonly" or "readwrite") and scope which can be a single object store name or an array of names.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/transaction)
*/
@send
external transaction2: (
  IndexedDbTypes.idbDatabase,
  ~storeNames: array<string>,
  ~mode: IndexedDbTypes.idbTransactionMode=?,
  ~options: IndexedDbTypes.idbTransactionOptions=?,
) => IndexedDbTypes.idbTransaction = "transaction"

/**
Closes the connection once all running transactions have finished.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/close)
*/
@send
external close: IndexedDbTypes.idbDatabase => unit = "close"

/**
Creates a new object store with the given name and options and returns a new IDBObjectStore.

Throws a "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/createObjectStore)
*/
@send
external createObjectStore: (
  IndexedDbTypes.idbDatabase,
  ~name: string,
  ~options: IndexedDbTypes.idbObjectStoreParameters=?,
) => IndexedDbTypes.idbObjectStore = "createObjectStore"

/**
Deletes the object store with the given name.

Throws a "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBDatabase/deleteObjectStore)
*/
@send
external deleteObjectStore: (IndexedDbTypes.idbDatabase, string) => unit = "deleteObjectStore"
