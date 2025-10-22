open WebStorageAPI

include Event.Impl({type t = storageEvent})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: storageEventInit=?) => storageEvent = "StorageEvent"
