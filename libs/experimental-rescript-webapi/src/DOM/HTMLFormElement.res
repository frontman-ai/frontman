type t = DomTypes.htmlFormElement

include HTMLElement.Impl({type t = t})

/**
Fires when a FORM is about to be submitted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/submit)
*/
@send
external submit: t => unit = "submit"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/requestSubmit)
*/
@send
external requestSubmit: (t, ~submitter: HTMLElement.t=?) => unit = "requestSubmit"

/**
Fires when the user resets a form.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/reset)
*/
@send
external reset: t => unit = "reset"

/**
Returns whether a form will validate when it is submitted, without having to submit it.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/checkValidity)
*/
@send
external checkValidity: t => bool = "checkValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/reportValidity)
*/
@send
external reportValidity: t => bool = "reportValidity"
