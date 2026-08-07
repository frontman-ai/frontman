@new
external make: unit => DomTypes.documentFragment = "DocumentFragment"

module Impl = (
  T: {
    type t
  },
) => {
  include Node.Impl({type t = T.t})

  external asDocumentFragment: T.t => DomTypes.documentFragment = "%identity"

  @send
  external append: (T.t, DomTypes.node) => unit = "append"

  @send
  external append2: (T.t, string) => unit = "append"

  @send
  external getElementById: (T.t, string) => null<DomTypes.element> = "getElementById"

  @send
  external prepend: (T.t, DomTypes.node) => unit = "prepend"

  @send
  external prepend2: (T.t, string) => unit = "prepend"

  @send
  external querySelector: (T.t, string) => Null.t<DomTypes.element> = "querySelector"

  @send
  external querySelectorAll: (T.t, string) => DomTypes.nodeList<DomTypes.element> =
    "querySelectorAll"

  @send
  external replaceChildren: (T.t, DomTypes.node) => unit = "replaceChildren"

  @send
  external replaceChildren2: (T.t, string) => unit = "replaceChildren"
}

include Impl({type t = DomTypes.documentFragment})
