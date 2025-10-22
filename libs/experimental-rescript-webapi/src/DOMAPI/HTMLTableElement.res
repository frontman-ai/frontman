open DOMAPI

include HTMLElement.Impl({type t = htmlTableElement})

/**
Creates an empty caption element in the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/createCaption)
*/
@send
external createCaption: htmlTableElement => htmlTableCaptionElement = "createCaption"

/**
Deletes the caption element and its contents from the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/deleteCaption)
*/
@send
external deleteCaption: htmlTableElement => unit = "deleteCaption"

/**
Returns the tHead element object if successful, or null otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/createTHead)
*/
@send
external createTHead: htmlTableElement => htmlTableSectionElement = "createTHead"

/**
Deletes the tHead element and its contents from the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/deleteTHead)
*/
@send
external deleteTHead: htmlTableElement => unit = "deleteTHead"

/**
Creates an empty tFoot element in the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/createTFoot)
*/
@send
external createTFoot: htmlTableElement => htmlTableSectionElement = "createTFoot"

/**
Deletes the tFoot element and its contents from the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/deleteTFoot)
*/
@send
external deleteTFoot: htmlTableElement => unit = "deleteTFoot"

/**
Creates an empty tBody element in the table.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/createTBody)
*/
@send
external createTBody: htmlTableElement => htmlTableSectionElement = "createTBody"

/**
Creates a new row (tr) in the table, and adds the row to the rows collection.
@param index Number that specifies where to insert the row in the rows collection. The default value is -1, which appends the new row to the end of the rows collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/insertRow)
*/
@send
external insertRow: (htmlTableElement, ~index: int=?) => htmlTableRowElement = "insertRow"

/**
Removes the specified row (tr) from the element and from the rows collection.
@param index Number that specifies the zero-based position in the rows collection of the row to remove.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/deleteRow)
*/
@send
external deleteRow: (htmlTableElement, int) => unit = "deleteRow"
