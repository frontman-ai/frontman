type t = FetchTypes.request = private {...FetchTypes.request}
type requestInit = FetchTypes.requestInit
type bodyInit = BodyInit.t
type headersInit = HeadersInit.t

@new
external fromURL: (string, ~init: requestInit=?) => t = "Request"

@new
external fromRequest: (t, ~init: requestInit=?) => t = "Request"

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

@send
external clone: t => t = "clone"
