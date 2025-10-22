open IndexedDBAPI

/**
Attempts to open a connection to the named database with the current version, or 1 if it does not already exist. If the request is successful request's result will be the connection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBFactory/open)
*/
@send
external open_: (idbFactory, ~name: string, ~version: int=?) => idbOpenDBRequest = "open"

/**
Attempts to delete the named database. If the database already exists and there are open connections that don't close in response to a versionchange event, the request will be blocked until all they close. If the request is successful request's result will be null.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBFactory/deleteDatabase)
*/
@send
external deleteDatabase: (idbFactory, string) => idbOpenDBRequest = "deleteDatabase"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBFactory/databases)
*/
@send
external databases: idbFactory => promise<array<idbDatabaseInfo>> = "databases"

/**
Compares two values as keys. Returns -1 if key1 precedes key2, 1 if key2 precedes key1, and 0 if the keys are equal.

Throws a "DataError" DOMException if either input is not a valid key.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBFactory/cmp)
*/
@send
external cmp: (idbFactory, ~first: JSON.t, ~second: JSON.t) => int = "cmp"
