open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace)
*/
@new
external make: (~init: videoColorSpaceInit=?) => videoColorSpace = "VideoColorSpace"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace/toJSON)
*/
@send
external toJSON: videoColorSpace => videoColorSpaceInit = "toJSON"
