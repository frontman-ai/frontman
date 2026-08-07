type t = DomTypes.htmlFormElement

include HTMLElement.Impl({type t = t})

@send
external submit: t => unit = "submit"

@send
external requestSubmit: (t, ~submitter: HTMLElement.t=?) => unit = "requestSubmit"

@send
external reset: t => unit = "reset"

@send
external checkValidity: t => bool = "checkValidity"

@send
external reportValidity: t => bool = "reportValidity"
