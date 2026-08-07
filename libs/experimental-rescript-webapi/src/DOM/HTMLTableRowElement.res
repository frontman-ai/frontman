include HTMLElement.Impl({type t = DomTypes.htmlTableRowElement})

@send
external insertCell: (
  DomTypes.htmlTableRowElement,
  ~index: int=?,
) => DomTypes.htmlTableCellElement = "insertCell"

@send
external deleteCell: (DomTypes.htmlTableRowElement, int) => unit = "deleteCell"
