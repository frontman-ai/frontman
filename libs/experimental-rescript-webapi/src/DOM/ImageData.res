@new
external make: (~sw: int, ~sh: int, ~settings: DomTypes.imageDataSettings=?) => DomTypes.imageData =
  "ImageData"

@new
external makeWithData: (
  ~data: Uint8ClampedArray.t,
  ~sw: int,
  ~sh: int=?,
  ~settings: DomTypes.imageDataSettings=?,
) => DomTypes.imageData = "ImageData"
