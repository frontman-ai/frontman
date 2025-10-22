open CanvasAPI

/**
Adds a color stop with the given color to the gradient at the given offset. 0.0 is the offset at one end of the gradient, 1.0 is the offset at the other end.

Throws an "IndexSizeError" DOMException if the offset is out of range. Throws a "SyntaxError" DOMException if the color cannot be parsed.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasGradient/addColorStop)
*/
@send
external addColorStop: (canvasGradient, ~offset: float, ~color: string) => unit = "addColorStop"

let isInstanceOf = (_: 't): bool => %raw(`param instanceof CanvasGradient`)
