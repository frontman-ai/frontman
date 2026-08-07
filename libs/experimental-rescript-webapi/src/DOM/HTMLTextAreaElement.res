include HTMLElement.Impl({type t = DomTypes.htmlTextAreaElement})

@send
external checkValidity: DomTypes.htmlTextAreaElement => bool = "checkValidity"

@send
external reportValidity: DomTypes.htmlTextAreaElement => bool = "reportValidity"

@send
external setCustomValidity: (DomTypes.htmlTextAreaElement, string) => unit = "setCustomValidity"

@send
external select: DomTypes.htmlTextAreaElement => unit = "select"

@send
external setRangeText: (DomTypes.htmlTextAreaElement, string) => unit = "setRangeText"

@send
external setRangeText2: (
  DomTypes.htmlTextAreaElement,
  ~replacement: string,
  ~start: int,
  ~end: int,
  ~selectionMode: DomTypes.selectionMode=?,
) => unit = "setRangeText"

@send
external setSelectionRange: (
  DomTypes.htmlTextAreaElement,
  ~start: int,
  ~end: int,
  ~direction: string=?,
) => unit = "setSelectionRange"
