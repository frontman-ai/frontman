open DOMAPI

include HTMLElement.Impl({type t = htmlScriptElement})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/supports_static)
*/
@scope("HTMLScriptElement")
external supports: string => bool = "supports"
