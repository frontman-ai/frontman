open DOMAPI
open IntersectionObserverAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver)
*/
@new
external make: (
  ~callback: intersectionObserverCallback,
  ~options: intersectionObserverInit=?,
) => intersectionObserver = "IntersectionObserver"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/observe)
*/
@send
external observe: (intersectionObserver, element) => unit = "observe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/unobserve)
*/
@send
external unobserve: (intersectionObserver, element) => unit = "unobserve"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/disconnect)
*/
@send
external disconnect: intersectionObserver => unit = "disconnect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/takeRecords)
*/
@send
external takeRecords: intersectionObserver => array<intersectionObserverEntry> = "takeRecords"
