@new
external make: (~x: float=?, ~y: float=?, ~z: float=?, ~w: float=?) => DomTypes.domPoint =
  "DOMPoint"

external asDOMPointReadOnly: DomTypes.domPoint => DomTypes.domPointReadOnly = "%identity"
@scope("DOMPoint")
external fromPoint: (~other: DomTypes.domPointInit=?) => DomTypes.domPointReadOnly = "fromPoint"

@send
external matrixTransform: (
  DomTypes.domPoint,
  ~matrix: DomTypes.domMatrixInit=?,
) => DomTypes.domPoint = "matrixTransform"

@send
external toJSON: DomTypes.domPoint => Dict.t<string> = "toJSON"

@scope("DOMPoint")
external fromPointD: (~other: DomTypes.domPointInit=?) => DomTypes.domPoint = "fromPoint"
