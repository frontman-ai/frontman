// Node.js Buffer bindings for binary data operations

type t

// Create a Buffer from a base64-encoded string
@module("node:buffer") @scope("Buffer")
external fromBase64: (string, @as("base64") _) => t = "from"

// Create a Buffer from a utf8 string
@module("node:buffer") @scope("Buffer")
external fromString: (string, @as("utf8") _) => t = "from"
