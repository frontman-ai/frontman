type t = Dict.t<JSON.t>

let maxBytes = 16384
let maxKeys = 64
let reservedTraceKeys = ["traceparent", "tracestate", "baggage"]
let keyPattern = /^(?:[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\/)?(?:[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?)?$(?![\s\S])/
let isValidKey = key => keyPattern->RegExp.test(key)
let isReservedTraceKey = key => reservedTraceKeys->Array.includes(key)

type textEncoder

@new external makeTextEncoder: unit => textEncoder = "TextEncoder"
@send external encode: (textEncoder, string) => Uint8Array.t = "encode"
@get external byteLength: Uint8Array.t => int = "byteLength"
external toJson: t => JSON.t = "%identity"

let jsonSchema: JSONSchema.t = {
  type_: JSONSchema.Arrayable.single(#object),
  maxProperties: maxKeys,
  propertyNames: JSONSchema.Schema({
    allOf: [
      JSONSchema.Schema({pattern: keyPattern->RegExp.source}),
      JSONSchema.Schema({
        not: JSONSchema.Schema({enum: reservedTraceKeys->Array.map(JSON.Encode.string)}),
      }),
    ],
  }),
}

let schema =
  S.dict(S.json)
  ->S.refine(
    value => value->Dict.keysToArray->Array.every(isValidKey),
    ~error="MCP metadata contains an invalid key",
  )
  ->S.refine(
    value => value->Dict.keysToArray->Array.every(key => !isReservedTraceKey(key)),
    ~error="MCP metadata contains reserved trace propagation fields",
  )
  ->S.refine(
    value => value->Dict.keysToArray->Array.length <= maxKeys,
    ~error=`MCP metadata exceeds ${maxKeys->Int.toString} immediate keys`,
  )
  ->S.refine(
    value => makeTextEncoder()->encode(JSON.stringify(value->toJson))->byteLength <= maxBytes,
    ~error=`MCP metadata exceeds ${maxBytes->Int.toString} UTF-8 bytes`,
  )
  ->S.extendJSONSchema(jsonSchema)
