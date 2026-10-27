open WebAPI

@module("../dist/bridge.js?raw") external bundle: string = "default"

let window = Window.current
let document = window->Window.document
let failed = ref(false)
window->Window.addEventListener(Error, _ => failed := true)
let script = document->Document.createElement("script")
script->Element.appendChild(document->Document.createTextNode(bundle))->ignore
document.body->HTMLElement.appendChild(script)->ignore
window
->Window.parent
->Window.postMessage(~message=JSON.Encode.bool(!failed.contents), ~targetOrigin="*")
