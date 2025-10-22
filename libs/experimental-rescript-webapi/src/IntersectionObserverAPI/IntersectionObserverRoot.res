open DOMAPI
open IntersectionObserverAPI

external fromDocument: document => root = "%identity"
external fromElement: element => root = "%identity"
external fromNull: root = "null"

type decoded =
  | Element(element)
  | Document(document)
  | Null

let decode = (t: root): decoded => {
  open Prelude
  if Element.isInstanceOf(t) {
    Element(t->unsafeConversation)
  } else if Document.isInstanceOf(t) {
    Document(t->unsafeConversation)
  } else {
    Null
  }
}
