@new
external make: ResizeObserverTypes.resizeObserverCallback => ResizeObserverTypes.resizeObserver =
  "ResizeObserver"

@send
external observe: (
  ResizeObserverTypes.resizeObserver,
  ~target: DomTypes.element,
  ~options: ResizeObserverTypes.resizeObserverOptions=?,
) => unit = "observe"

@send
external unobserve: (ResizeObserverTypes.resizeObserver, DomTypes.element) => unit = "unobserve"

@send
external disconnect: ResizeObserverTypes.resizeObserver => unit = "disconnect"

module Types = ResizeObserverTypes
