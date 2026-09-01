type validator

type compileResult = Valid(validator) | Invalid

let schemaDepthLimit = 32
let schemaNodeLimit = 1024
let instanceDepthLimit = 64
let instanceNodeLimit = 65536
let instanceByteLimit = 2097152

@module("./mcp-json-schema.mjs") @return(nullable)
external compileInternal: JSON.t => option<validator> = "compileSchema"

@module("./mcp-json-schema.mjs")
external validateInternal: (validator, JSON.t) => bool = "validateInstance"

@module("./mcp-json-schema.mjs")
external validateBounded: (JSON.t, JSON.t) => promise<bool> = "validateBounded"

let compile = schema =>
  switch compileInternal(schema) {
  | Some(validator) => Valid(validator)
  | None => Invalid
  }

let validate = (validator, value) => validateInternal(validator, value)
