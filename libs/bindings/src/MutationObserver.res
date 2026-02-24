type t

type mutationRecord = {
  @as("type") type_: string,
  target: WebAPI.DOMAPI.node,
  addedNodes: array<WebAPI.DOMAPI.node>,
  removedNodes: array<WebAPI.DOMAPI.node>,
  attributeName: Null.t<string>,
  oldValue: Null.t<string>,
}

type observeOptions = {
  "childList": bool,
  "attributes": bool,
  "characterData": bool,
  "subtree": bool,
  "attributeOldValue": bool,
  "characterDataOldValue": bool,
}

@new
external make: (array<mutationRecord> => unit) => t = "MutationObserver"

@send
external observe: (t, WebAPI.DOMAPI.node, observeOptions) => unit = "observe"

@send
external disconnect: t => unit = "disconnect"
