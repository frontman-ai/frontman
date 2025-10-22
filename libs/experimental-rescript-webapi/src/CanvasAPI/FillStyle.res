open Prelude
open CanvasAPI

external fromString: string => fillStyle = "%identity"
external fromCanvasGradient: canvasGradient => fillStyle = "%identity"
external fromCanvasPattern: canvasGradient => fillStyle = "%identity"

/**
Represents a decoded version of the abstract `fillStyle` type, used in Context2D.
 */
type decoded =
  | String(string)
  | CanvasGradient(canvasGradient)
  | CanvasPattern(canvasPattern)

let decode = (t: fillStyle): decoded => {
  if CanvasGradient.isInstanceOf(t) {
    CanvasGradient(unsafeConversation(t))
  } else if CanvasPattern.isInstanceOf(t) {
    CanvasPattern(unsafeConversation(t))
  } else {
    String(unsafeConversation(t))
  }
}
