external window: DomTypes.window = "window"

external self: DomTypes.window = "self"

external document: DomTypes.document = "document"

external name: string = "name"

external location: DomTypes.location = "location"

external history: HistoryTypes.history = "history"

external customElements: DomTypes.customElementRegistry = "customElements"

external locationbar: DomTypes.barProp = "locationbar"

external menubar: DomTypes.barProp = "menubar"

external personalbar: DomTypes.barProp = "personalbar"

external scrollbars: DomTypes.barProp = "scrollbars"

external statusbar: DomTypes.barProp = "statusbar"

external toolbar: DomTypes.barProp = "toolbar"

external closed: bool = "closed"

external frames: DomTypes.window = "frames"

external length: int = "length"

external top: DomTypes.window = "top"

external opener: JSON.t = "opener"

external parent: DomTypes.window = "parent"

external frameElement: DomTypes.element = "frameElement"

external navigator: DomTypes.navigator = "navigator"

external screen: DomTypes.screen = "screen"

external visualViewport: VisualViewport.t = "visualViewport"

external innerWidth: int = "innerWidth"

external innerHeight: int = "innerHeight"

external scrollX: float = "scrollX"

external scrollY: float = "scrollY"

external screenX: int = "screenX"

external screenLeft: int = "screenLeft"

external screenY: int = "screenY"

external screenTop: int = "screenTop"

external outerWidth: int = "outerWidth"

external outerHeight: int = "outerHeight"

external devicePixelRatio: float = "devicePixelRatio"

external speechSynthesis: WebSpeechTypes.speechSynthesis = "speechSynthesis"

external origin: string = "origin"

external isSecureContext: bool = "isSecureContext"

external crossOriginIsolated: bool = "crossOriginIsolated"

external indexedDB: IndexedDbTypes.idbFactory = "indexedDB"

external crypto: WebCryptoTypes.crypto = "crypto"

external performance: PerformanceTypes.performance = "performance"

external caches: WebWorkersTypes.cacheStorage = "caches"

external sessionStorage: WebStorageTypes.storage = "sessionStorage"

external localStorage: WebStorageTypes.storage = "localStorage"

external reportError: JSON.t => unit = "reportError"

external btoa: string => string = "btoa"

external atob: string => string = "atob"

external setTimeout: (~handler: unit => unit, ~timeout: int=?) => DomTypes.timeoutId = "setTimeout"

external clearTimeout: DomTypes.timeoutId => unit = "clearTimeout"

external setInterval: (~handler: string, ~timeout: int=?) => int = "setInterval"

external setInterval2: (~handler: unit => unit, ~timeout: int=?) => int = "setInterval"

external clearInterval: int => unit = "clearInterval"

external queueMicrotask: unit => unit => unit = "queueMicrotask"

external structuredClone: ('t, ~options: ChannelMessagingTypes.structuredSerializeOptions=?) => 't =
  "structuredClone"

external requestAnimationFrame: (float => unit) => int = "requestAnimationFrame"

external cancelAnimationFrame: int => unit = "cancelAnimationFrame"

external addEventListener: (
  EventTypes.eventType,
  EventTypes.eventListener<'event>,
  ~options: EventTypes.addEventListenerOptions=?,
) => unit = "addEventListener"

external addEventListenerWithCapture: (
  EventTypes.eventType,
  EventTypes.eventListener<'event>,
  @as(json`true`) _,
) => unit = "addEventListener"

external removeEventListener: (
  EventTypes.eventType,
  EventTypes.eventListener<'event>,
  ~options: EventTypes.eventListenerOptions=?,
) => unit = "removeEventListener"

external removeEventListenerUseCapture: (
  EventTypes.eventType,
  EventTypes.eventListener<'event>,
  @as(json`true`) _,
) => unit = "removeEventListener"

external dispatchEvent: EventTypes.event => bool = "dispatchEvent"

external close: unit => unit = "close"

external stop: unit => unit = "stop"

external focus: unit => unit = "focus"

external open_: (~url: string=?, ~target: string=?, ~features: string=?) => DomTypes.window = "open"

external alert: (~message: string=?) => unit = "alert"

external confirm: (~message: string=?) => bool = "confirm"

external prompt: (~message: string=?, ~default: string=?) => string = "prompt"

external print: unit => unit = "print"

external postMessage: (
  ~message: JSON.t,
  ~targetOrigin: string,
  ~transfer: array<Dict.t<string>>=?,
) => unit = "postMessage"

external postMessageWithOptions: (
  ~message: JSON.t,
  ~options: DomTypes.windowPostMessageOptions=?,
) => unit = "postMessage"

external matchMedia: string => DomTypes.mediaQueryList = "matchMedia"

external moveTo: (~x: int, ~y: int) => unit = "moveTo"

external moveBy: (~x: int, ~y: int) => unit = "moveBy"

external resizeTo: (~width: int, ~height: int) => unit = "resizeTo"

external resizeBy: (~x: int, ~y: int) => unit = "resizeBy"

external scroll: (~options: DomTypes.scrollToOptions=?) => unit = "scroll"

external scroll2: (~x: float, ~y: float) => unit = "scroll"

external scrollTo: (~options: DomTypes.scrollToOptions=?) => unit = "scrollTo"

external scrollTo2: (~x: float, ~y: float) => unit = "scrollTo"

external scrollBy: (~options: DomTypes.scrollToOptions=?) => unit = "scrollBy"

external scrollBy2: (~x: float, ~y: float) => unit = "scrollBy"

external getComputedStyle: (
  ~elt: DomTypes.element,
  ~pseudoElt: string=?,
) => DomTypes.cssStyleDeclaration = "getComputedStyle"

external requestIdleCallback: (
  ~callback: DomTypes.idleDeadline => unit,
  ~options: DomTypes.idleRequestOptions=?,
) => int = "requestIdleCallback"

external cancelIdleCallback: int => unit = "cancelIdleCallback"

external getSelection: unit => null<DomTypes.selection> = "getSelection"
