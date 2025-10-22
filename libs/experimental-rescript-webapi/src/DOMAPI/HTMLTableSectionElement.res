open DOMAPI

include HTMLElement.Impl({type t = htmlTableSectionElement})

/**
Creates a new row (tr) in the table, and adds the row to the rows collection.
@param index Number that specifies where to insert the row in the rows collection. The default value is -1, which appends the new row to the end of the rows collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableSectionElement/insertRow)
*/
@send
external insertRow: (htmlTableSectionElement, ~index: int=?) => htmlTableRowElement = "insertRow"

/**
Removes the specified row (tr) from the element and from the rows collection.
@param index Number that specifies the zero-based position in the rows collection of the row to remove.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableSectionElement/deleteRow)
*/
@send
external deleteRow: (htmlTableSectionElement, int) => unit = "deleteRow"
