include EventTarget.Impl({type t = IndexedDbTypes.idbTransaction})

@send
external objectStore: (IndexedDbTypes.idbTransaction, string) => IndexedDbTypes.idbObjectStore =
  "objectStore"

@send
external commit: IndexedDbTypes.idbTransaction => unit = "commit"

@send
external abort: IndexedDbTypes.idbTransaction => unit = "abort"
