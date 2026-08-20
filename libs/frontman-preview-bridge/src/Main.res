let requiredAttribute = (script, name) => {
  switch WebAPI.HTMLElement.getAttribute(script, name)->Null.toOption {
  | Some(value) if value !== "" => value
  | Some(_) | None => JsError.throwWithMessage(`Frontman preview bridge requires ${name}`)
  }
}

let document = WebAPI.Window.current->WebAPI.Window.document

let script =
  document.currentScript
  ->Null.toOption
  ->Option.getOrThrow(~message="Frontman preview bridge requires document.currentScript")
let parentOrigin = requiredAttribute(script, "data-frontman-parent-origin")
let channel = requiredAttribute(script, "data-frontman-channel")

FrontmanPreviewBridge.install({
  parentOrigin,
  channel,
})->ignore
