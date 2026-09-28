include HTMLElement.Impl({type t = DomTypes.htmlImageElement})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/decode)
*/
@send
external decode: DomTypes.htmlImageElement => promise<unit> = "decode"
