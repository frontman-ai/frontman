type t = FetchTypes.bodyInit

external fromString: string => t = "%identity"

external fromArrayBuffer: ArrayBuffer.t => t = "%identity"

external fromTypedArray: TypedArray.t<'t> => t = "%identity"

external fromDataView: DataView.t => t = "%identity"

external fromBlob: Blob.t => t = "%identity"

external fromFile: File.t => t = "%identity"

external fromURLSearchParams: URLSearchParams.t => t = "%identity"

external fromFormData: FormData.t => t = "%identity"

external fromReadableStream: ReadableStream.t<'t> => t = "%identity"
