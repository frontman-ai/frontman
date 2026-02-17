// Bindings to Node.js HTTP module (IncomingMessage, ServerResponse)

// Node.js Buffer
module Buffer = {
  type t

  @module("node:buffer") @scope("Buffer")
  external concat: array<t> => t = "concat"

  @get external length: t => int = "length"

  // Convert buffer to Uint8Array for Web API interop
  external toUint8Array: t => Uint8Array.t = "%identity"
}

// IncomingMessage (extends Readable stream)
type incomingMessage

@get external method: incomingMessage => string = "method"
@get external url: incomingMessage => string = "url"
@get external headers: incomingMessage => Dict.t<string> = "headers"

// Collect the full request body by async-iterating over the IncomingMessage stream
let collectRequestBody: incomingMessage => promise<Buffer.t> = %raw(`
  async function(req) {
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    const { Buffer } = await import("node:buffer");
    return Buffer.concat(chunks);
  }
`)

// ServerResponse (extends Writable stream)
type serverResponse

@set external setStatusCode: (serverResponse, int) => unit = "statusCode"
@get external headersSent: serverResponse => bool = "headersSent"
@send external setHeader: (serverResponse, string, string) => unit = "setHeader"
@send external writeString: (serverResponse, string) => bool = "write"
@send external writeUint8Array: (serverResponse, Uint8Array.t) => bool = "write"
@send external end: serverResponse => unit = "end"
@send external endWithData: (serverResponse, string) => unit = "end"

// Connect-style middleware next function
type next = unit => unit

// Connect-style middleware type (used by Vite's server.middlewares)
type connectMiddleware = (incomingMessage, serverResponse, next) => unit
