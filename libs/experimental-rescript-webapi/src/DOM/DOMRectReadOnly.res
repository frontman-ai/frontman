@new
external make: (
  ~x: float=?,
  ~y: float=?,
  ~width: float=?,
  ~height: float=?,
) => DomTypes.domRectReadOnly = "DOMRectReadOnly"

@scope("DOMRectReadOnly")
external fromRect: (~other: DomTypes.domRectInit=?) => DomTypes.domRectReadOnly = "fromRect"

@send
external toJSON: DomTypes.domRectReadOnly => Dict.t<string> = "toJSON"
