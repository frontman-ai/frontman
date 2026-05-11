// Pure bindings for Vite's Node.js dev server types and externals.
// No business logic — only types, @send, @get, @set, @val, @module externals.

// ── Node.js http types ─────────────────────────────────────────────────

// IncomingMessage (readable stream of request data)
type incomingMessage = {
  method: Null.t<string>,
  url: Null.t<string>,
  headers: Dict.t<string>,
}

// ServerResponse (writable stream for response)
type serverResponse

@send external writeHead: (serverResponse, int, Dict.t<string>) => unit = "writeHead"
@send external write: (serverResponse, Uint8Array.t) => bool = "write"
@send external endResponse: serverResponse => unit = "end"
@send external endResponseWithData: (serverResponse, string) => unit = "end"
@set external setStatusCode: (serverResponse, int) => unit = "statusCode"

// ── Node.js Buffer ─────────────────────────────────────────────────────

type nodeBuffer
@scope("Buffer") @val external bufferConcat: array<nodeBuffer> => nodeBuffer = "concat"
@get external bufferLength: nodeBuffer => int = "length"

// ── Vite server types ──────────────────────────────────────────────────

type connectMiddleware = (incomingMessage, serverResponse, unit => unit) => unit
type connectServer = {@live use: connectMiddleware => unit}
@send external useMiddleware: (connectServer, connectMiddleware) => unit = "use"

type viteDevServer = {middlewares: connectServer}

// Vite Plugin type (minimal subset)
type plugin = {
  @live
  name: string,
  @live
  configureServer: viteDevServer => unit,
}

// ── Vue SFC source annotation plugin ───────────────────────────────────

// Injects __frontman_templateLine into compiled Vue SFC output.
@module("./vite-plugin-vue-source.mjs")
external frontmanVueSourcePlugin: unit => plugin = "frontmanVueSourcePlugin"
