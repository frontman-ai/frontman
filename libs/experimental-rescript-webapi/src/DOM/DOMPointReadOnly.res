@new
external make: (~x: float=?, ~y: float=?, ~z: float=?, ~w: float=?) => DomTypes.domPointReadOnly =
  "DOMPointReadOnly"

@scope("DOMPointReadOnly")
external fromPoint: (~other: DomTypes.domPointInit=?) => DomTypes.domPointReadOnly = "fromPoint"

@send
external matrixTransform: (
  DomTypes.domPointReadOnly,
  ~matrix: DomTypes.domMatrixInit=?,
) => DomTypes.domPoint = "matrixTransform"

@send
external toJSON: DomTypes.domPointReadOnly => Dict.t<string> = "toJSON"
