module NodeHttp = FrontmanBindings.NodeHttp
module WebStreams = FrontmanBindings.WebStreams
module CoreMiddleware = FrontmanAiFrontmanCore.FrontmanCore__Middleware

let collectRequestBody: NodeHttp.incomingMessage => promise<NodeHttp.Buffer.t> = %raw(`
  async function(req) {
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    const { Buffer } = await import("node:buffer");
    return Buffer.concat(chunks);
  }
`)

let copyHeaders: (WebAPI.FetchAPI.headers, NodeHttp.serverResponse) => unit = %raw(`
  function(headers, res) {
    headers.forEach(function(value, key) {
      res.setHeader(key, value);
    });
  }
`)

type webMiddleware = WebAPI.FetchAPI.request => promise<option<WebAPI.FetchAPI.response>>

let toWebRequest = async (req: NodeHttp.incomingMessage): WebAPI.FetchAPI.request => {
  let host = req->NodeHttp.headers->Dict.get("host")->Option.getOr("localhost")
  let url = `http://${host}${req->NodeHttp.url}`
  let method = req->NodeHttp.method

  let body = switch method->String.toUpperCase {
  | "POST" | "PUT" | "PATCH" =>
    let buffer = await collectRequestBody(req)
    Some(buffer->NodeHttp.Buffer.toUint8Array)
  | _ => None
  }

  let headersDict = req->NodeHttp.headers

  let init: WebAPI.FetchAPI.requestInit = {
    method,
    headers: WebAPI.HeadersInit.fromDict(headersDict),
    body: ?(body->Option.map(b => WebAPI.BodyInit.fromTypedArray(b))),
  }
  switch body {
  | Some(_) => init->Obj.magic->Dict.set("duplex", "half")
  | None => ()
  }

  WebAPI.Request.fromURL(url, ~init)
}

let writeWebResponse = async (
  webResponse: WebAPI.FetchAPI.response,
  res: NodeHttp.serverResponse,
): unit => {
  res->NodeHttp.setStatusCode(webResponse.status)

  copyHeaders(webResponse.headers, res)

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

let adaptToConnect = (middleware: webMiddleware, ~basePath: string): NodeHttp.connectMiddleware => {
  (req, res, next) => {
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
