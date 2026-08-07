module Config = FrontmanVite__Config
module Middleware = FrontmanVite__Middleware
module Core = FrontmanAiFrontmanCore
open FrontmanVite__Bindings

let headersToDict: WebAPI.FetchAPI.headers => Dict.t<string> = %raw(`
  function headersToDict(headers) {
    const dict = {};
    headers.forEach(function(value, key) {
      dict[key] = value;
    });
    return dict;
  }
`)

let collectBody: incomingMessage => promise<nodeBuffer> = %raw(`
  async function collectBody(req) {
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  }
`)

let pipeStreamToResponse: (
  WebAPI.FileAPI.readableStream<'a>,
  serverResponse,
) => promise<unit> = %raw(`
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

let adaptMiddlewareToVite = (
  ~basePath: string,
  middleware: WebAPI.FetchAPI.request => promise<option<WebAPI.FetchAPI.response>>,
): ((incomingMessage, serverResponse, unit => unit) => promise<unit>) => {
  async (req, res, next) => {
    let reqUrl = req.url->Null.toOption->Option.getOr("/")
    let pathname = reqUrl->String.toLowerCase
    let pathOnly = switch pathname->String.indexOf("?") {
    | -1 => pathname
    | idx => pathname->String.slice(~start=0, ~end=idx)
    }
    let isFrontmanRoute = Core.FrontmanCore__Middleware.isFrontmanRoute(
      ~pathname=pathOnly,
      ~basePath,
      ~method=req.method->Null.toOption->Option.getOr("GET"),
    )
    switch isFrontmanRoute {
    | false => next()
    | true =>
      let bodyBuffer = await collectBody(req)

      let host = req.headers->Dict.get("host")->Option.getOr("localhost")
      let url = `http://${host}${reqUrl}`

      let method = req.method->Null.toOption->Option.getOr("GET")
      let headers = WebAPI.HeadersInit.fromDict(req.headers)
      let hasBody = bufferLength(bodyBuffer) > 0

      let body = switch hasBody {
      | true => Some(WebAPI.BodyInit.fromArrayBuffer((Obj.magic(bodyBuffer): ArrayBuffer.t)))
      | false => None
      }

      let webRequest = WebAPI.Request.fromURL(url, ~init={method, headers, ?body})

      let responseOption = await middleware(webRequest)

      switch responseOption {
      | None => next()
      | Some(webResponse) =>
        setStatusCode(res, webResponse.status)

        let headerDict = headersToDict(webResponse.headers)
        writeHead(res, webResponse.status, headerDict)

        switch webResponse.body->Null.toOption {
        | Some(stream) => await pipeStreamToResponse(stream, res)
        | None => ()
        }

        endResponse(res)
      }
    }
  }
}

type pluginOptions = {
  isDev?: bool,
  basePath?: string,
  clientUrl?: string,
  clientCssUrl?: string,
  entrypointUrl?: string,
  projectRoot?: string,
  sourceRoot?: string,
  host?: string,
}

@@live
let frontmanPlugin = (~options: option<pluginOptions>=?): array<plugin> => {
  let opts = options->Option.getOr({})

  let middlewarePlugin = {
    name: "frontman",
    configureServer: server => {
      FrontmanAiFrontmanCore.FrontmanCore__LogCapture.initialize()

      let isDev = opts.isDev
      let basePath = opts.basePath
      let clientUrl = opts.clientUrl
      let clientCssUrl = opts.clientCssUrl
      let entrypointUrl = opts.entrypointUrl
      let projectRoot = opts.projectRoot
      let sourceRoot = opts.sourceRoot
      let host = opts.host
      let configInput: Config.jsConfigInput = {
        ?isDev,
        ?basePath,
        ?clientUrl,
        ?clientCssUrl,
        ?entrypointUrl,
        ?projectRoot,
        ?sourceRoot,
        ?host,
      }
      let config = Config.makeFromObject(configInput)
      let middleware = Middleware.createMiddleware(config)
      let adaptedMiddleware = adaptMiddlewareToVite(~basePath=config.basePath, middleware)

      server.middlewares->useMiddleware((req, res, next) => {
        let _ = adaptedMiddleware(req, res, next)->Promise.catch(error => {
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

  [middlewarePlugin, frontmanVueSourcePlugin()]
}
