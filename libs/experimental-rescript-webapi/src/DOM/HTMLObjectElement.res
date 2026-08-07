include HTMLElement.Impl({type t = DomTypes.htmlObjectElement})

@send
external getSVGDocument: DomTypes.htmlObjectElement => DomTypes.document = "getSVGDocument"

/**
Returns whether a form will validate when it is submitted, without having to submit it.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/checkValidity)
*/
@send
external checkValidity: DomTypes.htmlObjectElement => bool = "checkValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/reportValidity)
*/
@send
external reportValidity: DomTypes.htmlObjectElement => bool = "reportValidity"

/**
Sets a custom error message that is displayed when a form is submitted.
@param error Sets a custom error message that is displayed when a form is submitted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/setCustomValidity)
*/
@send
external setCustomValidity: (DomTypes.htmlObjectElement, string) => unit = "setCustomValidity"
