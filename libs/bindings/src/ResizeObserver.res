type t

type entry = {contentRect: WebAPI.DOMAPI.domRectReadOnly}

@new
external make: (array<entry> => unit) => t = "ResizeObserver"

@send
external observe: (t, Dom.element) => unit = "observe"

@send
external disconnect: t => unit = "disconnect"
