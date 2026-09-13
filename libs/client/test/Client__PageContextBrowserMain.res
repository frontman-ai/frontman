@get
external optionMarker: WebAPI.DomTypes.window => Nullable.t<int> = "BS_PRIVATE_NESTED_SOME_NONE"

let main = async () => {
  let doc = WebAPI.Window.current->WebAPI.Window.document
  let body = doc->WebAPI.Document.body->Null.getOrThrow->WebAPI.HTMLElement.asElement
  let result = doc->WebAPI.Document.createElement("div")
  result->WebAPI.Element.setAttribute(~qualifiedName="id", ~value="test-result")
  let iframe =
    doc
    ->WebAPI.Document.createElement("iframe")
    ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
    ->Option.getOrThrow
  let outcome = try {
    let childOrigin =
      doc.documentElement->WebAPI.HTMLElement.getAttribute("data-child-origin")->Null.getOrThrow
    let loaded = Promise.make((resolve, _) => {
      iframe->WebAPI.HTMLIFrameElement.addEventListener(WebAPI.EventTypes.Load, _ => resolve())
    })
    iframe.src = childOrigin
    body->WebAPI.Element.appendChild(iframe->WebAPI.HTMLIFrameElement.asNode)->ignore
    await loaded
    let blocked = try {
      iframe.contentWindow->Null.getOrThrow->optionMarker->ignore
      false
    } catch {
    | exn => exn->JsExn.fromException->Option.flatMap(JsExn.name) === Some("SecurityError")
    }
    Client__PageContextBrowser.check(
      blocked,
      "Expected Firefox to block the old option marker access",
    )
    await Client__PageContextBrowser.run(iframe, childOrigin)
    "passed"
  } catch {
  | exn =>
    exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Browser check failed")
  }
  iframe->WebAPI.HTMLIFrameElement.remove
  result.textContent = Null.make(outcome)
  body->WebAPI.Element.appendChild(result->WebAPI.Element.asNode)->ignore
}

main()->ignore
