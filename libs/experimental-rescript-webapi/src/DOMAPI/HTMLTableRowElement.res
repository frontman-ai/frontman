open DOMAPI

include HTMLElement.Impl({type t = htmlTableRowElement})

/**
Creates a new cell in the table row, and adds the cell to the cells collection.
@param index Number that specifies where to insert the cell in the tr. The default value is -1, which appends the new cell to the end of the cells collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableRowElement/insertCell)
*/
@send
external insertCell: (htmlTableRowElement, ~index: int=?) => htmlTableCellElement = "insertCell"

/**
Removes the specified cell from the table row, as well as from the cells collection.
@param index Number that specifies the zero-based position of the cell to remove from the table row. If no value is provided, the last cell in the cells collection is deleted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableRowElement/deleteCell)
*/
@send
external deleteCell: (htmlTableRowElement, int) => unit = "deleteCell"
