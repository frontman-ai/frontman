@send
external createIframe: (
  WebAPI.DomTypes.document,
  @as("iframe") _,
) => WebAPI.DomTypes.htmliFrameElement = "createElement"
@set external setSrc: (WebAPI.DomTypes.htmliFrameElement, string) => unit = "src"
@get
external foreignWindow: WebAPI.DomTypes.htmliFrameElement => Nullable.t<WebAPI.DomTypes.window> =
  "contentWindow"
@get
external optionMarker: WebAPI.DomTypes.window => Nullable.t<int> = "BS_PRIVATE_NESTED_SOME_NONE"
@get external errorName: JsExn.t => string = "name"
@set external setText: (WebAPI.DomTypes.element, string) => unit = "textContent"

let main = async () => {
  let doc = WebAPI.Window.current->WebAPI.Window.document
  let body = doc->WebAPI.Document.body->Null.getOrThrow->WebAPI.HTMLElement.asElement
  let result = doc->WebAPI.Document.createElement("div")
  result->WebAPI.Element.setAttribute(~qualifiedName="id", ~value="test-result")
  let iframe = doc->createIframe
  let outcome = try {
    let childOrigin =
      doc.documentElement->WebAPI.HTMLElement.getAttribute("data-child-origin")->Null.getOrThrow
    let loaded = Promise.make((resolve, _) => {
      iframe->WebAPI.HTMLIFrameElement.addEventListener(WebAPI.EventTypes.Load, _ => resolve())
    })
    iframe->setSrc(childOrigin)
    body->WebAPI.Element.appendChild(iframe->WebAPI.HTMLIFrameElement.asNode)->ignore
    await loaded
    let blocked = try {
      iframe->foreignWindow->Nullable.getOrThrow->optionMarker->ignore
      false
    } catch {
    | exn =>
      exn->JsExn.fromException->Option.mapOr(false, error => error->errorName === "SecurityError")
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
  result->setText(outcome)
  body->WebAPI.Element.appendChild(result->WebAPI.Element.asNode)->ignore
}

main()->ignore
