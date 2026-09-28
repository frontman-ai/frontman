@@warning("-30")

/**
This Web WebApiStorage API interface provides access to a particular domain's session or local storage. It allows, for example, the addition, modification, or deletion of stored data items.
[See WebApiStorage on MDN](https://developer.mozilla.org/docs/Web/API/Storage)
*/
@editor.completeFrom(WebApiStorage)
type storage = private {
  /**
    Returns the number of key/value pairs.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Storage/length)
    */
  length: int,
}

/**
A StorageEvent is sent to a window when a storage area it has access to is changed within the context of another document.
[See StorageEvent on MDN](https://developer.mozilla.org/docs/Web/API/StorageEvent)
*/
@editor.completeFrom(StorageEvent)
type storageEvent = private {
  ...EventTypes.event,
  /**
    Returns the key of the storage item being changed.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageEvent/key)
    */
  key: Null.t<string>,
  /**
    Returns the old value of the key of the storage item whose value is being changed.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageEvent/oldValue)
    */
  oldValue: Null.t<string>,
  /**
    Returns the new value of the key of the storage item whose value is being changed.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageEvent/newValue)
    */
  newValue: Null.t<string>,
  /**
    Returns the WebApiURL of the document whose storage item changed.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageEvent/url)
    */
  url: string,
  /**
    Returns the WebApiStorage object that was affected.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageEvent/storageArea)
    */
  storageArea: Null.t<storage>,
}

type storageEventInit = {
  ...EventTypes.eventInit,
  mutable key?: Null.t<string>,
  mutable oldValue?: Null.t<string>,
  mutable newValue?: Null.t<string>,
  mutable url?: string,
  mutable storageArea?: Null.t<storage>,
}
