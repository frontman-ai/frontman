type t = FetchTypes.response = private {...FetchTypes.response}
type responseInit = FetchTypes.responseInit
type bodyInit = BodyInit.t
type headersInit = HeadersInit.t

@new
external fromNull: (@as(json`null`) _, ~init: responseInit=?) => t = "Response"

@new
external fromString: (string, ~init: responseInit=?) => t = "Response"

@new
external fromArrayBuffer: (ArrayBuffer.t, ~init: responseInit=?) => t = "Response"

@new
external fromTypedArray: (TypedArray.t<'t>, ~init: responseInit=?) => t = "Response"

@new
external fromDataView: (DataView.t, ~init: responseInit=?) => t = "Response"

@new
external fromBlob: (Blob.t, ~init: responseInit=?) => t = "Response"

@new
external fromFile: (File.t, ~init: responseInit=?) => t = "Response"

@new
external fromURLSearchParams: (URLSearchParams.t, ~init: responseInit=?) => t = "Response"

@new
external fromFormData: (FormData.t, ~init: responseInit=?) => t = "Response"

@new
external fromReadableStream: (ReadableStream.t<'t>, ~init: responseInit=?) => t = "Response"

@send
external arrayBuffer: t => promise<ArrayBuffer.t> = "arrayBuffer"

@send
external blob: t => promise<Blob.t> = "blob"

@send
external bytes: t => promise<array<int>> = "bytes"

@send
external formData: t => promise<FormData.t> = "formData"

@send
external json: t => promise<JSON.t> = "json"

@send
external text: t => promise<string> = "text"

@scope("Response")
external error: unit => t = "error"

@scope("Response")
external redirect: (~url: string, ~status: int=?) => t = "redirect"

@scope("Response")
external jsonR: (~data: JSON.t, ~init: responseInit=?) => t = "json"

@send
external clone: t => t = "clone"
