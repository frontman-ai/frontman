type t = DomTypes.window
type windowPostMessageOptions = DomTypes.windowPostMessageOptions

include EventTarget.Impl({type t = t})

external current: t = "window"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/window)
    */
@get
external window: t => t = "window"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/self)
    */
@get
external self: t => t = "self"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/document)
    */
@get
external document: t => DomTypes.document = "document"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/name)
    */
@get
external name: t => string = "name"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/location)
    */
@get
external location: t => DomTypes.location = "location"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/history)
    */
@get
external history: t => HistoryTypes.history = "history"

@get
external navigation: t => Navigation.t = "navigation"

/**
    Defines a new custom element, mapping the given name to the given constructor as an autonomous custom element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/customElements)
    */
@get
external customElements: t => DomTypes.customElementRegistry = "customElements"

/**
    Returns true if the location bar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/locationbar)
    */
@get
external locationbar: t => DomTypes.barProp = "locationbar"

/**
    Returns true if the menu bar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/menubar)
    */
@get
external menubar: t => DomTypes.barProp = "menubar"

/**
    Returns true if the personal bar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/personalbar)
    */
@get
external personalbar: t => DomTypes.barProp = "personalbar"

/**
    Returns true if the scrollbars are visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollbars)
    */
@get
external scrollbars: t => DomTypes.barProp = "scrollbars"

/**
    Returns true if the status bar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/statusbar)
    */
@get
external statusbar: t => DomTypes.barProp = "statusbar"

/**
    Returns true if the toolbar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/toolbar)
    */
@get
external toolbar: t => DomTypes.barProp = "toolbar"

/**
    Returns true if the window has been closed, false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/closed)
    */
@get
external closed: t => bool = "closed"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/frames)
    */
@get
external frames: t => t = "frames"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/length)
    */
@get
external length: t => int = "length"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/top)
    */
@get
external top: t => Null.t<t> = "top"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/opener)
    */
@get
external opener: t => JSON.t = "opener"

/**
    Refers to either the parent WindowProxy, or itself.

It can rarely be null e.g. for contentWindow of an iframe that is already removed from the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/parent)
    */
@get
external parent: t => t = "parent"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/frameElement)
    */
@get
external frameElement: t => Null.t<DomTypes.element> = "frameElement"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/navigator)
    */
@get
external navigator: t => DomTypes.navigator = "navigator"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screen)
    */
@get
external screen: t => DomTypes.screen = "screen"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/visualViewport)
    */
@get
external visualViewport: t => Null.t<VisualViewport.t> = "visualViewport"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/innerWidth)
    */
@get
external innerWidth: t => int = "innerWidth"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/innerHeight)
    */
@get
external innerHeight: t => int = "innerHeight"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollX)
    */
@get
external scrollX: t => float = "scrollX"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollY)
    */
@get
external scrollY: t => float = "scrollY"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenX)
    */
@get
external screenX: t => int = "screenX"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenLeft)
    */
@get
external screenLeft: t => int = "screenLeft"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenY)
    */
@get
external screenY: t => int = "screenY"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenTop)
    */
@get
external screenTop: t => int = "screenTop"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/outerWidth)
    */
@get
external outerWidth: t => int = "outerWidth"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/outerHeight)
    */
@get
external outerHeight: t => int = "outerHeight"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/devicePixelRatio)
    */
@get
external devicePixelRatio: t => float = "devicePixelRatio"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/speechSynthesis)
    */
@get
external speechSynthesis: t => WebSpeechTypes.speechSynthesis = "speechSynthesis"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/origin)
    */
@get
external origin: t => string = "origin"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/isSecureContext)
    */
@get
external isSecureContext: t => bool = "isSecureContext"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/crossOriginIsolated)
    */
@get
external crossOriginIsolated: t => bool = "crossOriginIsolated"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/indexedDB)
    */
@get
external indexedDB: t => IndexedDbTypes.idbFactory = "indexedDB"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/crypto)
    */
@get
external crypto: t => WebCryptoTypes.crypto = "crypto"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/performance)
    */
@get
external performance: t => PerformanceTypes.performance = "performance"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/caches)
    */
@get
external caches: t => WebWorkersTypes.cacheStorage = "caches"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/sessionStorage)
    */
@get
external sessionStorage: t => WebStorageTypes.storage = "sessionStorage"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/localStorage)
    */
@get
external localStorage: t => WebStorageTypes.storage = "localStorage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/reportError)
*/
@send
external reportError: (t, JSON.t) => unit = "reportError"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/btoa)
*/
@send
external btoa: (t, string) => string = "btoa"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/atob)
*/
@send
external atob: (t, string) => string = "atob"

/**
Executes a function after a delay given in milliseconds expires.

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setTimeout)
*/
@send
external setTimeout: (t, ~handler: unit => unit, ~timeout: int=?) => DomTypes.timeoutId =
  "setTimeout"

/**
Cancels the execution of a timeout created with setTimeout.

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/clearTimeout)
*/
@send
external clearTimeout: (t, DomTypes.timeoutId) => unit = "clearTimeout"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setInterval)
*/
@send
external setInterval: (t, ~handler: string, ~timeout: int=?) => int = "setInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setInterval)
*/
@send
external setInterval2: (t, ~handler: unit => unit, ~timeout: int=?) => int = "setInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setInterval)
*/
@send
external setIntervalWithCallback: (t, ~handler: unit => unit, ~timeout: int=?) => int =
  "setInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/clearInterval)
*/
@send
external clearInterval: (t, int) => unit = "clearInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/queueMicrotask)
*/
@send
external queueMicrotask: (t, unit => unit) => unit = "queueMicrotask"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/structuredClone)
*/
@send
external structuredClone: (
  t,
  't,
  ~options: ChannelMessagingTypes.structuredSerializeOptions=?,
) => 't = "structuredClone"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DedicatedWorkerGlobalScope/requestAnimationFrame)
*/
@send
external requestAnimationFrame: (t, float => unit) => int = "requestAnimationFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DedicatedWorkerGlobalScope/cancelAnimationFrame)
*/
@send
external cancelAnimationFrame: (t, int) => unit = "cancelAnimationFrame"

/**
Closes the window.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/close)
*/
@send
external close: t => unit = "close"

/**
Cancels the document load.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/stop)
*/
@send
external stop: t => unit = "stop"

/**
Moves the focus to the window's browsing context, if any.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/focus)
*/
@send
external focus: t => unit = "focus"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/open)
*/
@send
external open_: (t, ~url: string=?, ~target: string=?, ~features: string=?) => t = "open"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/alert)
*/
@send
external alert: (t, ~message: string=?) => unit = "alert"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/confirm)
*/
@send
external confirm: (t, ~message: string=?) => bool = "confirm"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/prompt)
*/
@send
external prompt: (t, ~message: string=?, ~default: string=?) => string = "prompt"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/print)
*/
@send
external print: t => unit = "print"

/**
Posts a message to the given window. Messages can be structured objects, e.g. nested objects and arrays, can contain JavaScript values (strings, numbers, Date objects, etc), and can contain certain data objects such as WebApiFile Blob, FileList, and ArrayBuffer objects.

Objects listed in the transfer member of options are transferred, not just cloned, meaning that they are no longer usable on the sending side.

A target origin can be specified using the targetOrigin member of options. If not provided, it defaults to "/". This default restricts the message to same-origin targets only.

If the origin of the target window doesn't match the given target origin, the message is discarded, to avoid information leakage. To send the message to the target regardless of origin, set the target origin to "*".

Throws a "DataCloneError" DOMException if transfer array contains duplicate objects or if message could not be cloned.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/postMessage)
*/
@send
external postMessage: (
  t,
  ~message: JSON.t,
  ~targetOrigin: string,
  ~transfer: array<Dict.t<string>>=?,
) => unit = "postMessage"

/**
Posts a message to the given window. Messages can be structured objects, e.g. nested objects and arrays, can contain JavaScript values (strings, numbers, Date objects, etc), and can contain certain data objects such as WebApiFile Blob, FileList, and ArrayBuffer objects.

Objects listed in the transfer member of options are transferred, not just cloned, meaning that they are no longer usable on the sending side.

A target origin can be specified using the targetOrigin member of options. If not provided, it defaults to "/". This default restricts the message to same-origin targets only.

If the origin of the target window doesn't match the given target origin, the message is discarded, to avoid information leakage. To send the message to the target regardless of origin, set the target origin to "*".

Throws a "DataCloneError" DOMException if transfer array contains duplicate objects or if message could not be cloned.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/postMessage)
*/
@send
external postMessageWithOptions: (
  t,
  ~message: JSON.t,
  ~options: windowPostMessageOptions=?,
) => unit = "postMessage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/matchMedia)
*/
@send
external matchMedia: (t, string) => DomTypes.mediaQueryList = "matchMedia"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/moveTo)
*/
@send
external moveTo: (t, ~x: int, ~y: int) => unit = "moveTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/moveBy)
*/
@send
external moveBy: (t, ~x: int, ~y: int) => unit = "moveBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/resizeTo)
*/
@send
external resizeTo: (t, ~width: int, ~height: int) => unit = "resizeTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/resizeBy)
*/
@send
external resizeBy: (t, ~x: int, ~y: int) => unit = "resizeBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scroll)
*/
@send
external scroll: (t, ~options: DomTypes.scrollToOptions=?) => unit = "scroll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scroll)
*/
@send
external scrollXY: (t, ~x: float, ~y: float) => unit = "scroll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollTo)
*/
@send
external scrollTo: (t, ~options: DomTypes.scrollToOptions=?) => unit = "scrollTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollTo)
*/
@send
external scrollToXY: (t, ~x: float, ~y: float) => unit = "scrollTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollBy)
*/
@send
external scrollBy: (t, ~options: DomTypes.scrollToOptions=?) => unit = "scrollBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollBy)
*/
@send
external scrollByXY: (t, ~x: float, ~y: float) => unit = "scrollBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/getComputedStyle)
*/
@send
external getComputedStyle: (
  t,
  ~elt: DomTypes.element,
  ~pseudoElt: string=?,
) => DomTypes.cssStyleDeclaration = "getComputedStyle"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/requestIdleCallback)
*/
@send
external requestIdleCallback: (
  t,
  ~callback: DomTypes.idleDeadline => unit,
  ~options: DomTypes.idleRequestOptions=?,
) => int = "requestIdleCallback"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/cancelIdleCallback)
*/
@send
external cancelIdleCallback: (t, int) => unit = "cancelIdleCallback"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/getSelection)
*/
@send
external getSelection: t => null<DomTypes.selection> = "getSelection"
