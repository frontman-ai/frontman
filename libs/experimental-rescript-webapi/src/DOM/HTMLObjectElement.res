include HTMLElement.Impl({type t = DomTypes.htmlObjectElement})

@send
external getSVGDocument: DomTypes.htmlObjectElement => DomTypes.document = "getSVGDocument"

@send
external checkValidity: DomTypes.htmlObjectElement => bool = "checkValidity"

@send
external reportValidity: DomTypes.htmlObjectElement => bool = "reportValidity"

@send
external setCustomValidity: (DomTypes.htmlObjectElement, string) => unit = "setCustomValidity"
