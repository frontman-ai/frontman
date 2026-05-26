type entry = {isIntersecting: bool}

type t

type options = {
  mutable root?: Dom.element,
  mutable rootMargin?: string,
  mutable threshold?: array<float>,
}

@new
external make: (array<entry> => unit, options) => t = "IntersectionObserver"

@send
external observe: (t, Dom.element) => unit = "observe"

@send
external disconnect: t => unit = "disconnect"
