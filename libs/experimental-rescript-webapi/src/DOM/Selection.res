/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/getRangeAt)
*/
@send
external getRangeAt: (DomTypes.selection, int) => DomTypes.range = "getRangeAt"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/addRange)
*/
@send
external addRange: (DomTypes.selection, DomTypes.range) => unit = "addRange"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/removeRange)
*/
@send
external removeRange: (DomTypes.selection, DomTypes.range) => unit = "removeRange"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/removeAllRanges)
*/
@send
external removeAllRanges: DomTypes.selection => unit = "removeAllRanges"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/removeAllRanges)
*/
@send
external empty: DomTypes.selection => unit = "empty"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/collapse)
*/
@send
external collapse: (DomTypes.selection, ~node: DomTypes.node, ~offset: int=?) => unit = "collapse"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/collapse)
*/
@send
external setPosition: (DomTypes.selection, ~node: DomTypes.node, ~offset: int=?) => unit =
  "setPosition"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/collapseToStart)
*/
@send
external collapseToStart: DomTypes.selection => unit = "collapseToStart"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/collapseToEnd)
*/
@send
external collapseToEnd: DomTypes.selection => unit = "collapseToEnd"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/extend)
*/
@send
external extend: (DomTypes.selection, ~node: DomTypes.node, ~offset: int=?) => unit = "extend"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/setBaseAndExtent)
*/
@send
external setBaseAndExtent: (
  DomTypes.selection,
  ~anchorNode: DomTypes.node,
  ~anchorOffset: int,
  ~focusNode: DomTypes.node,
  ~focusOffset: int,
) => unit = "setBaseAndExtent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/selectAllChildren)
*/
@send
external selectAllChildren: (DomTypes.selection, DomTypes.node) => unit = "selectAllChildren"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/modify)
*/
@send
external modify: (
  DomTypes.selection,
  ~alter: string=?,
  ~direction: string=?,
  ~granularity: string=?,
) => unit = "modify"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/deleteFromDocument)
*/
@send
external deleteFromDocument: DomTypes.selection => unit = "deleteFromDocument"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/containsNode)
*/
@send
external containsNode: (
  DomTypes.selection,
  ~node: DomTypes.node,
  ~allowPartialContainment: bool=?,
) => bool = "containsNode"
