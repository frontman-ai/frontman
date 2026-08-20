type incomingMessage

module Buffer = {
  type t

  @module("node:buffer") @scope("Buffer")
  external concat: array<t> => t = "concat"

  @get external length: t => int = "length"

  external toUint8Array: t => Uint8Array.t = "%identity"
}

module Readable = {
  @module("node:stream") @scope("Readable")
  external toWeb: incomingMessage => WebAPI.FileAPI.readableStream<Uint8Array.t> = "toWeb"
}

@get external method: incomingMessage => string = "method"
@get external url: incomingMessage => string = "url"
@get external headers: incomingMessage => Dict.t<string> = "headers"
@get external rawHeaders: incomingMessage => array<string> = "rawHeaders"
@get external readableDidRead: incomingMessage => bool = "readableDidRead"
@get external destroyed: incomingMessage => bool = "destroyed"
@send external destroy: incomingMessage => unit = "destroy"

type serverResponse

@set external setStatusCode: (serverResponse, int) => unit = "statusCode"
@get external headersSent: serverResponse => bool = "headersSent"
@send external setHeader: (serverResponse, string, string) => unit = "setHeader"
@send external writeString: (serverResponse, string) => bool = "write"
@send external writeUint8Array: (serverResponse, Uint8Array.t) => bool = "write"
@send external end: serverResponse => unit = "end"
@send external endWithData: (serverResponse, string) => unit = "end"

type eventListener = unit => unit

@send external onEvent: ('target, string, eventListener) => unit = "on"
@send external removeEventListener: ('target, string, eventListener) => unit = "removeListener"

type next = unit => unit

type connectMiddleware = (incomingMessage, serverResponse, next) => unit
