include HTMLElement.Impl({type t = DomTypes.htmlButtonElement})

/**
Returns whether a form will validate when it is submitted, without having to submit it.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/checkValidity)
*/
@send
external checkValidity: DomTypes.htmlButtonElement => bool = "checkValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/reportValidity)
*/
@send
external reportValidity: DomTypes.htmlButtonElement => bool = "reportValidity"

/**
Sets a custom error message that is displayed when a form is submitted.
@param error Sets a custom error message that is displayed when a form is submitted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/setCustomValidity)
*/
@send
external setCustomValidity: (DomTypes.htmlButtonElement, string) => unit = "setCustomValidity"
