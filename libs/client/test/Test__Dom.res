@set external setInnerHTML: (WebAPI.DomTypes.element, string) => unit = "innerHTML"
@send external click: WebAPI.DomTypes.element => unit = "click"
@get external value: WebAPI.DomTypes.element => string = "value"
@get external disabled: WebAPI.DomTypes.element => bool = "disabled"
@set external actEnvironment: (WebAPI.DomTypes.window, bool) => unit = "IS_REACT_ACT_ENVIRONMENT"

let document = WebAPI.Window.current->WebAPI.Window.document
let body = document->WebAPI.Document.body->Null.getOrThrow->WebAPI.HTMLElement.asElement
let query = (~root=body, selector) => root->WebAPI.Element.querySelector(selector)->Null.getOrThrow
let html = text => body->setInnerHTML(text)
