include EventTarget.Impl({type t = IndexedDbTypes.idbTransaction})

/**
Returns an IDBObjectStore in the transaction's scope.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/objectStore)
*/
@send
external objectStore: (IndexedDbTypes.idbTransaction, string) => IndexedDbTypes.idbObjectStore =
  "objectStore"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/commit)
*/
@send
external commit: IndexedDbTypes.idbTransaction => unit = "commit"

/**
Aborts the transaction. All pending requests will fail with a "AbortError" DOMException and all changes made to the database will be reverted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IDBTransaction/abort)
*/
@send
external abort: IndexedDbTypes.idbTransaction => unit = "abort"
