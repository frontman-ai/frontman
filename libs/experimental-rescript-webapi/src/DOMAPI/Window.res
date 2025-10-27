open DOMAPI
open CanvasAPI
open FileAPI
open ChannelMessagingAPI
open FetchAPI

include EventTarget.Impl({type t = window})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/reportError)
*/
@send
external reportError: (window, JSON.t) => unit = "reportError"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/btoa)
*/
@send
external btoa: (window, string) => string = "btoa"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/atob)
*/
@send
external atob: (window, string) => string = "atob"

/**
Executes a function after a delay given in milliseconds expires.

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setTimeout)
*/
@send
external setTimeout: (window, ~handler: unit => unit, ~timeout: int=?) => timeoutId = "setTimeout"

/**
Cancels the execution of a timeout created with setTimeout.

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/clearTimeout)
*/
@send
external clearTimeout: (window, timeoutId) => unit = "clearTimeout"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setInterval)
*/
@send
external setInterval: (window, ~handler: string, ~timeout: int=?) => int = "setInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/setInterval)
*/
@send
external setInterval2: (window, ~handler: unit => unit, ~timeout: int=?) => int = "setInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/clearInterval)
*/
@send
external clearInterval: (window, int) => unit = "clearInterval"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/queueMicrotask)
*/
@send
external queueMicrotask: (window, voidFunction) => unit = "queueMicrotask"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap: (
  window,
  ~image: htmlImageElement,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap2: (
  window,
  ~image: svgImageElement,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap3: (
  window,
  ~image: htmlVideoElement,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap4: (
  window,
  ~image: htmlCanvasElement,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap5: (
  window,
  ~image: imageBitmap,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap6: (
  window,
  ~image: offscreenCanvas,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap7: (
  window,
  ~image: videoFrame,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap8: (
  window,
  ~image: blob,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap9: (
  window,
  ~image: imageData,
  ~options: imageBitmapOptions=?,
) => promise<imageBitmap> = "createImageBitmap"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/createImageBitmap)
*/
@send
external createImageBitmap10: (
  window,
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
@send
external createImageBitmap11: (
  window,
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
@send
external createImageBitmap12: (
  window,
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
@send
external createImageBitmap13: (
  window,
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
@send
external createImageBitmap14: (
  window,
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
@send
external createImageBitmap15: (
  window,
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
@send
external createImageBitmap16: (
  window,
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
@send
external createImageBitmap17: (
  window,
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
@send
external createImageBitmap18: (
  window,
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
@send
external structuredClone: (window, 't, ~options: structuredSerializeOptions=?) => 't =
  "structuredClone"

/**
`fetch(window, string, init)`

Starts the process of fetching a resource from the network,
returning a promise that is fulfilled once the response is available.

```res
let response = await window->Window.fetch("https://rescript-lang.org")
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/fetch)
*/
@send
external fetch: (window, string, ~init: requestInit=?) => promise<response> = "fetch"

/**
`fetchWithRequest(window, request, init)`

Starts the process of fetching a resource from the network,
returning a promise that is fulfilled once the response is available.

```res
let response = await window->Window.fetch(myRequest)
```
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/fetch)
*/
@send
external fetchWithRequest: (window, request, ~init: requestInit=?) => promise<response> = "fetch"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DedicatedWorkerGlobalScope/requestAnimationFrame)
*/
@send
external requestAnimationFrame: (window, frameRequestCallback) => int = "requestAnimationFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DedicatedWorkerGlobalScope/cancelAnimationFrame)
*/
@send
external cancelAnimationFrame: (window, int) => unit = "cancelAnimationFrame"

/**
Closes the window.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/close)
*/
@send
external close: window => unit = "close"

/**
Cancels the document load.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/stop)
*/
@send
external stop: window => unit = "stop"

/**
Moves the focus to the window's browsing context, if any.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/focus)
*/
@send
external focus: window => unit = "focus"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/open)
*/
@send
external open_: (window, ~url: string=?, ~target: string=?, ~features: string=?) => window = "open"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/alert)
*/
@send
external alert: window => unit = "alert"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/alert)
*/
@send
external alert2: (window, string) => unit = "alert"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/confirm)
*/
@send
external confirm: (window, ~message: string=?) => bool = "confirm"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/prompt)
*/
@send
external prompt: (window, ~message: string=?, ~default: string=?) => string = "prompt"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/print)
*/
@send
external print: window => unit = "print"

/**
Posts a message to the given window. Messages can be structured objects, e.g. nested objects and arrays, can contain JavaScript values (strings, numbers, Date objects, etc), and can contain certain data objects such as File Blob, FileList, and ArrayBuffer objects.

Objects listed in the transfer member of options are transferred, not just cloned, meaning that they are no longer usable on the sending side.

A target origin can be specified using the targetOrigin member of options. If not provided, it defaults to "/". This default restricts the message to same-origin targets only.

If the origin of the target window doesn't match the given target origin, the message is discarded, to avoid information leakage. To send the message to the target regardless of origin, set the target origin to "*".

Throws a "DataCloneError" DOMException if transfer array contains duplicate objects or if message could not be cloned.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/postMessage)
*/
@send
external postMessage: (
  window,
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
@send
external postMessage2: (window, ~message: JSON.t, ~options: windowPostMessageOptions=?) => unit =
  "postMessage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/matchMedia)
*/
@send
external matchMedia: (window, string) => mediaQueryList = "matchMedia"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/moveTo)
*/
@send
external moveTo: (window, ~x: int, ~y: int) => unit = "moveTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/moveBy)
*/
@send
external moveBy: (window, ~x: int, ~y: int) => unit = "moveBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/resizeTo)
*/
@send
external resizeTo: (window, ~width: int, ~height: int) => unit = "resizeTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/resizeBy)
*/
@send
external resizeBy: (window, ~x: int, ~y: int) => unit = "resizeBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scroll)
*/
@send
external scroll: (window, ~options: scrollToOptions=?) => unit = "scroll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scroll)
*/
@send
external scroll2: (window, ~x: float, ~y: float) => unit = "scroll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollTo)
*/
@send
external scrollTo: (window, ~options: scrollToOptions=?) => unit = "scrollTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollTo)
*/
@send
external scrollTo2: (window, ~x: float, ~y: float) => unit = "scrollTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollBy)
*/
@send
external scrollBy: (window, ~options: scrollToOptions=?) => unit = "scrollBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollBy)
*/
@send
external scrollBy2: (window, ~x: float, ~y: float) => unit = "scrollBy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/getComputedStyle)
*/
@send
external getComputedStyle: (window, ~elt: element, ~pseudoElt: string=?) => cssStyleDeclaration =
  "getComputedStyle"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/location)
*/
@get
external location: window => location = "location"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/requestIdleCallback)
*/
@send
external requestIdleCallback: (
  window,
  ~callback: idleRequestCallback,
  ~options: idleRequestOptions=?,
) => int = "requestIdleCallback"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/cancelIdleCallback)
*/
@send
external cancelIdleCallback: (window, int) => unit = "cancelIdleCallback"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/getSelection)
*/
@send
external getSelection: window => selection = "getSelection"
