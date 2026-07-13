include EventTarget.Impl({type t = CssFontLoadingTypes.fontFaceSet})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/add)
*/
@send
external add: (
  CssFontLoadingTypes.fontFaceSet,
  CssFontLoadingTypes.fontFace,
) => CssFontLoadingTypes.fontFaceSet = "add"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/delete)
*/
@send
external delete: (CssFontLoadingTypes.fontFaceSet, CssFontLoadingTypes.fontFace) => bool = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/clear)
*/
@send
external clear: CssFontLoadingTypes.fontFaceSet => unit = "clear"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/load)
*/
@send
external load: (
  CssFontLoadingTypes.fontFaceSet,
  ~font: string,
  ~text: string=?,
) => promise<array<CssFontLoadingTypes.fontFace>> = "load"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/check)
*/
@send
external check: (CssFontLoadingTypes.fontFaceSet, ~font: string, ~text: string=?) => bool = "check"
