// Bindings for @toon-format/toon
// TOON is a compact, token-efficient serialization format

// Encode JSON to TOON string (reduces token usage by 30-60%)
@module("@toon-format/toon")
external encode: JSON.t => string = "encode"

// Decode TOON string back to JSON
@module("@toon-format/toon")
external decode: string => JSON.t = "decode"


