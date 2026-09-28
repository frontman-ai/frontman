include HTMLElement.Impl({type t = DomTypes.htmlSlotElement})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement/assignedNodes)
*/
@send
external assignedNodes: (
  DomTypes.htmlSlotElement,
  ~options: DomTypes.assignedNodesOptions=?,
) => array<DomTypes.node> = "assignedNodes"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement/assignedElements)
*/
@send
external assignedElements: (
  DomTypes.htmlSlotElement,
  ~options: DomTypes.assignedNodesOptions=?,
) => array<DomTypes.element> = "assignedElements"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement/assign)
*/
@send
external assign: (DomTypes.htmlSlotElement, DomTypes.element) => unit = "assign"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement/assign)
*/
@send
external assign2: (DomTypes.htmlSlotElement, DomTypes.text) => unit = "assign"
