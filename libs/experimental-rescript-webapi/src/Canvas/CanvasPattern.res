type domMatrix2DInit = DomTypes.domMatrix2DInit

@send
external setTransform: (CanvasTypes.canvasPattern, ~transform: domMatrix2DInit=?) => unit =
  "setTransform"

let isInstanceOf = (_: 't): bool => %raw(`param instanceof CanvasPattern`)
