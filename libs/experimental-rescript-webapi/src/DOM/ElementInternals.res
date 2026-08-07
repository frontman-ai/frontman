@send
external setFormValue: (DomTypes.elementInternals, ~value: unknown, ~state: unknown=?) => unit =
  "setFormValue"

@send
external setValidity: (
  DomTypes.elementInternals,
  ~flags: DomTypes.validityStateFlags=?,
  ~message: string=?,
  ~anchor: DomTypes.htmlElement=?,
) => unit = "setValidity"

@send
external checkValidity: DomTypes.elementInternals => bool = "checkValidity"

@send
external reportValidity: DomTypes.elementInternals => bool = "reportValidity"
