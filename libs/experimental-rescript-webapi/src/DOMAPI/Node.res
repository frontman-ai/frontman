open DOMAPI

module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external asNode: T.t => node = "%identity"

  /**
Returns node's root.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/getRootNode)
*/
  @send
  external getRootNode: (T.t, ~options: getRootNodeOptions=?) => node = "getRootNode"

  /**
Returns whether node has children.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/hasChildNodes)
*/
  @send
  external hasChildNodes: T.t => bool = "hasChildNodes"

  /**
Removes empty exclusive Text nodes and concatenates the data of remaining contiguous exclusive Text nodes into the first of their nodes.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/normalize)
*/
  @send
  external normalize: T.t => unit = "normalize"

  /**
Returns a copy of node. If deep is true, the copy also includes the node's descendants.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/cloneNode)
*/
  @send
  external cloneNode: (T.t, ~deep: bool=?) => T.t = "cloneNode"

  /**
Returns whether node and otherNode have the same properties.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isEqualNode)
*/
  @send
  external isEqualNode: (T.t, node) => bool = "isEqualNode"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isSameNode)
*/
  @send
  external isSameNode: (T.t, node) => bool = "isSameNode"

  /**
Returns a bitmask indicating the position of other relative to node.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/compareDocumentPosition)
*/
  @send
  external compareDocumentPosition: (T.t, node) => int = "compareDocumentPosition"

  /**
Returns true if other is an inclusive descendant of node, and false otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/contains)
*/
  @send
  external contains: (T.t, node) => bool = "contains"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lookupPrefix)
*/
  @send
  external lookupPrefix: (T.t, string) => string = "lookupPrefix"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lookupNamespaceURI)
*/
  @send
  external lookupNamespaceURI: (T.t, string) => string = "lookupNamespaceURI"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isDefaultNamespace)
*/
  @send
  external isDefaultNamespace: (T.t, string) => bool = "isDefaultNamespace"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/insertBefore)
*/
  @send
  external insertBefore: (T.t, 't, ~child: node) => 't = "insertBefore"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/appendChild)
*/
  @send
  external appendChild: (T.t, 't) => 't = "appendChild"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/replaceChild)
*/
  @send
  external replaceChild: (T.t, ~node: node, 't) => 't = "replaceChild"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/removeChild)
*/
  @send
  external removeChild: (T.t, 't) => 't = "removeChild"
}

include Impl({type t = node})
