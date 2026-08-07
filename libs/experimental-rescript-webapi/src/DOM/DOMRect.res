@new
external make: (~x: float=?, ~y: float=?, ~width: float=?, ~height: float=?) => DomTypes.domRect =
  "DOMRect"

external asDOMRectReadOnly: DomTypes.domRect => DomTypes.domRectReadOnly = "%identity"
@scope("DOMRect")
external fromRect: (~other: DomTypes.domRectInit=?) => DomTypes.domRectReadOnly = "fromRect"

@send
external toJSON: DomTypes.domRect => Dict.t<string> = "toJSON"

@scope("DOMRect")
external fromRectD: (~other: DomTypes.domRectInit=?) => DomTypes.domRect = "fromRect"
