open DOMAPI

module Impl = (
  T: {
    type t
  },
) => {
  include Node.Impl({type t = T.t})

  external asCharacterData: T.t => characterData = "%identity"

  /**
Inserts nodes just after node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/after)
*/
  @send
  external after: (T.t, node) => unit = "after"

  /**
Inserts nodes just after node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/after)
*/
  @send
  external after2: (T.t, string) => unit = "after"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/appendData)
*/
  @send
  external appendData: (T.t, string) => unit = "appendData"

  /**
Inserts nodes just before node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/before)
*/
  @send
  external before: (T.t, node) => unit = "before"

  /**
Inserts nodes just before node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/before)
*/
  @send
  external before2: (T.t, string) => unit = "before"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/deleteData)
*/
  @send
  external deleteData: (T.t, ~offset: int, ~count: int) => unit = "deleteData"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/insertData)
*/
  @send
  external insertData: (T.t, ~offset: int, ~data: string) => unit = "insertData"

  /**
Removes node.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/remove)
*/
  @send
  external remove: T.t => unit = "remove"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/replaceData)
*/
  @send
  external replaceData: (T.t, ~offset: int, ~count: int, ~data: string) => unit = "replaceData"

  /**
Replaces node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/replaceWith)
*/
  @send
  external replaceWith: (T.t, node) => unit = "replaceWith"

  /**
Replaces node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/replaceWith)
*/
  @send
  external replaceWith2: (T.t, string) => unit = "replaceWith"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/substringData)
*/
  @send
  external substringData: (T.t, ~offset: int, ~count: int) => string = "substringData"
}

include Impl({type t = characterData})
