open DOMAPI

include HTMLElement.Impl({type t = htmlImageElement})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/decode)
*/
@send
external decode: htmlImageElement => promise<unit> = "decode"
