/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItemList/item)
*/
@send
external item: (UiEventsTypes.dataTransferItemList, int) => UiEventsTypes.dataTransferItem = "item"

/**
Adds a new entry for the given data to the drag data store. If the data is plain text then a type string has to be provided also.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItemList/add)
*/
@send
external add: (
  UiEventsTypes.dataTransferItemList,
  ~data: string,
  ~type_: string,
) => UiEventsTypes.dataTransferItem = "add"

/**
Adds a new entry for the given data to the drag data store. If the data is plain text then a type string has to be provided also.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItemList/add)
*/
@send
external addFile: (
  UiEventsTypes.dataTransferItemList,
  FileTypes.file,
) => UiEventsTypes.dataTransferItem = "add"

/**
Removes the indexth entry in the drag data store.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItemList/remove)
*/
@send
external remove: (UiEventsTypes.dataTransferItemList, int) => unit = "remove"

/**
Removes all the entries in the drag data store.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItemList/clear)
*/
@send
external clear: UiEventsTypes.dataTransferItemList => unit = "clear"
