// Vite plugin for integrating Frontman middleware
// Adapts Web API Request/Response to Vite's Node.js IncomingMessage/ServerResponse

module Config = FrontmanVite__Config
module Middleware = FrontmanVite__Middleware

// Minimal Node.js http bindings for Vite's dev server

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

// Helper: convert WebAPI Headers to a Dict<string>
let headersToDict: WebAPI.FetchAPI.headers => Dict.t<string> = %raw(`
  function headersToDict(headers) {
    const dict = {};
    headers.forEach(function(value, key) {
      dict[key] = value;
    });
    return dict;
  }
`)

// Buffer (opaque type for Node.js Buffer which extends Uint8Array)
type nodeBuffer
@scope("Buffer") @val external bufferConcat: array<nodeBuffer> => nodeBuffer = "concat"
@get external bufferLength: nodeBuffer => int = "length"

// Vite server types (minimal subset)
type connectMiddleware = (incomingMessage, serverResponse, unit => unit) => unit
type connectServer = {use: connectMiddleware => unit}
@send external useMiddleware: (connectServer, connectMiddleware) => unit = "use"

type viteDevServer = {middlewares: connectServer}

// Vite Plugin type (minimal subset)
type plugin = {
  name: string,
  configureServer: viteDevServer => unit,
}

// Helper: collect body chunks from IncomingMessage using for-await
// Since we can't use for-await in ReScript, we manually iterate
let collectBody: incomingMessage => promise<nodeBuffer> = %raw(`
  async function collectBody(req) {
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  }
`)

// Helper: pipe a ReadableStream to ServerResponse
let pipeStreamToResponse: (WebAPI.FileAPI.readableStream<'a>, serverResponse) => promise<unit> = %raw(`
  async function pipeStreamToResponse(stream, res) {
    const reader = stream.getReader();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(value);
      }
    } finally {
      reader.releaseLock();
    }
  }
`)

// Adapt a Web API middleware to Vite's Node.js middleware
// The middleware is: Request => Promise<Option<Response>>
// basePath is used to short-circuit non-frontman requests before consuming the body
let adaptMiddlewareToVite = (
  ~basePath: string,
  middleware: WebAPI.FetchAPI.request => promise<option<WebAPI.FetchAPI.response>>,
): ((incomingMessage, serverResponse, unit => unit) => promise<unit>) => {
  let prefix = "/" ++ basePath->String.toLowerCase

  async (req, res, next) => {
    // Short-circuit: only process requests under the frontman basePath.
    // This avoids draining the IncomingMessage body stream for non-frontman
    // routes, which would break downstream handlers that need to read it.
    let reqUrl = req.url->Null.toOption->Option.getOr("/")
    let pathname = reqUrl->String.toLowerCase
    // Strip query string for prefix matching (req.url includes ?query)
    let pathOnly = switch pathname->String.indexOf("?") {
    | -1 => pathname
    | idx => pathname->String.slice(~start=0, ~end=idx)
    }
    switch pathOnly == prefix || pathOnly->String.startsWith(prefix ++ "/") {
    | false => next()
    | true =>
      // Collect request body (safe — this is a frontman route)
      let bodyBuffer = await collectBody(req)

      // Build URL from host header + request URL
      let host = req.headers->Dict.get("host")->Option.getOr("localhost")
      let url = `http://${host}${reqUrl}`

      // Create Web API Request from Node.js IncomingMessage
      let method = req.method->Null.toOption->Option.getOr("GET")
      let headers = WebAPI.HeadersInit.fromDict(req.headers)
      let hasBody = bufferLength(bodyBuffer) > 0

      let body = switch hasBody {
      | true =>
        Some(WebAPI.BodyInit.fromArrayBuffer((Obj.magic(bodyBuffer): ArrayBuffer.t)))
      | false => None
      }

      let webRequest = WebAPI.Request.fromURL(url, ~init={method, headers, ?body})

      // Call middleware
      let responseOption = await middleware(webRequest)

      switch responseOption {
      | None => next()
      | Some(webResponse) =>
        // Set status code
        setStatusCode(res, webResponse.status)

        // Copy headers from Web API Response to Node.js ServerResponse
        let headerDict = headersToDict(webResponse.headers)
        writeHead(res, webResponse.status, headerDict)

        // Pipe the body stream if present
        switch webResponse.body->Null.toOption {
        | Some(stream) => await pipeStreamToResponse(stream, res)
        | None => ()
        }

        endResponse(res)
      }
    }
  }
}

// JS-friendly options type for the plugin (mirrors Config.jsConfigInput)
type pluginOptions = {
  isDev?: bool,
  basePath?: string,
  clientUrl?: string,
  clientCssUrl?: string,
  entrypointUrl?: string,
  isLightTheme?: bool,
  projectRoot?: string,
  sourceRoot?: string,
  host?: string,
}

// Create the Vite plugin
let frontmanPlugin = (~options: option<pluginOptions>=?): plugin => {
  let opts = options->Option.getOr({})

  {
    name: "frontman",
    configureServer: server => {
      // Initialize core LogCapture to intercept console/stdout for the
      // get_logs tool and post-edit error checking in edit_file
      FrontmanFrontmanCore.FrontmanCore__LogCapture.initialize()

      // Create config from options - pass through optional fields directly
      let isDev = opts.isDev
      let basePath = opts.basePath
      let clientUrl = opts.clientUrl
      let clientCssUrl = opts.clientCssUrl
      let entrypointUrl = opts.entrypointUrl
      let isLightTheme = opts.isLightTheme
      let projectRoot = opts.projectRoot
      let sourceRoot = opts.sourceRoot
      let host = opts.host
      let configInput: Config.jsConfigInput = {
        ?isDev,
        ?basePath,
        ?clientUrl,
        ?clientCssUrl,
        ?entrypointUrl,
        ?isLightTheme,
        ?projectRoot,
        ?sourceRoot,
        ?host,
      }
      let config = Config.makeFromObject(configInput)
      let middleware = Middleware.createMiddleware(config)
      let adaptedMiddleware = adaptMiddlewareToVite(~basePath=config.basePath, middleware)

      server.middlewares->useMiddleware((req, res, next) => {
        let _ =
          adaptedMiddleware(req, res, next)->Promise.catch(error => {
            let msg =
              error
              ->JsExn.fromException
              ->Option.flatMap(JsExn.message)
              ->Option.getOr("Unknown error")
            Console.error2("Frontman middleware error:", msg)
            setStatusCode(res, 500)
            endResponseWithData(res, "Internal Server Error")
            Promise.resolve()
          })
      })
    },
  }
}
