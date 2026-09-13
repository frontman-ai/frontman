module GetDom = FrontmanAiFrontmanProtocol.FrontmanProtocol__GetDom
module Inspector = FrontmanCore__ElementInspector
module Resolver = FrontmanCore__SelectorResolver

let fullModeMaxBytes = 15_000
let defaultMaxDepth = 1
let defaultMaxNodes = 200
let hardMaxNodes = 500

let inspect = (
  input: GetDom.input,
  ~document: WebAPI.DomTypes.document,
  ~additionalAttributes,
  ~componentForElement,
): result<(GetDom.output, WebAPI.DomTypes.element), string> => {
  let (element, _) = Resolver.resolveBySelector(~doc=document, ~selector=input.selector)
  switch element {
  | None => Error(`No element found for selector: ${input.selector}`)
  | Some(el) =>
    let maxNodes =
      input.maxNodes->Option.getOr(defaultMaxNodes)->Math.Int.min(hardMaxNodes)->Math.Int.max(1)
    let overview = () => {
      let inspection = Inspector.inspect(
        ~element=el,
        ~document,
        ~maxDepth=1,
        ~maxNodes=16,
        ~additionalAttributes,
        ~componentForElement,
      )
      `Target a child selector from this overview instead:\n${inspection.html}`
    }
    let content = switch input.mode->Option.getOr(#simplified) {
    | #full =>
      let elementCount = (el->WebAPI.Element.querySelectorAll("*")).length + 1
      switch elementCount > maxNodes {
      | true =>
        Error(
          `Subtree too large for full mode (${elementCount->Int.toString} elements, limit: ${maxNodes->Int.toString}).\n${overview()}`,
        )
      | false =>
        let raw = el.outerHTML
        let byteSize = Inspector.utf8ByteSize(raw)
        switch byteSize > fullModeMaxBytes {
        | true =>
          Error(
            `HTML too large: ${byteSize->Int.toString} bytes (limit: ${fullModeMaxBytes->Int.toString}). Use simplified mode for an overview, or target a smaller component.\n${overview()}`,
          )
        | false => Ok((raw, elementCount, None))
        }
      }
    | #simplified =>
      let selectedSelector = switch Resolver.classifySelector(input.selector) {
      | CssSelector(_) => Some(input.selector)
      | XPathExpression(_) => None
      }
      let inspection = Inspector.inspect(
        ~element=el,
        ~document,
        ~maxDepth=input.maxDepth->Option.getOr(defaultMaxDepth),
        ~maxNodes,
        ~pierceShadowDom=input.pierceShadowDom->Option.getOr(false),
        ~selectedSelector?,
        ~additionalAttributes,
        ~componentForElement,
      )
      let hint = switch inspection.truncated {
      | true =>
        Some(
          `Output stopped at the ${maxNodes->Int.toString}-node or ${Inspector.maxOutputBytes->Int.toString}-byte limit. Narrow your selector for complete results.`,
        )
      | false => None
      }
      Ok((inspection.html, inspection.nodeCount, hint))
    }
    content->Result.map(((html, nodeCount, hint)) => (
      {GetDom.url: document.url, html, nodeCount, byteSize: Inspector.utf8ByteSize(html), hint},
      el,
    ))
  }
}
