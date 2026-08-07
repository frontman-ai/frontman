@send
external item: (DomTypes.htmlSelectElement, int) => DomTypes.htmlOptionElement = "item"

@send
external namedItem: (DomTypes.htmlSelectElement, string) => DomTypes.htmlOptionElement = "namedItem"

@send
external add: (DomTypes.htmlSelectElement, ~element: unknown, ~before: unknown=?) => unit = "add"

@send
external removeH: DomTypes.htmlSelectElement => unit = "remove"

@send
external removeH2: (DomTypes.htmlSelectElement, int) => unit = "remove"

@send
external checkValidity: DomTypes.htmlSelectElement => bool = "checkValidity"

@send
external reportValidity: DomTypes.htmlSelectElement => bool = "reportValidity"

@send
external setCustomValidity: (DomTypes.htmlSelectElement, string) => unit = "setCustomValidity"

@send
external showPicker: DomTypes.htmlSelectElement => unit = "showPicker"

include HTMLElement.Impl({type t = DomTypes.htmlSelectElement})
