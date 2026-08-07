include HTMLElement.Impl({type t = DomTypes.htmlTableElement})

@send
external createCaption: DomTypes.htmlTableElement => DomTypes.htmlTableCaptionElement =
  "createCaption"

@send
external deleteCaption: DomTypes.htmlTableElement => unit = "deleteCaption"

@send
external createTHead: DomTypes.htmlTableElement => DomTypes.htmlTableSectionElement = "createTHead"

@send
external deleteTHead: DomTypes.htmlTableElement => unit = "deleteTHead"

@send
external createTFoot: DomTypes.htmlTableElement => DomTypes.htmlTableSectionElement = "createTFoot"

@send
external deleteTFoot: DomTypes.htmlTableElement => unit = "deleteTFoot"

@send
external createTBody: DomTypes.htmlTableElement => DomTypes.htmlTableSectionElement = "createTBody"

@send
external insertRow: (DomTypes.htmlTableElement, ~index: int=?) => DomTypes.htmlTableRowElement =
  "insertRow"

@send
external deleteRow: (DomTypes.htmlTableElement, int) => unit = "deleteRow"
