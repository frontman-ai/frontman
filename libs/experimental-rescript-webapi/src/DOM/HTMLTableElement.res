include HTMLElement.Impl({type t = DomTypes.htmlTableElement})

/**
Creates an empty caption element in the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/createCaption)
*/
@send
external createCaption: DomTypes.htmlTableElement => DomTypes.htmlTableCaptionElement =
  "createCaption"

/**
Deletes the caption element and its contents from the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/deleteCaption)
*/
@send
external deleteCaption: DomTypes.htmlTableElement => unit = "deleteCaption"

/**
Returns the tHead element object if successful, or null otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/createTHead)
*/
@send
external createTHead: DomTypes.htmlTableElement => DomTypes.htmlTableSectionElement = "createTHead"

/**
Deletes the tHead element and its contents from the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/deleteTHead)
*/
@send
external deleteTHead: DomTypes.htmlTableElement => unit = "deleteTHead"

/**
Creates an empty tFoot element in the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/createTFoot)
*/
@send
external createTFoot: DomTypes.htmlTableElement => DomTypes.htmlTableSectionElement = "createTFoot"

/**
Deletes the tFoot element and its contents from the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/deleteTFoot)
*/
@send
external deleteTFoot: DomTypes.htmlTableElement => unit = "deleteTFoot"

/**
Creates an empty tBody element in the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/createTBody)
*/
@send
external createTBody: DomTypes.htmlTableElement => DomTypes.htmlTableSectionElement = "createTBody"

/**
Creates a new row (tr) in the table, and adds the row to the rows collection.
@param index Number that specifies where to insert the row in the rows collection. The default value is -1, which appends the new row to the end of the rows collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/insertRow)
*/
@send
external insertRow: (DomTypes.htmlTableElement, ~index: int=?) => DomTypes.htmlTableRowElement =
  "insertRow"

/**
Removes the specified row (tr) from the element and from the rows collection.
@param index Number that specifies the zero-based position in the rows collection of the row to remove.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/deleteRow)
*/
@send
external deleteRow: (DomTypes.htmlTableElement, int) => unit = "deleteRow"
