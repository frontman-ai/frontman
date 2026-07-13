type t = DOM.domException

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMException)
*/
@new
external make: (~message: string=?, ~name: string=?) => t = "DOMException"
