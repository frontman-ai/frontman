type decodeError =
  | InvalidCharacters
  | InvalidEncoding

type nodeBuffer

@module("node:buffer") @scope("Buffer")
external bufferFromBase64: (string, @as("base64") _) => nodeBuffer = "from"

@module("node:buffer")
external bufferIsUtf8: nodeBuffer => bool = "isUtf8"

@send
external bufferToBase64: (nodeBuffer, @as("base64") _) => string = "toString"

@send
external bufferToUtf8: (nodeBuffer, @as("utf8") _) => string = "toString"

let sentinelPrefix = "=?base64?"
let sentinelSuffix = "?="
let base64Pattern = /^(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?$/
let safePlainPattern = /^[\x09\x20-\x7E]*$/

let hasEdgeWhitespace = value =>
  value->String.startsWith(" ") ||
  value->String.startsWith("\t") ||
  value->String.endsWith(" ") ||
  value->String.endsWith("\t")

let decodeSentinel = value => {
  let payload =
    value->String.slice(
      ~start=sentinelPrefix->String.length,
      ~end=value->String.length - sentinelSuffix->String.length,
    )

  switch base64Pattern->RegExp.test(payload) {
  | false => Error(InvalidEncoding)
  | true =>
    let buffer = payload->bufferFromBase64
    switch buffer->bufferToBase64 == payload && buffer->bufferIsUtf8 {
    | true => Ok(buffer->bufferToUtf8)
    | false => Error(InvalidEncoding)
    }
  }
}

let decode = (value: string): result<string, decodeError> => {
  switch (value->String.startsWith(sentinelPrefix), value->String.endsWith(sentinelSuffix)) {
  | (true, true) => decodeSentinel(value)
  | _ =>
    switch safePlainPattern->RegExp.test(value) && !hasEdgeWhitespace(value) {
    | true => Ok(value)
    | false => Error(InvalidCharacters)
    }
  }
}
