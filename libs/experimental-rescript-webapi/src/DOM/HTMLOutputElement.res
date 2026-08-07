include HTMLElement.Impl({type t = DomTypes.htmlOutputElement})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/checkValidity)
*/
@send
external checkValidity: DomTypes.htmlOutputElement => bool = "checkValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/reportValidity)
*/
@send
external reportValidity: DomTypes.htmlOutputElement => bool = "reportValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/setCustomValidity)
*/
@send
external setCustomValidity: (DomTypes.htmlOutputElement, string) => unit = "setCustomValidity"
