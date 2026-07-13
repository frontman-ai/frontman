type t
external fromArrayBuffer: ArrayBuffer.t => t = "%identity"
external fromTypedArray: TypedArray.t<'t> => t = "%identity"
external fromDataView: DataView.t => t = "%identity"
