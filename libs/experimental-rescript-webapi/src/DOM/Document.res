@new
external make: unit => DomTypes.document = "Document"

include Node.Impl({type t = DomTypes.document})

@send
external getElementById: (DomTypes.document, string) => null<DomTypes.element> = "getElementById"

@get
external body: DomTypes.document => Null.t<DomTypes.htmlElement> = "body"

@send
external createCanvasElement_: (DomTypes.document, string) => DomTypes.htmlCanvasElement =
  "createElement"

let createCanvasElement = document => createCanvasElement_(document, "canvas")

@send
external getAnimations: DomTypes.document => array<DomTypes.animation> = "getAnimations"

@send
external prepend: (DomTypes.document, DomTypes.node) => unit = "prepend"

@send
external prepend2: (DomTypes.document, string) => unit = "prepend"

@send
external append: (DomTypes.document, DomTypes.node) => unit = "append"

@send
external append2: (DomTypes.document, string) => unit = "append"

@send
external replaceChildren: (DomTypes.document, DomTypes.node) => unit = "replaceChildren"

@send
external replaceChildren2: (DomTypes.document, string) => unit = "replaceChildren"

@send
external querySelector: (DomTypes.document, string) => Null.t<DomTypes.element> = "querySelector"

@send
external querySelectorAll: (DomTypes.document, string) => DomTypes.nodeList<DomTypes.element> =
  "querySelectorAll"

@send
external createExpression: (
  DomTypes.document,
  ~expression: string,
  ~resolver: DomTypes.xPathNSResolver=?,
) => DomTypes.xPathExpression = "createExpression"

@send
external evaluate: (
  DomTypes.document,
  ~expression: string,
  ~contextNode: DomTypes.node,
  ~resolver: DomTypes.xPathNSResolver=?,
  ~type_: int=?,
  ~result: DomTypes.xPathResult=?,
) => DomTypes.xPathResult = "evaluate"

@send
external getElementsByTagName: (
  DomTypes.document,
  string,
) => DomTypes.htmlCollection<DomTypes.element> = "getElementsByTagName"

@send
external getElementsByTagNameNS: (
  DomTypes.document,
  ~namespace: string,
  ~localName: string,
) => DomTypes.htmlCollection<DomTypes.element> = "getElementsByTagNameNS"

@send
external getElementsByClassName: (
  DomTypes.document,
  string,
) => DomTypes.htmlCollection<DomTypes.element> = "getElementsByClassName"

@send
external createElement: (DomTypes.document, string, ~options: string=?) => DomTypes.element =
  "createElement"

@send
external createElement2: (
  DomTypes.document,
  ~localName: string,
  ~options: DomTypes.elementCreationOptions=?,
) => DomTypes.element = "createElement"

@send
external createElementNS: (
  DomTypes.document,
  ~namespace: string,
  ~qualifiedName: string,
  ~options: string=?,
) => DomTypes.element = "createElementNS"

@send
external createElementNS2: (
  DomTypes.document,
  ~namespace: string,
  ~qualifiedName: string,
  ~options: DomTypes.elementCreationOptions=?,
) => DomTypes.element = "createElementNS"

@send
external createDocumentFragment: DomTypes.document => DomTypes.documentFragment =
  "createDocumentFragment"

@send
external createTextNode: (DomTypes.document, string) => DomTypes.text = "createTextNode"

@send
external createCDATASection: (DomTypes.document, string) => DomTypes.cdataSection =
  "createCDATASection"

@send
external createComment: (DomTypes.document, string) => DomTypes.comment = "createComment"

@send
external createProcessingInstruction: (
  DomTypes.document,
  ~target: string,
  ~data: string,
) => DomTypes.processingInstruction = "createProcessingInstruction"

@send
external importNode: (DomTypes.document, 't, ~deep: bool=?) => 't = "importNode"

@send
external adoptNode: (DomTypes.document, 't) => 't = "adoptNode"

@send
external createAttribute: (DomTypes.document, string) => DomTypes.attr = "createAttribute"

@send
external createAttributeNS: (
  DomTypes.document,
  ~namespace: string,
  ~qualifiedName: string,
) => DomTypes.attr = "createAttributeNS"

@send
external createEvent: (DomTypes.document, string) => EventTypes.event = "createEvent"

@send
external createRange: DomTypes.document => DomTypes.range = "createRange"

@send
external createNodeIterator: (
  DomTypes.document,
  ~root: DomTypes.node,
  ~whatToShow: int=?,
  ~filter: DomTypes.nodeFilter=?,
) => DomTypes.nodeIterator = "createNodeIterator"

@send
external createTreeWalker: (
  DomTypes.document,
  ~root: DomTypes.node,
  ~whatToShow: int=?,
  ~filter: DomTypes.nodeFilter=?,
) => DomTypes.treeWalker = "createTreeWalker"

@send
external startViewTransition: (
  DomTypes.document,
  ~callbackOptions: ViewTransitionsTypes.viewTransitionUpdateCallback=?,
) => ViewTransitionsTypes.viewTransition = "startViewTransition"

@send
external caretPositionFromPoint: (
  DomTypes.document,
  ~x: float,
  ~y: float,
  ~options: DomTypes.caretPositionFromPointOptions=?,
) => DomTypes.caretPosition = "caretPositionFromPoint"

@send
external exitFullscreen: DomTypes.document => promise<unit> = "exitFullscreen"

@scope("Document")
external parseHTMLUnsafe: string => DomTypes.document = "parseHTMLUnsafe"

@send
external getElementsByName: (DomTypes.document, string) => DomTypes.nodeList<DomTypes.htmlElement> =
  "getElementsByName"

@send
external open_: (DomTypes.document, ~unused1: string=?, ~unused2: string=?) => DomTypes.document =
  "open"

@send
external open2: (
  DomTypes.document,
  ~url: string,
  ~name: string,
  ~features: string,
) => DomTypes.window = "open"

@send
external close: DomTypes.document => unit = "close"

@send
external write: (DomTypes.document, string) => unit = "write"

@send
external writeln: (DomTypes.document, string) => unit = "writeln"

@send
external hasFocus: DomTypes.document => bool = "hasFocus"

@send
external exitPictureInPicture: DomTypes.document => promise<unit> = "exitPictureInPicture"

@send
external exitPointerLock: DomTypes.document => unit = "exitPointerLock"

@send
external getSelection: DomTypes.document => null<DomTypes.selection> = "getSelection"

@send
external hasStorageAccess: DomTypes.document => promise<bool> = "hasStorageAccess"

@send
external requestStorageAccess: DomTypes.document => promise<unit> = "requestStorageAccess"

let isInstanceOf = (_: 't): bool => %raw(`param instanceof Document`)
