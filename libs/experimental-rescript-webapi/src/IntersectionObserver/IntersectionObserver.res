/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver)
*/
@new
external make: (
  ~callback: IntersectionObserverTypes.intersectionObserverCallback,
  ~options: IntersectionObserverTypes.intersectionObserverInit=?,
) => IntersectionObserverTypes.intersectionObserver = "IntersectionObserver"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/observe)
*/
@send
external observe: (IntersectionObserverTypes.intersectionObserver, DomTypes.element) => unit =
  "observe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/unobserve)
*/
@send
external unobserve: (IntersectionObserverTypes.intersectionObserver, DomTypes.element) => unit =
  "unobserve"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/disconnect)
*/
@send
external disconnect: IntersectionObserverTypes.intersectionObserver => unit = "disconnect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/takeRecords)
*/
@send
external takeRecords: IntersectionObserverTypes.intersectionObserver => array<
  IntersectionObserverTypes.intersectionObserverEntry,
> = "takeRecords"

module IntersectionObserverRoot = IntersectionObserverRoot
module Types = IntersectionObserverTypes
