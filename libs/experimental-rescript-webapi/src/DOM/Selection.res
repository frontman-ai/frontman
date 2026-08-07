@send
external getRangeAt: (DomTypes.selection, int) => DomTypes.range = "getRangeAt"

@send
external addRange: (DomTypes.selection, DomTypes.range) => unit = "addRange"

@send
external removeRange: (DomTypes.selection, DomTypes.range) => unit = "removeRange"

@send
external removeAllRanges: DomTypes.selection => unit = "removeAllRanges"

@send
external empty: DomTypes.selection => unit = "empty"

@send
external collapse: (DomTypes.selection, ~node: DomTypes.node, ~offset: int=?) => unit = "collapse"

@send
external setPosition: (DomTypes.selection, ~node: DomTypes.node, ~offset: int=?) => unit =
  "setPosition"

@send
external collapseToStart: DomTypes.selection => unit = "collapseToStart"

@send
external collapseToEnd: DomTypes.selection => unit = "collapseToEnd"

@send
external extend: (DomTypes.selection, ~node: DomTypes.node, ~offset: int=?) => unit = "extend"

@send
external setBaseAndExtent: (
  DomTypes.selection,
  ~anchorNode: DomTypes.node,
  ~anchorOffset: int,
  ~focusNode: DomTypes.node,
  ~focusOffset: int,
) => unit = "setBaseAndExtent"

@send
external selectAllChildren: (DomTypes.selection, DomTypes.node) => unit = "selectAllChildren"

@send
external modify: (
  DomTypes.selection,
  ~alter: string=?,
  ~direction: string=?,
  ~granularity: string=?,
) => unit = "modify"

@send
external deleteFromDocument: DomTypes.selection => unit = "deleteFromDocument"

@send
external containsNode: (
  DomTypes.selection,
  ~node: DomTypes.node,
  ~allowPartialContainment: bool=?,
) => bool = "containsNode"
