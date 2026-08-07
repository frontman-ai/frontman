type t = FetchTypes.formData = private {...FetchTypes.formData}
type formDataEntryValue = FormDataEntryValue.t

@new
external make: (~form: 'form=?, ~submitter: 'submitter=?) => t = "FormData"

@send
external append: (t, ~name: string, ~value: string) => unit = "append"

@send
external appendBlob: (t, ~name: string, ~blobValue: Blob.t, ~filename: string=?) => unit = "append"

@send
external delete: (t, string) => unit = "delete"

@send
external get: (t, string) => null<formDataEntryValue> = "get"

@send
external getAll: (t, string) => array<formDataEntryValue> = "getAll"

@send
external has: (t, string) => bool = "has"

@send
external entries: t => Iterator.t<(string, formDataEntryValue)> = "entries"

@send
external keys: t => Iterator.t<string> = "keys"

@send
external set: (t, ~name: string, ~value: string) => unit = "set"

@send
external setBlob: (t, ~name: string, ~blobValue: Blob.t, ~filename: string=?) => unit = "set"
