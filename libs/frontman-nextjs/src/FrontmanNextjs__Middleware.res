// Middleware factory for NextJS

module Server = FrontmanNextjs__Server

type config = {
  projectRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
}

let defaultConfig = {
  projectRoot: ".",
  basePath: "__frontman",
  serverName: "frontman-nextjs",
  serverVersion: "1.0.0",
}

// CORS headers for cross-origin requests (e.g., browser test page on different port)
let corsHeaders = Dict.fromArray([
  ("Access-Control-Allow-Origin", "*"),
  ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
  ("Access-Control-Allow-Headers", "Content-Type"),
])

// Add CORS headers to a response
let withCors = (response: WebAPI.FetchAPI.response): WebAPI.FetchAPI.response => {
  let headers = response.headers
  corsHeaders->Dict.forEachWithKey((value, key) => {
    headers->WebAPI.Headers.set(~name=key, ~value)
  })
  response
}

// Handle OPTIONS preflight request
let handlePreflight = (): WebAPI.FetchAPI.response => {
  let headers = WebAPI.HeadersInit.fromDict(corsHeaders)
  WebAPI.Response.fromNull(~init={status: 204, headers})
}

// Create middleware that handles /__frontman/* routes
// Returns None if route doesn't match, Some(response) if handled
let createMiddleware = (~config: config=defaultConfig) => {
  let server = Server.make(
    ~projectRoot=config.projectRoot,
    ~serverName=config.serverName,
    ~serverVersion=config.serverVersion,
  )

  let middleware: WebAPI.FetchAPI.request => promise<option<WebAPI.FetchAPI.response>> = async req => {
    let method = req.method->String.toLowerCase
    let pathname = WebAPI.URL.parse(~url=req.url).pathname

    // Normalize path: remove leading slash, lowercase
    let path =
      pathname
      ->String.split("/")
      ->Array.filter(p => !String.isEmpty(p))
      ->Array.join("/")
      ->String.toLowerCase

    let toolsPath = config.basePath->String.toLowerCase ++ "/tools"
    let toolsCallPath = config.basePath->String.toLowerCase ++ "/tools/call"

    // Check if this is a frontman route (for CORS preflight)
    let isFrontmanRoute = path == toolsPath || path == toolsCallPath

    switch (method, path) {
    | ("options", _) if isFrontmanRoute => Some(handlePreflight())
    | ("get", p) if p == toolsPath => Some(server->Server.handleGetTools->withCors)
    | ("post", p) if p == toolsCallPath => Some((await server->Server.handleToolCall(req))->withCors)
    | _ => None
    }
  }

  middleware
}
