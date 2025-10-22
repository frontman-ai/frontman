open DOMAPI
open HistoryAPI
open VisualViewportAPI
open WebSpeechAPI
open IndexedDBAPI
open WebCryptoAPI
open PerformanceAPI
open WebWorkersAPI
open WebStorageAPI
open CanvasAPI
open FileAPI
open ChannelMessagingAPI
open FetchAPI
open EventAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/window)
*/
external window: window = "window"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/self)
*/
external self: window = "self"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/document)
*/
external document: document = "document"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/name)
*/
external name: string = "name"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/location)
*/
external location: location = "location"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/history)
*/
external history: history = "history"

/**
Defines a new custom element, mapping the given name to the given constructor as an autonomous custom element.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/customElements)
*/
external customElements: customElementRegistry = "customElements"

/**
Returns true if the location bar is visible; otherwise, returns false.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/locationbar)
*/
external locationbar: barProp = "locationbar"

/**
Returns true if the menu bar is visible; otherwise, returns false.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/menubar)
*/
external menubar: barProp = "menubar"

/**
Returns true if the personal bar is visible; otherwise, returns false.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/personalbar)
*/
external personalbar: barProp = "personalbar"

/**
Returns true if the scrollbars are visible; otherwise, returns false.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollbars)
*/
external scrollbars: barProp = "scrollbars"

/**
Returns true if the status bar is visible; otherwise, returns false.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/statusbar)
*/
external statusbar: barProp = "statusbar"

/**
Returns true if the toolbar is visible; otherwise, returns false.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/toolbar)
*/
external toolbar: barProp = "toolbar"

/**
Returns true if the window has been closed, false otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/closed)
*/
external closed: bool = "closed"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/frames)
*/
external frames: window = "frames"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/length)
*/
external length: int = "length"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/top)
*/
external top: window = "top"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/opener)
*/
external opener: JSON.t = "opener"

/**
Refers to either the parent WindowProxy, or itself.

It can rarely be null e.g. for contentWindow of an iframe that is already removed from the parent.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/parent)
*/
external parent: window = "parent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/frameElement)
*/
external frameElement: element = "frameElement"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/navigator)
*/
external navigator: navigator = "navigator"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screen)
*/
external screen: screen = "screen"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/visualViewport)
*/
external visualViewport: visualViewport = "visualViewport"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/innerWidth)
*/
external innerWidth: int = "innerWidth"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/innerHeight)
*/
external innerHeight: int = "innerHeight"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollX)
*/
external scrollX: float = "scrollX"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollY)
*/
external scrollY: float = "scrollY"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenX)
*/
external screenX: int = "screenX"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenLeft)
*/
external screenLeft: int = "screenLeft"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenY)
*/
external screenY: int = "screenY"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenTop)
*/
external screenTop: int = "screenTop"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/outerWidth)
*/
external outerWidth: int = "outerWidth"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/outerHeight)
*/
external outerHeight: int = "outerHeight"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/devicePixelRatio)
*/
external devicePixelRatio: float = "devicePixelRatio"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/speechSynthesis)
*/
external speechSynthesis: speechSynthesis = "speechSynthesis"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/origin)
*/
external origin: string = "origin"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/isSecureContext)
*/
external isSecureContext: bool = "isSecureContext"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/crossOriginIsolated)
*/
external crossOriginIsolated: bool = "crossOriginIsolated"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/indexedDB)
*/
external indexedDB: idbFactory = "indexedDB"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/crypto)
*/
external crypto: crypto = "crypto"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/performance)
*/
external performance: performance = "performance"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/caches)
*/
external caches: cacheStorage = "caches"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/sessionStorage)
*/
external sessionStorage: storage = "sessionStorage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/localStorage)
*/
external localStorage: storage = "localStorage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/reportError)
*/
external reportError: JSON.t => unit = "reportError"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/btoa)
*/
external btoa: string => string = "btoa"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/atob)
*/
external atob: string => string = "atob"

/**
Executes a function after a delay given in milliseconds expires.

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setTimeout)
*/
external setTimeout: (~handler: unit => unit, ~timeout: int=?) => timeoutId = "setTimeout"

/**
Cancels the execution of a timeout created with setTimeout.

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/clearTimeout)
*/
external clearTimeout: timeoutId => unit = "clearTimeout"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setInterval)
*/
external setInterval: (~handler: string, ~timeout: int=?) => int = "setInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setInterval)
*/
external setInterval2: (~handler: unit => unit, ~timeout: int=?) => int = "setInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/clearInterval)
*/
external clearInterval: int => unit = "clearInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/queueMicrotask)
*/
external queueMicrotask: voidFunction => unit = "queueMicrotask"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap: (
  ~image: htmlImageElement,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap2: (
  ~image: svgImageElement,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap3: (
  ~image: htmlVideoElement,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap4: (
  ~image: htmlCanvasElement,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap5: (
  ~image: imageBitmap,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap6: (
  ~image: offscreenCanvas,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap7: (
  ~image: videoFrame,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap8: (
  ~image: blob,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap9: (
  ~image: imageData,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap10: (
  ~image: htmlImageElement,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap11: (
  ~image: svgImageElement,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap12: (
  ~image: htmlVideoElement,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap13: (
  ~image: htmlCanvasElement,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap14: (
  ~image: imageBitmap,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap15: (
  ~image: offscreenCanvas,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap16: (
  ~image: videoFrame,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap17: (
  ~image: blob,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
external createImageBitmap18: (
  ~image: imageData,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/structuredClone)
*/
external structuredClone: ('t, ~options: structuredSerializeOptions=?) => 't = "structuredClone"

/**
`fetch(string, init)`

Starts the process of fetching a resource from the network,
returning a promise that is fulfilled once the response is available.

```res
let response = await fetch("https://rescript-lang.org")
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/fetch)
*/
external fetch: (string, ~init: requestInit=?) => promise<response> = "fetch"

/**
`fetchWithRequest(request, init)`

Starts the process of fetching a resource from the network,
returning a promise that is fulfilled once the response is available.

```res
let response = await fetch(myRequest)
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/fetch)
*/
external fetchWithRequest: (request, ~init: requestInit=?) => promise<response> = "fetch"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DedicatedWorkerGlobalScope/requestAnimationFrame)
*/
external requestAnimationFrame: frameRequestCallback => int = "requestAnimationFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DedicatedWorkerGlobalScope/cancelAnimationFrame)
*/
external cancelAnimationFrame: int => unit = "cancelAnimationFrame"

/**
Appends an event listener for events whose type attribute value is type. The callback argument sets the callback that will be invoked when the event is dispatched.

The options argument sets listener-specific options. For compatibility this can be a boolean, in which case the method behaves exactly as if the value was specified as options's capture.

When set to true, options's capture prevents callback from being invoked when the event's eventPhase attribute value is BUBBLING_PHASE. When false (or not present), callback will not be invoked when event's eventPhase attribute value is CAPTURING_PHASE. Either way, callback will be invoked if event's eventPhase attribute value is AT_TARGET.

When set to true, options's passive indicates that the callback will not cancel the event by invoking preventDefault(). This is used to enable performance optimizations described in § 2.8 Observing event listeners.

When set to true, options's once indicates that the callback will only be invoked once after which the event listener will be removed.

If an AbortSignal is passed for options's signal, then the event listener will be removed when signal is aborted.

The event listener is appended to target's event listener list and is not appended if it has the same type, callback, and capture.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/addEventListener)
*/
external addEventListener: (
  eventType,
  eventListener<'event>,
  ~options: addEventListenerOptions=?,
) => unit = "addEventListener"

/**
Appends an event listener for events whose type attribute value is type. The callback argument sets the callback that will be invoked when the event is dispatched.

The options argument sets listener-specific options. For compatibility this can be a boolean, in which case the method behaves exactly as if the value was specified as options's capture.

When set to true, options's capture prevents callback from being invoked when the event's eventPhase attribute value is BUBBLING_PHASE. When false (or not present), callback will not be invoked when event's eventPhase attribute value is CAPTURING_PHASE. Either way, callback will be invoked if event's eventPhase attribute value is AT_TARGET.

When set to true, options's passive indicates that the callback will not cancel the event by invoking preventDefault(). This is used to enable performance optimizations described in § 2.8 Observing event listeners.

When set to true, options's once indicates that the callback will only be invoked once after which the event listener will be removed.

If an AbortSignal is passed for options's signal, then the event listener will be removed when signal is aborted.

The event listener is appended to target's event listener list and is not appended if it has the same type, callback, and capture.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/addEventListener)
*/
external addEventListenerWithCapture: (
  eventType,
  eventListener<'event>,
  @as(json`true`) _,
) => unit = "addEventListener"

/**
Removes the event listener in target's event listener list with the same type, callback, and options.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/removeEventListener)
*/
external removeEventListener: (
  eventType,
  eventListener<'event>,
  ~options: eventListenerOptions=?,
) => unit = "removeEventListener"

/**
Removes the event listener in target's event listener list with the same type, callback, and options.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/removeEventListener)
*/
external removeEventListener_useCapture: (
  eventType,
  eventListener<'event>,
  @as(json`true`) _,
) => unit = "removeEventListener"

/**
Dispatches a synthetic event event to target and returns true if either event's cancelable attribute value is false or its preventDefault() method was not invoked, and false otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/dispatchEvent)
*/
external dispatchEvent: event => bool = "dispatchEvent"

/**
Closes the window.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/close)
*/
external close: unit => unit = "close"

/**
Cancels the document load.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/stop)
*/
external stop: unit => unit = "stop"

/**
Moves the focus to the window's browsing context, if any.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/focus)
*/
external focus: unit => unit = "focus"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/open)
*/
external open_: (~url: string=?, ~target: string=?, ~features: string=?) => window = "open"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/alert)
*/
external alert: unit => unit = "alert"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/alert)
*/
external alert2: string => unit = "alert"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/confirm)
*/
external confirm: (~message: string=?) => bool = "confirm"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/prompt)
*/
external prompt: (~message: string=?, ~default: string=?) => string = "prompt"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/print)
*/
external print: unit => unit = "print"

/**
Posts a message to the given window. Messages can be structured objects, e.g. nested objects and arrays, can contain JavaScript values (strings, numbers, Date objects, etc), and can contain certain data objects such as File Blob, FileList, and ArrayBuffer objects.

Objects listed in the transfer member of options are transferred, not just cloned, meaning that they are no longer usable on the sending side.

A target origin can be specified using the targetOrigin member of options. If not provided, it defaults to "/". This default restricts the message to same-origin targets only.

If the origin of the target window doesn't match the given target origin, the message is discarded, to avoid information leakage. To send the message to the target regardless of origin, set the target origin to "*".

Throws a "DataCloneError" DOMException if transfer array contains duplicate objects or if message could not be cloned.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/postMessage)
*/
external postMessage: (
  ~message: JSON.t,
  ~targetOrigin: string,
  ~transfer: array<Dict.t<string>>=?,
) => unit = "postMessage"

/**
Posts a message to the given window. Messages can be structured objects, e.g. nested objects and arrays, can contain JavaScript values (strings, numbers, Date objects, etc), and can contain certain data objects such as File Blob, FileList, and ArrayBuffer objects.

Objects listed in the transfer member of options are transferred, not just cloned, meaning that they are no longer usable on the sending side.

A target origin can be specified using the targetOrigin member of options. If not provided, it defaults to "/". This default restricts the message to same-origin targets only.

If the origin of the target window doesn't match the given target origin, the message is discarded, to avoid information leakage. To send the message to the target regardless of origin, set the target origin to "*".

Throws a "DataCloneError" DOMException if transfer array contains duplicate objects or if message could not be cloned.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/postMessage)
*/
external postMessage2: (~message: JSON.t, ~options: windowPostMessageOptions=?) => unit =
  "postMessage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/matchMedia)
*/
external matchMedia: string => mediaQueryList = "matchMedia"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/moveTo)
*/
external moveTo: (~x: int, ~y: int) => unit = "moveTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/moveBy)
*/
external moveBy: (~x: int, ~y: int) => unit = "moveBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/resizeTo)
*/
external resizeTo: (~width: int, ~height: int) => unit = "resizeTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/resizeBy)
*/
external resizeBy: (~x: int, ~y: int) => unit = "resizeBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scroll)
*/
external scroll: (~options: scrollToOptions=?) => unit = "scroll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scroll)
*/
external scroll2: (~x: float, ~y: float) => unit = "scroll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollTo)
*/
external scrollTo: (~options: scrollToOptions=?) => unit = "scrollTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollTo)
*/
external scrollTo2: (~x: float, ~y: float) => unit = "scrollTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollBy)
*/
external scrollBy: (~options: scrollToOptions=?) => unit = "scrollBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollBy)
*/
external scrollBy2: (~x: float, ~y: float) => unit = "scrollBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/getComputedStyle)
*/
external getComputedStyle: (~elt: element, ~pseudoElt: string=?) => cssStyleDeclaration =
  "getComputedStyle"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/requestIdleCallback)
*/
external requestIdleCallback: (
  ~callback: idleRequestCallback,
  ~options: idleRequestOptions=?,
) => int = "requestIdleCallback"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/cancelIdleCallback)
*/
external cancelIdleCallback: int => unit = "cancelIdleCallback"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/getSelection)
*/
external getSelection: unit => selection = "getSelection"
