/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range)
*/
@new
external make: unit => DomTypes.range = "Range"

external asAbstractRange: DomTypes.range => DomTypes.abstractRange = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/setStart)
*/
@send
external setStart: (DomTypes.range, ~node: DomTypes.node, ~offset: int) => unit = "setStart"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/setEnd)
*/
@send
external setEnd: (DomTypes.range, ~node: DomTypes.node, ~offset: int) => unit = "setEnd"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/setStartBefore)
*/
@send
external setStartBefore: (DomTypes.range, DomTypes.node) => unit = "setStartBefore"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/setStartAfter)
*/
@send
external setStartAfter: (DomTypes.range, DomTypes.node) => unit = "setStartAfter"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/setEndBefore)
*/
@send
external setEndBefore: (DomTypes.range, DomTypes.node) => unit = "setEndBefore"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/setEndAfter)
*/
@send
external setEndAfter: (DomTypes.range, DomTypes.node) => unit = "setEndAfter"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/collapse)
*/
@send
external collapse: (DomTypes.range, ~toStart: bool=?) => unit = "collapse"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/selectNode)
*/
@send
external selectNode: (DomTypes.range, DomTypes.node) => unit = "selectNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/selectNodeContents)
*/
@send
external selectNodeContents: (DomTypes.range, DomTypes.node) => unit = "selectNodeContents"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/compareBoundaryPoints)
*/
@send
external compareBoundaryPoints: (DomTypes.range, ~how: int, ~sourceRange: DomTypes.range) => int =
  "compareBoundaryPoints"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/deleteContents)
*/
@send
external deleteContents: DomTypes.range => unit = "deleteContents"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/extractContents)
*/
@send
external extractContents: DomTypes.range => DomTypes.documentFragment = "extractContents"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/cloneContents)
*/
@send
external cloneContents: DomTypes.range => DomTypes.documentFragment = "cloneContents"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/insertNode)
*/
@send
external insertNode: (DomTypes.range, DomTypes.node) => unit = "insertNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/surroundContents)
*/
@send
external surroundContents: (DomTypes.range, DomTypes.node) => unit = "surroundContents"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/cloneRange)
*/
@send
external cloneRange: DomTypes.range => DomTypes.range = "cloneRange"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/detach)
*/
@send
external detach: DomTypes.range => unit = "detach"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/isPointInRange)
*/
@send
external isPointInRange: (DomTypes.range, ~node: DomTypes.node, ~offset: int) => bool =
  "isPointInRange"

/**
Returns −1 if the point is before the range, 0 if the point is in the range, and 1 if the point is after the range.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/comparePoint)
*/
@send
external comparePoint: (DomTypes.range, ~node: DomTypes.node, ~offset: int) => int = "comparePoint"

/**
Returns whether range intersects node.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/intersectsNode)
*/
@send
external intersectsNode: (DomTypes.range, DomTypes.node) => bool = "intersectsNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/getClientRects)
*/
@send
external getClientRects: DomTypes.range => DomTypes.domRectList = "getClientRects"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/getBoundingClientRect)
*/
@send
external getBoundingClientRect: DomTypes.range => DomTypes.domRect = "getBoundingClientRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/createContextualFragment)
*/
@send
external createContextualFragment: (DomTypes.range, string) => DomTypes.documentFragment =
  "createContextualFragment"
