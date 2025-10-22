open DOMAPI

include HTMLElement.Impl({type t = htmlSlotElement})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement/assignedNodes)
*/
@send
external assignedNodes: (htmlSlotElement, ~options: assignedNodesOptions=?) => array<node> =
  "assignedNodes"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement/assignedElements)
*/
@send
external assignedElements: (htmlSlotElement, ~options: assignedNodesOptions=?) => array<element> =
  "assignedElements"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement/assign)
*/
@send
external assign: (htmlSlotElement, element) => unit = "assign"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement/assign)
*/
@send
external assign2: (htmlSlotElement, text) => unit = "assign"
