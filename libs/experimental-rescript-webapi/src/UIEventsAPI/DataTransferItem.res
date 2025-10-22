open UIEventsAPI
open FileAPI
open FileAndDirectoryEntriesAPI

/**
Invokes the callback with the string data as the argument, if the drag data item kind is text.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItem/getAsString)
*/
@send
external getAsString: (dataTransferItem, string => unit) => unit = "getAsString"

/**
Returns a File object, if the drag data item kind is File.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItem/getAsFile)
*/
@send
external getAsFile: dataTransferItem => file = "getAsFile"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItem/webkitGetAsEntry)
*/
@send
external webkitGetAsEntry: dataTransferItem => fileSystemEntry = "webkitGetAsEntry"
