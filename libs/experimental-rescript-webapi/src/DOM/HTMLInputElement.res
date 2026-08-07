include HTMLElement.Impl({type t = DomTypes.htmlInputElement})

@send
external stepUp: (DomTypes.htmlInputElement, ~n: int=?) => unit = "stepUp"

@send
external stepDown: (DomTypes.htmlInputElement, ~n: int=?) => unit = "stepDown"

@send
external checkValidity: DomTypes.htmlInputElement => bool = "checkValidity"

@send
external reportValidity: DomTypes.htmlInputElement => bool = "reportValidity"

@send
external setCustomValidity: (DomTypes.htmlInputElement, string) => unit = "setCustomValidity"

@send
external select: DomTypes.htmlInputElement => unit = "select"

@send
external setRangeText: (DomTypes.htmlInputElement, string) => unit = "setRangeText"

@send
external setRangeText2: (
  DomTypes.htmlInputElement,
  ~replacement: string,
  ~start: int,
  ~end: int,
  ~selectionMode: DomTypes.selectionMode=?,
) => unit = "setRangeText"

@send
external setSelectionRange: (
  DomTypes.htmlInputElement,
  ~start: int,
  ~end: int,
  ~direction: string=?,
) => unit = "setSelectionRange"

@send
external showPicker: DomTypes.htmlInputElement => unit = "showPicker"
