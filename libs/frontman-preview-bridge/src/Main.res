type document
type script
type browserWindow

@val external document: document = "document"
@get external currentScript: document => Nullable.t<script> = "currentScript"
@send external getAttribute: (script, string) => Nullable.t<string> = "getAttribute"
@val external currentWindow: browserWindow = "window"
@get external parentWindow: browserWindow => browserWindow = "parent"

let requiredAttribute = (script, name) => {
  switch getAttribute(script, name)->Nullable.toOption {
  | Some(value) if value !== "" => value
  | Some(_) | None => JsError.throwWithMessage(`Frontman preview bridge requires ${name}`)
  }
}

let script =
  currentScript(document)
  ->Nullable.toOption
  ->Option.getOrThrow(~message="Frontman preview bridge requires document.currentScript")
let parentOrigin = requiredAttribute(script, "data-frontman-parent-origin")
let channel = requiredAttribute(script, "data-frontman-channel")

FrontmanPreviewBridge.install({
  parentWindow: parentWindow(currentWindow),
  parentOrigin,
  channel,
})->ignore
