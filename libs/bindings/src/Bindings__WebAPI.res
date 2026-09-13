external elementFromReact: Dom.element => WebAPI.DomTypes.element = "%identity"
external elementToReact: WebAPI.DomTypes.element => Dom.element = "%identity"

@get
external matchMediaMethod: WebAPI.DomTypes.window => Nullable.t<
  string => WebAPI.DomTypes.mediaQueryList,
> = "matchMedia"

external unsafeHTMLElementFromElement: WebAPI.DomTypes.element => WebAPI.DomTypes.htmlElement =
  "%identity"
external unsafeInputElementFromElement: WebAPI.DomTypes.element => WebAPI.DomTypes.htmlInputElement =
  "%identity"

let htmlElementFromElement = (element: WebAPI.DomTypes.element) =>
  switch element.namespaceURI->Null.toOption {
  | Some("http://www.w3.org/1999/xhtml") => Some(element->unsafeHTMLElementFromElement)
  | _ => None
  }

let inputElementFromElement = (element: WebAPI.DomTypes.element) =>
  switch (element.namespaceURI->Null.toOption, element.tagName) {
  | (Some("http://www.w3.org/1999/xhtml"), "INPUT") => Some(element->unsafeInputElementFromElement)
  | _ => None
  }

@get external locationOrigin: WebAPI.DomTypes.location => string = "origin"

@send
external openPopup: (
  WebAPI.Window.t,
  ~url: string,
  ~target: string,
  ~features: string,
) => Null.t<WebAPI.Window.t> = "open"

external messageSourceFromWindow: WebAPI.Window.t => WebAPI.MessageEvent.messageEventSource =
  "%identity"

external unsafeIframeElementFromElement: WebAPI.DomTypes.element => WebAPI.DomTypes.htmliFrameElement =
  "%identity"

external unsafeElementFromEventTarget: WebAPI.EventTypes.eventTarget => WebAPI.DomTypes.element =
  "%identity"

external unsafeElementFromNode: WebAPI.DomTypes.node => WebAPI.DomTypes.element = "%identity"

@get
external eventTargetNodeType: WebAPI.EventTypes.eventTarget => Nullable.t<int> = "nodeType"

let elementFromEventTarget = target =>
  switch target->eventTargetNodeType->Nullable.toOption {
  | Some(1) => Some(target->unsafeElementFromEventTarget)
  | _ => None
  }

let iframeElementFromElement = (element: WebAPI.DomTypes.element) =>
  switch element.tagName {
  | "IFRAME" => Some(element->unsafeIframeElementFromElement)
  | _ => None
  }

let elementFromNode = node =>
  switch node->WebAPI.Node.nodeType {
  | 1 => Some(node->unsafeElementFromNode)
  | _ => None
  }
