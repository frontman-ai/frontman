include HTMLElement.Impl({type t = DomTypes.htmlButtonElement})

@send
external checkValidity: DomTypes.htmlButtonElement => bool = "checkValidity"

@send
external reportValidity: DomTypes.htmlButtonElement => bool = "reportValidity"

@send
external setCustomValidity: (DomTypes.htmlButtonElement, string) => unit = "setCustomValidity"
