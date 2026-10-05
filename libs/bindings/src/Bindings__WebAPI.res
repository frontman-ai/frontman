external elementFromReact: Dom.element => WebAPI.DomTypes.element = "%identity"

external unsafeHtmlElementFromElement: WebAPI.DomTypes.element => WebAPI.DomTypes.htmlElement =
  "%identity"
external unsafeInputElementFromElement: WebAPI.DomTypes.element => WebAPI.DomTypes.htmlInputElement =
  "%identity"
external unsafeTextAreaElementFromElement: WebAPI.DomTypes.element => WebAPI.DomTypes.htmlTextAreaElement =
  "%identity"

type constructor
type command

@get external inputConstructor: WebAPI.DomTypes.window => constructor = "HTMLInputElement"
@get external textareaConstructor: WebAPI.DomTypes.window => constructor = "HTMLTextAreaElement"
@get external hasExecCommand: WebAPI.DomTypes.document => option<command> = "execCommand"
@send
external execCommand: (WebAPI.DomTypes.document, string, bool, string) => bool = "execCommand"

@get external inputEventConstructor: WebAPI.DomTypes.window => constructor = "InputEvent"
@get external eventConstructor: WebAPI.DomTypes.window => constructor = "Event"
@get external transferConstructor: WebAPI.DomTypes.window => constructor = "DataTransfer"
@get external clipboardConstructor: WebAPI.DomTypes.window => constructor = "ClipboardEvent"
@get external keyboardConstructor: WebAPI.DomTypes.window => constructor = "KeyboardEvent"

@scope("Reflect") @val
external inputEvent: (
  constructor,
  (string, WebAPI.UiEventsTypes.inputEventInit),
) => WebAPI.EventTypes.event = "construct"
@scope("Reflect") @val
external transfer: (constructor, array<string>) => WebAPI.UiEventsTypes.dataTransfer = "construct"
@scope("Reflect") @val
external clipboardEvent: (
  constructor,
  (string, WebAPI.UiEventsTypes.clipboardEventInit),
) => WebAPI.EventTypes.event = "construct"

@scope("Reflect") @val
external keyboardEvent: (
  constructor,
  (string, WebAPI.UiEventsTypes.keyboardEventInit),
) => WebAPI.EventTypes.event = "construct"
@scope("Reflect") @val
external event: (constructor, (string, WebAPI.EventTypes.eventInit)) => WebAPI.EventTypes.event =
  "construct"

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
