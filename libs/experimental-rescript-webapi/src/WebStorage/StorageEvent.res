include Event.Impl({type t = WebStorageTypes.storageEvent})

@new
external make: (
  ~type_: string,
  ~eventInitDict: WebStorageTypes.storageEventInit=?,
) => WebStorageTypes.storageEvent = "StorageEvent"
