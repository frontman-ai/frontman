module Core = FrontmanAiFrontmanCore.FrontmanCore__ElementInspector
let findSelector = Core.findSelector

let componentForDocument = (document: WebAPI.DomTypes.document) =>
  element =>
    Client__ComponentName.getForElement(element, ~window=?document.defaultView->Null.toOption)

let inspect = (
  ~element,
  ~document,
  ~maxDepth,
  ~maxNodes,
  ~pierceShadowDom=false,
  ~selectedSelector=?,
  ~additionalAttributes=[],
) =>
  Core.inspect(
    ~element,
    ~document,
    ~maxDepth,
    ~maxNodes,
    ~pierceShadowDom,
    ~selectedSelector?,
    ~additionalAttributes,
    ~componentForElement=componentForDocument(document),
  )

let describeAncestor = (~element, ~document, ~additionalAttributes) =>
  Core.describeAncestor(
    ~element,
    ~document,
    ~additionalAttributes,
    ~componentForElement=componentForDocument(document),
  )
