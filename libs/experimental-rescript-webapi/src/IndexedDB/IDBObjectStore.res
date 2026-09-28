/**
Adds or updates a record in store with the given value and key.

If the store uses in-line keys and key is specified a "DataError" DOMException will be thrown.

If put() is used, any existing record with the key will be replaced. If add() is used, and if a record with the key already exists the request will fail, with request's error set to a "ConstraintError" DOMException.

If successful, request's result will be the record's key.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/put)
*/
@send
external put: (
  IndexedDbTypes.idbObjectStore,
  ~value: JSON.t,
  ~key: IndexedDbTypes.idbValidKey=?,
) => IndexedDbTypes.idbRequest<IndexedDbTypes.idbValidKey> = "put"

/**
Adds or updates a record in store with the given value and key.

If the store uses in-line keys and key is specified a "DataError" DOMException will be thrown.

If put() is used, any existing record with the key will be replaced. If add() is used, and if a record with the key already exists the request will fail, with request's error set to a "ConstraintError" DOMException.

If successful, request's result will be the record's key.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/add)
*/
@send
external add: (
  IndexedDbTypes.idbObjectStore,
  ~value: JSON.t,
  ~key: IndexedDbTypes.idbValidKey=?,
) => IndexedDbTypes.idbRequest<IndexedDbTypes.idbValidKey> = "add"

/**
Deletes records in store with the given key or in the given key range in query.

If successful, request's result will be undefined.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/delete)
*/
@send
external delete: (IndexedDbTypes.idbObjectStore, unknown) => IndexedDbTypes.idbRequest<unit> =
  "delete"

/**
Deletes all records in store.

If successful, request's result will be undefined.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/clear)
*/
@send
external clear: IndexedDbTypes.idbObjectStore => IndexedDbTypes.idbRequest<unit> = "clear"

/**
Retrieves the value of the first record matching the given key or key range in query.

If successful, request's result will be the value, or undefined if there was no matching record.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/get)
*/
@send
external get: (IndexedDbTypes.idbObjectStore, unknown) => IndexedDbTypes.idbRequest<JSON.t> = "get"

/**
Retrieves the key of the first record matching the given key or key range in query.

If successful, request's result will be the key, or undefined if there was no matching record.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/getKey)
*/
@send
external getKey: (IndexedDbTypes.idbObjectStore, unknown) => IndexedDbTypes.idbRequest<unknown> =
  "getKey"

/**
Retrieves the values of the records matching the given key or key range in query (up to count if given).

If successful, request's result will be an Array of the values.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/getAll)
*/
@send
external getAll: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
  ~count: int=?,
) => IndexedDbTypes.idbRequest<array<JSON.t>> = "getAll"

/**
Retrieves the keys of records matching the given key or key range in query (up to count if given).

If successful, request's result will be an Array of the keys.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/getAllKeys)
*/
@send
external getAllKeys: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
  ~count: int=?,
) => IndexedDbTypes.idbRequest<array<IndexedDbTypes.idbValidKey>> = "getAllKeys"

/**
Retrieves the number of records matching the given key or key range in query.

If successful, request's result will be the count.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/count)
*/
@send
external count: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
) => IndexedDbTypes.idbRequest<int> = "count"

/**
Opens a cursor over the records matching query, ordered by direction. If query is null, all records in store are matched.

If successful, request's result will be an IDBCursorWithValue pointing at the first matching record, or null if there were no matching records.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/openCursor)
*/
@send
external openCursor: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
  ~direction: IndexedDbTypes.idbCursorDirection=?,
) => IndexedDbTypes.idbRequest<unknown> = "openCursor"

/**
Opens a cursor with key only flag set over the records matching query, ordered by direction. If query is null, all records in store are matched.

If successful, request's result will be an IDBCursor pointing at the first matching record, or null if there were no matching records.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/openKeyCursor)
*/
@send
external openKeyCursor: (
  IndexedDbTypes.idbObjectStore,
  ~query: unknown=?,
  ~direction: IndexedDbTypes.idbCursorDirection=?,
) => IndexedDbTypes.idbRequest<unknown> = "openKeyCursor"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/index)
*/
@send
external index: (IndexedDbTypes.idbObjectStore, string) => IndexedDbTypes.idbIndex = "index"

/**
Creates a new index in store with the given name, keyPath and options and returns a new IDBIndex. If the keyPath and options define constraints that cannot be satisfied with the data already in store the upgrade transaction will abort with a "ConstraintError" DOMException.

Throws an "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/createIndex)
*/
@send
external createIndex: (
  IndexedDbTypes.idbObjectStore,
  ~name: string,
  ~keyPath: string,
  ~options: IndexedDbTypes.idbIndexParameters=?,
) => IndexedDbTypes.idbIndex = "createIndex"

/**
Creates a new index in store with the given name, keyPath and options and returns a new IDBIndex. If the keyPath and options define constraints that cannot be satisfied with the data already in store the upgrade transaction will abort with a "ConstraintError" DOMException.

Throws an "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/createIndex)
*/
@send
external createIndex2: (
  IndexedDbTypes.idbObjectStore,
  ~name: string,
  ~keyPath: array<string>,
  ~options: IndexedDbTypes.idbIndexParameters=?,
) => IndexedDbTypes.idbIndex = "createIndex"

/**
Deletes the index in store with the given name.

Throws an "InvalidStateError" DOMException if not called within an upgrade transaction.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBObjectStore/deleteIndex)
*/
@send
external deleteIndex: (IndexedDbTypes.idbObjectStore, string) => unit = "deleteIndex"
