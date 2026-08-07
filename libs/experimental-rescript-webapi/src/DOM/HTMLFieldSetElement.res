include HTMLElement.Impl({type t = DomTypes.htmlFieldSetElement})

@send
external checkValidity: DomTypes.htmlFieldSetElement => bool = "checkValidity"

@send
external reportValidity: DomTypes.htmlFieldSetElement => bool = "reportValidity"

@send
external setCustomValidity: (DomTypes.htmlFieldSetElement, string) => unit = "setCustomValidity"
