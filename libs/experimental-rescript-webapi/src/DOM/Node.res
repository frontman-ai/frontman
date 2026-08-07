module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external asNode: T.t => DomTypes.node = "%identity"
  external asElement: T.t => DomTypes.element = "%identity"

  @get
  external textContent: T.t => Null.t<string> = "textContent"

  @get
  external nodeType: T.t => int = "nodeType"

  @send
  external getRootNode: (T.t, ~options: DomTypes.getRootNodeOptions=?) => DomTypes.node =
    "getRootNode"

  @send
  external hasChildNodes: T.t => bool = "hasChildNodes"

  @send
  external normalize: T.t => unit = "normalize"

  @send
  external cloneNode: (T.t, ~deep: bool=?) => T.t = "cloneNode"

  @send
  external isEqualNode: (T.t, DomTypes.node) => bool = "isEqualNode"

  @send
  external isSameNode: (T.t, DomTypes.node) => bool = "isSameNode"

  @send
  external compareDocumentPosition: (T.t, DomTypes.node) => int = "compareDocumentPosition"

  @send
  external contains: (T.t, DomTypes.node) => bool = "contains"

  @send
  external lookupPrefix: (T.t, string) => string = "lookupPrefix"

  @send
  external lookupNamespaceURI: (T.t, string) => string = "lookupNamespaceURI"

  @send
  external isDefaultNamespace: (T.t, string) => bool = "isDefaultNamespace"

  @send
  external insertBefore: (T.t, 't, ~child: DomTypes.node) => 't = "insertBefore"

  @send
  external appendChild: (T.t, 't) => 't = "appendChild"

  @send
  external replaceChild: (T.t, ~node: DomTypes.node, 't) => 't = "replaceChild"

  @send
  external removeChild: (T.t, 't) => 't = "removeChild"
}

include Impl({type t = DomTypes.node})
