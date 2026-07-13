/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserver)
*/
@new
external make: ResizeObserverTypes.resizeObserverCallback => ResizeObserverTypes.resizeObserver =
  "ResizeObserver"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserver/observe)
*/
@send
external observe: (
  ResizeObserverTypes.resizeObserver,
  ~target: DomTypes.element,
  ~options: ResizeObserverTypes.resizeObserverOptions=?,
) => unit = "observe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserver/unobserve)
*/
@send
external unobserve: (ResizeObserverTypes.resizeObserver, DomTypes.element) => unit = "unobserve"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserver/disconnect)
*/
@send
external disconnect: ResizeObserverTypes.resizeObserver => unit = "disconnect"

module Types = ResizeObserverTypes
