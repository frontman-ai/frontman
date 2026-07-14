/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragmentFragment)
*/
@new
external make: unit => DomTypes.documentFragment = "DocumentFragment"

module Impl = (
  T: {
    type t
  },
) => {
  include Node.Impl({type t = T.t})

  external asDocumentFragment: T.t => DomTypes.documentFragment = "%identity"

  /**
Inserts nodes after the last child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment/append)
*/
  @send
  external append: (T.t, DomTypes.node) => unit = "append"

  /**
Inserts nodes after the last child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment/append)
*/
  @send
  external append2: (T.t, string) => unit = "append"

  /**
Returns the first element within node's descendants whose ID is elementId.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment/getElementById)
*/
  @send
  external getElementById: (T.t, string) => null<DomTypes.element> = "getElementById"

  /**
Inserts nodes before the first child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment/prepend)
*/
  @send
  external prepend: (T.t, DomTypes.node) => unit = "prepend"

  /**
Inserts nodes before the first child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment/prepend)
*/
  @send
  external prepend2: (T.t, string) => unit = "prepend"

  /**
Returns the first element that is a descendant of node that matches selectors.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment/querySelector)
*/
  @send
  external querySelector: (T.t, string) => Null.t<DomTypes.element> = "querySelector"

  /**
Returns all element descendants of node that match selectors.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment/querySelectorAll)
*/
  @send
  external querySelectorAll: (T.t, string) => DomTypes.nodeList<DomTypes.element> =
    "querySelectorAll"

  /**
Replace all children of node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment/replaceChildren)
*/
  @send
  external replaceChildren: (T.t, DomTypes.node) => unit = "replaceChildren"

  /**
Replace all children of node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment/replaceChildren)
*/
  @send
  external replaceChildren2: (T.t, string) => unit = "replaceChildren"
}

include Impl({type t = DomTypes.documentFragment})
