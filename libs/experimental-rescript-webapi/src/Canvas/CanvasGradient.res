@send
external addColorStop: (CanvasTypes.canvasGradient, ~offset: float, ~color: string) => unit =
  "addColorStop"

let isInstanceOf = (_: 't): bool => %raw(`param instanceof CanvasGradient`)
