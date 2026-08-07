@new
external make: (
  ~callback: IntersectionObserverTypes.intersectionObserverCallback,
  ~options: IntersectionObserverTypes.intersectionObserverInit=?,
) => IntersectionObserverTypes.intersectionObserver = "IntersectionObserver"

@send
external observe: (IntersectionObserverTypes.intersectionObserver, DomTypes.element) => unit =
  "observe"

@send
external unobserve: (IntersectionObserverTypes.intersectionObserver, DomTypes.element) => unit =
  "unobserve"

@send
external disconnect: IntersectionObserverTypes.intersectionObserver => unit = "disconnect"

@send
external takeRecords: IntersectionObserverTypes.intersectionObserver => array<
  IntersectionObserverTypes.intersectionObserverEntry,
> = "takeRecords"

module IntersectionObserverRoot = IntersectionObserverRoot
module Types = IntersectionObserverTypes
