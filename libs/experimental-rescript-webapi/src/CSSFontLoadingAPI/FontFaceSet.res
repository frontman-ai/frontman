open CSSFontLoadingAPI

include EventTarget.Impl({type t = fontFaceSet})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/add)
*/
@send
external add: (fontFaceSet, fontFace) => fontFaceSet = "add"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/delete)
*/
@send
external delete: (fontFaceSet, fontFace) => bool = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/clear)
*/
@send
external clear: fontFaceSet => unit = "clear"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/load)
*/
@send
external load: (fontFaceSet, ~font: string, ~text: string=?) => promise<array<fontFace>> = "load"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/check)
*/
@send
external check: (fontFaceSet, ~font: string, ~text: string=?) => bool = "check"
