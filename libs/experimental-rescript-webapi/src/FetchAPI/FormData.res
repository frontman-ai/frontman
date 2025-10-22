open FetchAPI
open FileAPI
open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData)
*/
@new
external make: (~form: htmlFormElement=?, ~submitter: htmlElement=?) => formData = "FormData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/append)
*/
@send
external append: (formData, ~name: string, ~value: string) => unit = "append"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/append)
*/
@send
external appendBlob: (formData, ~name: string, ~blobValue: blob, ~filename: string=?) => unit =
  "append"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/delete)
*/
@send
external delete: (formData, string) => unit = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/get)
*/
@send
external get: (formData, string) => null<string> = "get"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/get)
*/
@send
external getFile: (formData, string) => null<file> = "get"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/getAll)
*/
@send
external getAll: (formData, string) => array<formDataEntryValue> = "getAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/has)
*/
@send
external has: (formData, string) => bool = "has"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/keys)
*/
@send
external keys: formData => Iterator.t<string> = "keys"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/set)
*/
@send
external set: (formData, ~name: string, ~value: string) => unit = "set"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/set)
*/
@send
external setBlob: (formData, ~name: string, ~blobValue: blob, ~filename: string=?) => unit = "set"
