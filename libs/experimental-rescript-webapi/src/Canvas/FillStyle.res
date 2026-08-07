external fromString: string => CanvasTypes.fillStyle = "%identity"
external fromCanvasGradient: CanvasTypes.canvasGradient => CanvasTypes.fillStyle = "%identity"
external fromCanvasPattern: CanvasTypes.canvasPattern => CanvasTypes.fillStyle = "%identity"

external toString: CanvasTypes.fillStyle => string = "%identity"
external toCanvasGradient: CanvasTypes.fillStyle => CanvasTypes.canvasGradient = "%identity"
external toCanvasPattern: CanvasTypes.fillStyle => CanvasTypes.canvasPattern = "%identity"

/**
Represents a decoded version of the abstract `fillStyle` type, used in Context2D.
 */
type decoded =
  | String(string)
  | CanvasGradient(CanvasTypes.canvasGradient)
  | CanvasPattern(CanvasTypes.canvasPattern)

let decode = (t: CanvasTypes.fillStyle): decoded => {
  if CanvasGradient.isInstanceOf(t) {
    CanvasGradient(toCanvasGradient(t))
  } else if CanvasPattern.isInstanceOf(t) {
    CanvasPattern(toCanvasPattern(t))
  } else {
    String(toString(t))
  }
}
