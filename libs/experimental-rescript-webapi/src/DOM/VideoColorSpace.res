/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace)
*/
@new
external make: (~init: DomTypes.videoColorSpaceInit=?) => DomTypes.videoColorSpace =
  "VideoColorSpace"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace/toJSON)
*/
@send
external toJSON: DomTypes.videoColorSpace => DomTypes.videoColorSpaceInit = "toJSON"
