include HTMLElement.Impl({type t = DomTypes.htmlTableSectionElement})

@send
external insertRow: (
  DomTypes.htmlTableSectionElement,
  ~index: int=?,
) => DomTypes.htmlTableRowElement = "insertRow"

@send
external deleteRow: (DomTypes.htmlTableSectionElement, int) => unit = "deleteRow"
