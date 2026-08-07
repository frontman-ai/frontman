@new
external make: unit => DomTypes.range = "Range"

external asAbstractRange: DomTypes.range => DomTypes.abstractRange = "%identity"
@send
external setStart: (DomTypes.range, ~node: DomTypes.node, ~offset: int) => unit = "setStart"

@send
external setEnd: (DomTypes.range, ~node: DomTypes.node, ~offset: int) => unit = "setEnd"

@send
external setStartBefore: (DomTypes.range, DomTypes.node) => unit = "setStartBefore"

@send
external setStartAfter: (DomTypes.range, DomTypes.node) => unit = "setStartAfter"

@send
external setEndBefore: (DomTypes.range, DomTypes.node) => unit = "setEndBefore"

@send
external setEndAfter: (DomTypes.range, DomTypes.node) => unit = "setEndAfter"

@send
external collapse: (DomTypes.range, ~toStart: bool=?) => unit = "collapse"

@send
external selectNode: (DomTypes.range, DomTypes.node) => unit = "selectNode"

@send
external selectNodeContents: (DomTypes.range, DomTypes.node) => unit = "selectNodeContents"

@send
external compareBoundaryPoints: (DomTypes.range, ~how: int, ~sourceRange: DomTypes.range) => int =
  "compareBoundaryPoints"

@send
external deleteContents: DomTypes.range => unit = "deleteContents"

@send
external extractContents: DomTypes.range => DomTypes.documentFragment = "extractContents"

@send
external cloneContents: DomTypes.range => DomTypes.documentFragment = "cloneContents"

@send
external insertNode: (DomTypes.range, DomTypes.node) => unit = "insertNode"

@send
external surroundContents: (DomTypes.range, DomTypes.node) => unit = "surroundContents"

@send
external cloneRange: DomTypes.range => DomTypes.range = "cloneRange"

@send
external detach: DomTypes.range => unit = "detach"

@send
external isPointInRange: (DomTypes.range, ~node: DomTypes.node, ~offset: int) => bool =
  "isPointInRange"

@send
external comparePoint: (DomTypes.range, ~node: DomTypes.node, ~offset: int) => int = "comparePoint"

@send
external intersectsNode: (DomTypes.range, DomTypes.node) => bool = "intersectsNode"

@send
external getClientRects: DomTypes.range => DomTypes.domRectList = "getClientRects"

@send
external getBoundingClientRect: DomTypes.range => DomTypes.domRect = "getBoundingClientRect"

@send
external createContextualFragment: (DomTypes.range, string) => DomTypes.documentFragment =
  "createContextualFragment"
