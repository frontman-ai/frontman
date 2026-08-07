type t = DomTypes.window
type windowPostMessageOptions = DomTypes.windowPostMessageOptions

include EventTarget.Impl({type t = t})

external current: t = "window"

@get
external window: t => t = "window"

@get
external self: t => t = "self"

@get
external document: t => DomTypes.document = "document"

@get
external name: t => string = "name"

@get
external location: t => DomTypes.location = "location"

@get
external history: t => HistoryTypes.history = "history"

@get
external navigation: t => Navigation.t = "navigation"

@get
external customElements: t => DomTypes.customElementRegistry = "customElements"

@get
external locationbar: t => DomTypes.barProp = "locationbar"

@get
external menubar: t => DomTypes.barProp = "menubar"

@get
external personalbar: t => DomTypes.barProp = "personalbar"

@get
external scrollbars: t => DomTypes.barProp = "scrollbars"

@get
external statusbar: t => DomTypes.barProp = "statusbar"

@get
external toolbar: t => DomTypes.barProp = "toolbar"

@get
external closed: t => bool = "closed"

@get
external frames: t => t = "frames"

@get
external length: t => int = "length"

@get
external top: t => Null.t<t> = "top"

@get
external opener: t => JSON.t = "opener"

@get
external parent: t => t = "parent"

@get
external frameElement: t => Null.t<DomTypes.element> = "frameElement"

@get
external navigator: t => DomTypes.navigator = "navigator"

@get
external screen: t => DomTypes.screen = "screen"

@get
external visualViewport: t => Null.t<VisualViewport.t> = "visualViewport"

@get
external innerWidth: t => int = "innerWidth"

@get
external innerHeight: t => int = "innerHeight"

@get
external scrollX: t => float = "scrollX"

@get
external scrollY: t => float = "scrollY"

@get
external screenX: t => int = "screenX"

@get
external screenLeft: t => int = "screenLeft"

@get
external screenY: t => int = "screenY"

@get
external screenTop: t => int = "screenTop"

@get
external outerWidth: t => int = "outerWidth"

@get
external outerHeight: t => int = "outerHeight"

@get
external devicePixelRatio: t => float = "devicePixelRatio"

@get
external speechSynthesis: t => WebSpeechTypes.speechSynthesis = "speechSynthesis"

@get
external origin: t => string = "origin"

@get
external isSecureContext: t => bool = "isSecureContext"

@get
external crossOriginIsolated: t => bool = "crossOriginIsolated"

@get
external indexedDB: t => IndexedDbTypes.idbFactory = "indexedDB"

@get
external crypto: t => WebCryptoTypes.crypto = "crypto"

@get
external performance: t => PerformanceTypes.performance = "performance"

@get
external caches: t => WebWorkersTypes.cacheStorage = "caches"

@get
external sessionStorage: t => WebStorageTypes.storage = "sessionStorage"

@get
external localStorage: t => WebStorageTypes.storage = "localStorage"

@send
external reportError: (t, JSON.t) => unit = "reportError"

@send
external btoa: (t, string) => string = "btoa"

@send
external atob: (t, string) => string = "atob"

@send
external setTimeout: (t, ~handler: unit => unit, ~timeout: int=?) => DomTypes.timeoutId =
  "setTimeout"

@send
external clearTimeout: (t, DomTypes.timeoutId) => unit = "clearTimeout"

@send
external setInterval: (t, ~handler: string, ~timeout: int=?) => int = "setInterval"

@send
external setInterval2: (t, ~handler: unit => unit, ~timeout: int=?) => int = "setInterval"

@send
external setIntervalWithCallback: (t, ~handler: unit => unit, ~timeout: int=?) => int =
  "setInterval"

@send
external clearInterval: (t, int) => unit = "clearInterval"

@send
external queueMicrotask: (t, unit => unit) => unit = "queueMicrotask"

@send
external structuredClone: (
  t,
  't,
  ~options: ChannelMessagingTypes.structuredSerializeOptions=?,
) => 't = "structuredClone"

@send
external requestAnimationFrame: (t, float => unit) => int = "requestAnimationFrame"

@send
external cancelAnimationFrame: (t, int) => unit = "cancelAnimationFrame"

@send
external close: t => unit = "close"

@send
external stop: t => unit = "stop"

@send
external focus: t => unit = "focus"

@send
external open_: (t, ~url: string=?, ~target: string=?, ~features: string=?) => t = "open"

@send
external alert: (t, ~message: string=?) => unit = "alert"

@send
external confirm: (t, ~message: string=?) => bool = "confirm"

@send
external prompt: (t, ~message: string=?, ~default: string=?) => string = "prompt"

@send
external print: t => unit = "print"

@send
external postMessage: (
  t,
  ~message: JSON.t,
  ~targetOrigin: string,
  ~transfer: array<Dict.t<string>>=?,
) => unit = "postMessage"

@send
external postMessageWithOptions: (
  t,
  ~message: JSON.t,
  ~options: windowPostMessageOptions=?,
) => unit = "postMessage"

@send
external matchMedia: (t, string) => DomTypes.mediaQueryList = "matchMedia"

@send
external moveTo: (t, ~x: int, ~y: int) => unit = "moveTo"

@send
external moveBy: (t, ~x: int, ~y: int) => unit = "moveBy"

@send
external resizeTo: (t, ~width: int, ~height: int) => unit = "resizeTo"

@send
external resizeBy: (t, ~x: int, ~y: int) => unit = "resizeBy"

@send
external scroll: (t, ~options: DomTypes.scrollToOptions=?) => unit = "scroll"

@send
external scrollXY: (t, ~x: float, ~y: float) => unit = "scroll"

@send
external scrollTo: (t, ~options: DomTypes.scrollToOptions=?) => unit = "scrollTo"

@send
external scrollToXY: (t, ~x: float, ~y: float) => unit = "scrollTo"

@send
external scrollBy: (t, ~options: DomTypes.scrollToOptions=?) => unit = "scrollBy"

@send
external scrollByXY: (t, ~x: float, ~y: float) => unit = "scrollBy"

@send
external getComputedStyle: (
  t,
  ~elt: DomTypes.element,
  ~pseudoElt: string=?,
) => DomTypes.cssStyleDeclaration = "getComputedStyle"

@send
external requestIdleCallback: (
  t,
  ~callback: DomTypes.idleDeadline => unit,
  ~options: DomTypes.idleRequestOptions=?,
) => int = "requestIdleCallback"

@send
external cancelIdleCallback: (t, int) => unit = "cancelIdleCallback"

@send
external getSelection: t => null<DomTypes.selection> = "getSelection"
