module Impl = (
  T: {
    type t
  },
) => {
  include Node.Impl({type t = T.t})

  external asCharacterData: T.t => DomTypes.characterData = "%identity"

  @send
  external after: (T.t, DomTypes.node) => unit = "after"

  @send
  external after2: (T.t, string) => unit = "after"

  @send
  external appendData: (T.t, string) => unit = "appendData"

  @send
  external before: (T.t, DomTypes.node) => unit = "before"

  @send
  external before2: (T.t, string) => unit = "before"

  @send
  external deleteData: (T.t, ~offset: int, ~count: int) => unit = "deleteData"

  @send
  external insertData: (T.t, ~offset: int, ~data: string) => unit = "insertData"

  @send
  external remove: T.t => unit = "remove"

  @send
  external replaceData: (T.t, ~offset: int, ~count: int, ~data: string) => unit = "replaceData"

  @send
  external replaceWith: (T.t, DomTypes.node) => unit = "replaceWith"

  @send
  external replaceWith2: (T.t, string) => unit = "replaceWith"

  @send
  external substringData: (T.t, ~offset: int, ~count: int) => string = "substringData"
}

include Impl({type t = DomTypes.characterData})
