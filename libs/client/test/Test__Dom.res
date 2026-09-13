module Bindings = FrontmanBindings.Bindings__WebAPI
@set external actEnvironment: (WebAPI.DomTypes.window, bool) => unit = "IS_REACT_ACT_ENVIRONMENT"

let document = WebAPI.Window.current->WebAPI.Window.document
let body = document->WebAPI.Document.body->Null.getOrThrow->WebAPI.HTMLElement.asElement
let query = (~root=body, selector) => root->WebAPI.Element.querySelector(selector)->Null.getOrThrow
let html = text => body.innerHTML = text
let click = element =>
  element->Bindings.htmlElementFromElement->Option.getOrThrow->WebAPI.HTMLElement.click
let value = element => (element->Bindings.inputElementFromElement->Option.getOrThrow).value
let disabled = element => element->WebAPI.Element.hasAttribute("disabled")
