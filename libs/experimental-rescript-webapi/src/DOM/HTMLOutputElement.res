include HTMLElement.Impl({type t = DomTypes.htmlOutputElement})

@send
external checkValidity: DomTypes.htmlOutputElement => bool = "checkValidity"

@send
external reportValidity: DomTypes.htmlOutputElement => bool = "reportValidity"

@send
external setCustomValidity: (DomTypes.htmlOutputElement, string) => unit = "setCustomValidity"
