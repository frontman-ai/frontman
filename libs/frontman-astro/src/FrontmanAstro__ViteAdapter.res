// Adapter to convert our Web API-based middleware into Vite's Node.js Connect middleware
//
// Our Astro middleware uses Web API types (Request/Response) internally.
// Vite's server.middlewares.use() expects Node.js Connect middleware (IncomingMessage/ServerResponse).
// This module bridges the two.

module NodeHttp = FrontmanBindings.NodeHttp
module WebStreams = FrontmanBindings.WebStreams
module CoreMiddleware = FrontmanFrontmanCore.FrontmanCore__Middleware

// Copy headers from a Web API Headers object to a Node.js ServerResponse
let copyHeaders: (WebAPI.FetchAPI.headers, NodeHttp.serverResponse) => unit = %raw(`
  function(headers, res) {
    headers.forEach(function(value, key) {
      res.setHeader(key, value);
    });
  }
`)

// The shape of our middleware: takes a Web Request, returns option<Response>
// None means "pass through to next middleware"
type webMiddleware = WebAPI.FetchAPI.request => promise<option<WebAPI.FetchAPI.response>>

// Convert a Node.js IncomingMessage to a Web API Request
let toWebRequest = async (req: NodeHttp.incomingMessage): WebAPI.FetchAPI.request => {
  let host = req->NodeHttp.headers->Dict.get("host")->Option.getOr("localhost")
  let url = `http://${host}${req->NodeHttp.url}`
  let method = req->NodeHttp.method

  // Collect request body for methods that have one
  let body = switch method->String.toUpperCase {
  | "POST" | "PUT" | "PATCH" =>
    let buffer = await NodeHttp.collectRequestBody(req)
    Some(buffer->NodeHttp.Buffer.toUint8Array)
  | _ => None
  }

  // Convert Node.js headers dict to Web API HeadersInit
  let headersDict = req->NodeHttp.headers

  // Build request init — add duplex: 'half' for Node.js compatibility when body is present
  // (required by Node 18+ fetch spec for requests with a body)
  let init: WebAPI.FetchAPI.requestInit = {
    method,
    headers: WebAPI.HeadersInit.fromDict(headersDict),
    body: ?body->Option.map(b => WebAPI.BodyInit.fromTypedArray(b)),
  }
  switch body {
  | Some(_) => init->Obj.magic->Dict.set("duplex", "half")
  | None => ()
  }

  WebAPI.Request.fromURL(url, ~init)
}

// Write a Web API Response back to a Node.js ServerResponse
// Handles both regular responses and streaming (SSE)
// NOTE: Decodes all chunks as UTF-8 text. This is correct for Frontman's
// JSON/HTML/SSE routes but would corrupt binary responses. If binary route
// support is needed, use res.write(chunk) directly with the raw Uint8Array.
let writeWebResponse = async (
  webResponse: WebAPI.FetchAPI.response,
  res: NodeHttp.serverResponse,
): unit => {
  // Set status code
  res->NodeHttp.setStatusCode(webResponse.status)

  // Copy headers from Web API Response to Node.js ServerResponse
  // Headers.forEach isn't bound in our WebAPI bindings, use raw JS
  copyHeaders(webResponse.headers, res)

  // Stream the response body
  switch webResponse.body->Null.toOption {
  | Some(body) =>
    let reader = body->WebAPI.ReadableStream.getReader
    let decoder = WebStreams.makeTextDecoder()
    let reading = ref(true)
    while reading.contents {
      let result = await WebStreams.readChunk(reader)
      if result.done {
        reading := false
      } else {
        switch result.value->Nullable.toOption {
        | Some(chunk) =>
          // Decode the chunk and write as string to handle text/SSE responses
          let text = decoder->WebStreams.decodeWithOptions(chunk, {"stream": true})
          res->NodeHttp.writeString(text)->ignore
        | None => ()
        }
      }
    }
    res->NodeHttp.end
  | None => res->NodeHttp.end
  }
}

// Adapt a Web API middleware to a Vite Connect middleware
// The web middleware returns option<Response>:
//   - Some(response) => handle it (write to ServerResponse)
//   - None => pass through (call next())
//
// basePath is used for an early URL prefix check so we skip body consumption
// for requests that aren't Frontman routes. Without this, POST/PUT/PATCH
// requests to non-Frontman routes would have their body stream drained before
// next() is called, causing downstream handlers to receive an empty body.
let adaptToConnect = (middleware: webMiddleware, ~basePath: string): NodeHttp.connectMiddleware => {
  (req, res, next) => {
    // Fast path: skip non-Frontman routes without consuming the request body.
    // Strip query string first — Node.js req.url includes it (e.g. "/frontman?x=1")
    // but we only need the path portion for prefix matching.
    let reqPath =
      req
      ->NodeHttp.url
      ->String.split("?")
      ->Array.get(0)
      ->Option.getOr(req->NodeHttp.url)
    let isFrontmanRoute = CoreMiddleware.isFrontmanRoute(
      ~pathname=reqPath,
      ~basePath,
      ~method=req->NodeHttp.method,
    )
    if !isFrontmanRoute {
      next()
    } else {
      let handleRequest = async () => {
        let webRequest = await toWebRequest(req)
        let maybeResponse = await middleware(webRequest)
        switch maybeResponse {
        | Some(webResponse) => await writeWebResponse(webResponse, res)
        | None => next()
        }
      }
      handleRequest()
      ->Promise.catch(error => {
        Console.error2("[Frontman] Middleware error:", error)
        // Only send error response if headers haven't been sent yet
        // (writeWebResponse may have already started streaming)
        if !(res->NodeHttp.headersSent) {
          res->NodeHttp.setStatusCode(500)
          res->NodeHttp.endWithData("Internal Server Error")
        } else {
          res->NodeHttp.end
        }
        Promise.resolve()
      })
      ->ignore
    }
  }
}
