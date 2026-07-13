/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData)
*/
type t = FetchTypes.formData = private {...FetchTypes.formData}
type formDataEntryValue = FormDataEntryValue.t

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData)
*/
@new
external make: (~form: 'form=?, ~submitter: 'submitter=?) => t = "FormData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/append)
*/
@send
external append: (t, ~name: string, ~value: string) => unit = "append"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/append)
*/
@send
external appendBlob: (t, ~name: string, ~blobValue: Blob.t, ~filename: string=?) => unit = "append"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/delete)
*/
@send
external delete: (t, string) => unit = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/get)
*/
@send
external get: (t, string) => null<formDataEntryValue> = "get"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/getAll)
*/
@send
external getAll: (t, string) => array<formDataEntryValue> = "getAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/has)
*/
@send
external has: (t, string) => bool = "has"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/entries)
*/
@send
external entries: t => Iterator.t<(string, formDataEntryValue)> = "entries"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/keys)
*/
@send
external keys: t => Iterator.t<string> = "keys"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/set)
*/
@send
external set: (t, ~name: string, ~value: string) => unit = "set"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FormData/set)
*/
@send
external setBlob: (t, ~name: string, ~blobValue: Blob.t, ~filename: string=?) => unit = "set"
