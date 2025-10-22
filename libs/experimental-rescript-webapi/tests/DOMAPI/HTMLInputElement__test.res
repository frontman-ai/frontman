open Global

let input: DOMAPI.htmlInputElement =
  document->Document.createElement("input")->Prelude.unsafeConversation
let value = input.value
