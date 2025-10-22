open DOMAPI

include HTMLElement.Impl({type t = htmlObjectElement})

@send
external getSVGDocument: htmlObjectElement => document = "getSVGDocument"

/**
Returns whether a form will validate when it is submitted, without having to submit it.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/checkValidity)
*/
@send
external checkValidity: htmlObjectElement => bool = "checkValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/reportValidity)
*/
@send
external reportValidity: htmlObjectElement => bool = "reportValidity"

/**
Sets a custom error message that is displayed when a form is submitted.
@param error Sets a custom error message that is displayed when a form is submitted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/setCustomValidity)
*/
@send
external setCustomValidity: (htmlObjectElement, string) => unit = "setCustomValidity"
