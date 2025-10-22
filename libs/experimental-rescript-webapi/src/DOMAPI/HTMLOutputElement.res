open DOMAPI

include HTMLElement.Impl({type t = htmlOutputElement})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/checkValidity)
*/
@send
external checkValidity: htmlOutputElement => bool = "checkValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/reportValidity)
*/
@send
external reportValidity: htmlOutputElement => bool = "reportValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/setCustomValidity)
*/
@send
external setCustomValidity: (htmlOutputElement, string) => unit = "setCustomValidity"
