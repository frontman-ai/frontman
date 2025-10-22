open WebStorageAPI

/**
Returns the name of the nth key, or null if n is greater than or equal to the number of key/value pairs.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Storage/key)
*/
@send
external key: (storage, int) => Null.t<string> = "key"

/**
Returns the current value associated with the given key, or null if the given key does not exist.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Storage/getItem)
*/
@send
external getItem: (storage, string) => Null.t<string> = "getItem"

/**
Sets the value of the pair identified by key to value, creating a new key/value pair if none existed for key previously.

Throws a "QuotaExceededError" DOMException exception if the new value couldn't be set. (Setting could fail if, e.g., the user has disabled storage for the site, or if the quota has been exceeded.)

Dispatches a storage event on Window objects holding an equivalent Storage object.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Storage/setItem)
*/
@send
external setItem: (storage, ~key: string, ~value: string) => unit = "setItem"

/**
Removes the key/value pair with the given key, if a key/value pair with the given key exists.

Dispatches a storage event on Window objects holding an equivalent Storage object.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Storage/removeItem)
*/
@send
external removeItem: (storage, string) => unit = "removeItem"

/**
Removes all key/value pairs, if there are any.

Dispatches a storage event on Window objects holding an equivalent Storage object.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Storage/clear)
*/
@send
external clear: storage => unit = "clear"
