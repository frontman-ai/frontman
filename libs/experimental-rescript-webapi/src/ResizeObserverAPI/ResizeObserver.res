open DOMAPI
open ResizeObserverAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserver)
*/
@new
external make: resizeObserverCallback => resizeObserver = "ResizeObserver"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserver/observe)
*/
@send
external observe: (resizeObserver, ~target: element, ~options: resizeObserverOptions=?) => unit =
  "observe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserver/unobserve)
*/
@send
external unobserve: (resizeObserver, element) => unit = "unobserve"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserver/disconnect)
*/
@send
external disconnect: resizeObserver => unit = "disconnect"
