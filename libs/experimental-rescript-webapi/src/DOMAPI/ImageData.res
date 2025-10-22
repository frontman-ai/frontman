open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageData)
*/
@new
external make: (~sw: int, ~sh: int, ~settings: imageDataSettings=?) => imageData = "ImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageData)
*/
@new
external make2: (
  ~data: array<int>,
  ~sw: int,
  ~sh: int=?,
  ~settings: imageDataSettings=?,
) => imageData = "ImageData"
