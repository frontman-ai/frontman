module Buffer = {
  type t

  @module("node:buffer") @scope("Buffer")
  external concat: array<t> => t = "concat"

  @get external length: t => int = "length"

  external toUint8Array: t => Uint8Array.t = "%identity"
}

type incomingMessage

@get external method: incomingMessage => string = "method"
@get external url: incomingMessage => string = "url"
@get external headers: incomingMessage => Dict.t<string> = "headers"

type serverResponse

@set external setStatusCode: (serverResponse, int) => unit = "statusCode"
@get external headersSent: serverResponse => bool = "headersSent"
@send external setHeader: (serverResponse, string, string) => unit = "setHeader"
@send external writeString: (serverResponse, string) => bool = "write"
@send external writeUint8Array: (serverResponse, Uint8Array.t) => bool = "write"
@send external end: serverResponse => unit = "end"
@send external endWithData: (serverResponse, string) => unit = "end"

type next = unit => unit

type connectMiddleware = (incomingMessage, serverResponse, next) => unit
