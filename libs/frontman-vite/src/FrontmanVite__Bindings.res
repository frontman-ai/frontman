type incomingMessage = FrontmanBindings.NodeHttp.incomingMessage
type serverResponse = FrontmanBindings.NodeHttp.serverResponse

type connectMiddleware = (incomingMessage, serverResponse, unit => unit) => unit
type connectServer = {@live use: connectMiddleware => unit}
@send external useMiddleware: (connectServer, connectMiddleware) => unit = "use"

type viteDevServer = {middlewares: connectServer}
type serverConfig = {
  @live
  cors: bool,
}
type config = {
  @live
  server: serverConfig,
}

type plugin = {
  @live
  name: string,
  @live
  enforce?: string,
  @live
  config?: unit => config,
  @live
  configureServer: viteDevServer => unit,
}

@module("./vite-plugin-vue-source.mjs")
external frontmanVueSourcePlugin: unit => plugin = "frontmanVueSourcePlugin"
