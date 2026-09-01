module WebStreams = FrontmanBindings.WebStreams

@val external btoa: string => string = "btoa"
@get_index external byteAt: (Uint8Array.t, int) => int = ""
@get external byteLength: Uint8Array.t => int = "byteLength"

let safeRawPattern = /^[\x20-\x7e]+$/
let sentinelPattern = /^=\?base64\?.*\?=$/

let isSafeRaw = value =>
  safeRawPattern->RegExp.test(value) &&
  value == value->String.trim &&
  !(sentinelPattern->RegExp.test(value))

let base64Utf8 = value => {
  let bytes = WebStreams.makeTextEncoder()->WebStreams.encode(value)
  let binary = ref("")
  for index in 0 to bytes->byteLength - 1 {
    binary := binary.contents ++ String.fromCharCode(bytes->byteAt(index))
  }
  btoa(binary.contents)
}

let encode = value =>
  switch isSafeRaw(value) {
  | true => value
  | false => `=?base64?${base64Utf8(value)}?=`
  }
