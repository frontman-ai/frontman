type t

@module("node:buffer") @scope("Buffer")
external fromBase64: (string, @as("base64") _) => t = "from"

@module("node:buffer") @scope("Buffer")
external fromString: (string, @as("utf8") _) => t = "from"

@module("node:buffer") @scope("Buffer")
external byteLength: (string, @as("utf8") _) => int = "byteLength"

@send external equals: (t, t) => bool = "equals"
@send external toUtf8: (t, @as("utf8") _) => string = "toString"
