@send
external key: (WebStorageTypes.storage, int) => Null.t<string> = "key"

@send
external getItem: (WebStorageTypes.storage, string) => Null.t<string> = "getItem"

@send
external setItem: (WebStorageTypes.storage, ~key: string, ~value: string) => unit = "setItem"

@send
external removeItem: (WebStorageTypes.storage, string) => unit = "removeItem"

@send
external clear: WebStorageTypes.storage => unit = "clear"
