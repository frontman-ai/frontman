open CanvasAPI

/**
Releases imageBitmap's underlying bitmap data.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageBitmap/close)
*/
@send
external close: imageBitmap => unit = "close"
