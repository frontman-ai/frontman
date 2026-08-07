include HTMLElement.Impl({type t = DomTypes.htmlDialogElement})

/**
Displays the dialog element.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDialogElement/show)
*/
@send
external show: DomTypes.htmlDialogElement => unit = "show"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDialogElement/showModal)
*/
@send
external showModal: DomTypes.htmlDialogElement => unit = "showModal"

/**
Closes the dialog element.

The argument, if provided, provides a return value.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDialogElement/close)
*/
@send
external close: (DomTypes.htmlDialogElement, ~returnValue: string=?) => unit = "close"
