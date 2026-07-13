/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageManager/persisted)
*/
@send
external persisted: StorageTypes.storageManager => promise<bool> = "persisted"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageManager/persist)
*/
@send
external persist: StorageTypes.storageManager => promise<bool> = "persist"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageManager/estimate)
*/
@send
external estimate: StorageTypes.storageManager => promise<StorageTypes.storageEstimate> = "estimate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StorageManager/getDirectory)
*/
@send
external getDirectory: StorageTypes.storageManager => promise<FileTypes.fileSystemDirectoryHandle> =
  "getDirectory"
