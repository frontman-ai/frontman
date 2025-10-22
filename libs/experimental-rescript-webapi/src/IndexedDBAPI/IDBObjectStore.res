open IndexedDBAPI
open Prelude

/**
Adds or updates a record in store with the given value and key.

If the store uses in-line keys and key is specified a "DataError" DOMException will be thrown.

If put() is used, any existing record with the key will be replaced. If add() is used, and if a record with the key already exists the request will fail, with request's error set to a "ConstraintError" DOMException.

If successful, request's result will be the record's key.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/put)
*/
@send
external put: (idbObjectStore, ~value: JSON.t, ~key: idbValidKey=?) => idbRequest<idbValidKey> =
  "put"

/**
Adds or updates a record in store with the given value and key.

If the store uses in-line keys and key is specified a "DataError" DOMException will be thrown.

If put() is used, any existing record with the key will be replaced. If add() is used, and if a record with the key already exists the request will fail, with request's error set to a "ConstraintError" DOMException.

If successful, request's result will be the record's key.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/add)
*/
@send
external add: (idbObjectStore, ~value: JSON.t, ~key: idbValidKey=?) => idbRequest<idbValidKey> =
  "add"

/**
Deletes records in store with the given key or in the given key range in query.

If successful, request's result will be undefined.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/delete)
*/
@send
external delete: (idbObjectStore, any) => idbRequest<unit> = "delete"

/**
Deletes all records in store.

If successful, request's result will be undefined.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/clear)
*/
@send
external clear: idbObjectStore => idbRequest<unit> = "clear"

/**
Retrieves the value of the first record matching the given key or key range in query.

If successful, request's result will be the value, or undefined if there was no matching record.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/get)
*/
@send
external get: (idbObjectStore, any) => idbRequest<JSON.t> = "get"

/**
Retrieves the key of the first record matching the given key or key range in query.

If successful, request's result will be the key, or undefined if there was no matching record.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/getKey)
*/
@send
external getKey: (idbObjectStore, any) => idbRequest<any> = "getKey"

/**
Retrieves the values of the records matching the given key or key range in query (up to count if given).

If successful, request's result will be an Array of the values.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/getAll)
*/
@send
external getAll: (idbObjectStore, ~query: any=?, ~count: int=?) => idbRequest<array<JSON.t>> =
  "getAll"

/**
Retrieves the keys of records matching the given key or key range in query (up to count if given).

If successful, request's result will be an Array of the keys.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/getAllKeys)
*/
@send
external getAllKeys: (
  idbObjectStore,
  ~query: any=?,
  ~count: int=?,
) => idbRequest<array<idbValidKey>> = "getAllKeys"

/**
Retrieves the number of records matching the given key or key range in query.

If successful, request's result will be the count.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/count)
*/
@send
external count: (idbObjectStore, ~query: any=?) => idbRequest<int> = "count"

/**
Opens a cursor over the records matching query, ordered by direction. If query is null, all records in store are matched.

If successful, request's result will be an IDBCursorWithValue pointing at the first matching record, or null if there were no matching records.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/openCursor)
*/
@send
external openCursor: (
  idbObjectStore,
  ~query: any=?,
  ~direction: idbCursorDirection=?,
) => idbRequest<any> = "openCursor"

/**
Opens a cursor with key only flag set over the records matching query, ordered by direction. If query is null, all records in store are matched.

If successful, request's result will be an IDBCursor pointing at the first matching record, or null if there were no matching records.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/openKeyCursor)
*/
@send
external openKeyCursor: (
  idbObjectStore,
  ~query: any=?,
  ~direction: idbCursorDirection=?,
) => idbRequest<any> = "openKeyCursor"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/index)
*/
@send
external index: (idbObjectStore, string) => idbIndex = "index"

/**
Creates a new index in store with the given name, keyPath and options and returns a new IDBIndex. If the keyPath and options define constraints that cannot be satisfied with the data already in store the upgrade transaction will abort with a "ConstraintError" DOMException.

Throws an "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/createIndex)
*/
@send
external createIndex: (
  idbObjectStore,
  ~name: string,
  ~keyPath: string,
  ~options: idbIndexParameters=?,
) => idbIndex = "createIndex"

/**
Creates a new index in store with the given name, keyPath and options and returns a new IDBIndex. If the keyPath and options define constraints that cannot be satisfied with the data already in store the upgrade transaction will abort with a "ConstraintError" DOMException.

Throws an "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/createIndex)
*/
@send
external createIndex2: (
  idbObjectStore,
  ~name: string,
  ~keyPath: array<string>,
  ~options: idbIndexParameters=?,
) => idbIndex = "createIndex"

/**
Deletes the index in store with the given name.

Throws an "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/deleteIndex)
*/
@send
external deleteIndex: (idbObjectStore, string) => unit = "deleteIndex"
