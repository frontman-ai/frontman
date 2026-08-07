@@warning("-30")

@editor.completeFrom(WebApiStorage)
type storage = private {
  length: int,
}

@editor.completeFrom(StorageEvent)
type storageEvent = private {
  ...EventTypes.event,
  key: Null.t<string>,
  oldValue: Null.t<string>,
  newValue: Null.t<string>,
  url: string,
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
