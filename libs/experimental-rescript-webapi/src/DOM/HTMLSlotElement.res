include HTMLElement.Impl({type t = DomTypes.htmlSlotElement})

@send
external assignedNodes: (
  DomTypes.htmlSlotElement,
  ~options: DomTypes.assignedNodesOptions=?,
) => array<DomTypes.node> = "assignedNodes"

@send
external assignedElements: (
  DomTypes.htmlSlotElement,
  ~options: DomTypes.assignedNodesOptions=?,
) => array<DomTypes.element> = "assignedElements"

@send
external assign: (DomTypes.htmlSlotElement, DomTypes.element) => unit = "assign"

@send
external assign2: (DomTypes.htmlSlotElement, DomTypes.text) => unit = "assign"
