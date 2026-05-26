open Global

let input: DOMAPI.htmlInputElement =
  document->Document.createElement("input")->Prelude.unsafeConversation
input.value->ignore
