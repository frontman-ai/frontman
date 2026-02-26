// Shared exception helpers.
//
// Centralises the JS exception message extraction pattern that was duplicated
// across tool files and request handlers.

// Extract the message from a JS exception, or return "Unknown error".
let message = (exn: exn): string =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
