type incomingMessage = {
  method: Null.t<string>,
  url: Null.t<string>,
  headers: Dict.t<string>,
}

type serverResponse

@send external writeHead: (serverResponse, int, Dict.t<string>) => unit = "writeHead"
@send external write: (serverResponse, Uint8Array.t) => bool = "write"
@send external endResponse: serverResponse => unit = "end"
@send external endResponseWithData: (serverResponse, string) => unit = "end"
@set external setStatusCode: (serverResponse, int) => unit = "statusCode"

type nodeBuffer
@scope("Buffer") @val external bufferConcat: array<nodeBuffer> => nodeBuffer = "concat"
@get external bufferLength: nodeBuffer => int = "length"

type connectMiddleware = (incomingMessage, serverResponse, unit => unit) => unit
type connectServer = {@live use: connectMiddleware => unit}
@send external useMiddleware: (connectServer, connectMiddleware) => unit = "use"

type viteDevServer = {middlewares: connectServer}

type plugin = {
  @live
  name: string,
  @live
  configureServer: viteDevServer => unit,
}

@module("./vite-plugin-vue-source.mjs")
external frontmanVueSourcePlugin: unit => plugin = "frontmanVueSourcePlugin"
