@send
external persisted: StorageTypes.storageManager => promise<bool> = "persisted"

@send
external persist: StorageTypes.storageManager => promise<bool> = "persist"

@send
external estimate: StorageTypes.storageManager => promise<StorageTypes.storageEstimate> = "estimate"

@send
external getDirectory: StorageTypes.storageManager => promise<FileTypes.fileSystemDirectoryHandle> =
  "getDirectory"
