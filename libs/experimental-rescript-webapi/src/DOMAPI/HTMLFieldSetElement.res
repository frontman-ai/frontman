open DOMAPI

include HTMLElement.Impl({type t = htmlFieldSetElement})

/**
Returns whether a form will validate when it is submitted, without having to submit it.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/checkValidity)
*/
@send
external checkValidity: htmlFieldSetElement => bool = "checkValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/reportValidity)
*/
@send
external reportValidity: htmlFieldSetElement => bool = "reportValidity"

/**
Sets a custom error message that is displayed when a form is submitted.
@param error Sets a custom error message that is displayed when a form is submitted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/setCustomValidity)
*/
@send
external setCustomValidity: (htmlFieldSetElement, string) => unit = "setCustomValidity"
