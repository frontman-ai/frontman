let dataView: DataView.t = Obj.magic()
let arrayBuffer: ArrayBuffer.t = Obj.magic()

let _fromString = FontFace.fromString(~family="Inter", ~source="url(/fonts/inter.woff2)")

let _fromDataView = FontFace.fromDataView(~family="Inter", ~source=dataView)

let _fromArrayBuffer = FontFace.fromArrayBuffer(~family="Inter", ~source=arrayBuffer)
