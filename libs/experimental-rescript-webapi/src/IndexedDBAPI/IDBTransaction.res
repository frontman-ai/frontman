open IndexedDBAPI

include EventTarget.Impl({type t = idbTransaction})

/**
Returns an IDBObjectStore in the transaction's scope.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/objectStore)
*/
@send
external objectStore: (idbTransaction, string) => idbObjectStore = "objectStore"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/commit)
*/
@send
external commit: idbTransaction => unit = "commit"

/**
Aborts the transaction. All pending requests will fail with a "AbortError" DOMException and all changes made to the database will be reverted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/abort)
*/
@send
external abort: idbTransaction => unit = "abort"
