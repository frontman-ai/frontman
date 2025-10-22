open IndexedDBAPI
open Prelude

/**
Retrieves the value of the first record matching the given key or key range in query.

If successful, request's result will be the value, or undefined if there was no matching record.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/get)
*/
@send
external get: (idbIndex, any) => idbRequest<JSON.t> = "get"

/**
Retrieves the key of the first record matching the given key or key range in query.

If successful, request's result will be the key, or undefined if there was no matching record.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/getKey)
*/
@send
external getKey: (idbIndex, any) => idbRequest<any> = "getKey"

/**
Retrieves the values of the records matching the given key or key range in query (up to count if given).

If successful, request's result will be an Array of the values.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/getAll)
*/
@send
external getAll: (idbIndex, ~query: any=?, ~count: int=?) => idbRequest<array<JSON.t>> = "getAll"

/**
Retrieves the keys of records matching the given key or key range in query (up to count if given).

If successful, request's result will be an Array of the keys.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/getAllKeys)
*/
@send
external getAllKeys: (idbIndex, ~query: any=?, ~count: int=?) => idbRequest<array<idbValidKey>> =
  "getAllKeys"

/**
Retrieves the number of records matching the given key or key range in query.

If successful, request's result will be the count.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/count)
*/
@send
external count: (idbIndex, ~query: any=?) => idbRequest<int> = "count"

/**
Opens a cursor over the records matching query, ordered by direction. If query is null, all records in index are matched.

If successful, request's result will be an IDBCursorWithValue, or null if there were no matching records.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/openCursor)
*/
@send
external openCursor: (
  idbIndex,
  ~query: any=?,
  ~direction: idbCursorDirection=?,
) => idbRequest<any> = "openCursor"

/**
Opens a cursor with key only flag set over the records matching query, ordered by direction. If query is null, all records in index are matched.

If successful, request's result will be an IDBCursor, or null if there were no matching records.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBIndex/openKeyCursor)
*/
@send
external openKeyCursor: (
  idbIndex,
  ~query: any=?,
  ~direction: idbCursorDirection=?,
) => idbRequest<any> = "openKeyCursor"
