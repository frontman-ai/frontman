/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageData)
*/
@new
external make: (~sw: int, ~sh: int, ~settings: DomTypes.imageDataSettings=?) => DomTypes.imageData =
  "ImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageData)
*/
@new
external makeWithData: (
  ~data: Uint8ClampedArray.t,
  ~sw: int,
  ~sh: int=?,
  ~settings: DomTypes.imageDataSettings=?,
) => DomTypes.imageData = "ImageData"
