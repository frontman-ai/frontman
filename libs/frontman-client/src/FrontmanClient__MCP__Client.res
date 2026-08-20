module Types = FrontmanClient__MCP__Types
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module SSE = FrontmanClient__MCP__SSE
module Decoders = FrontmanClient__Decoders
module HeaderValue = FrontmanClient__MCP__HeaderValue
module CustomHeaders = FrontmanClient__MCP__CustomHeaders
module RemoteSchema = FrontmanClient__MCP__RemoteSchema
module ResponseBody = FrontmanClient__MCP__ResponseBody
module WebStreams = FrontmanBindings.WebStreams
module Log = FrontmanLogs.Logs.Make({
  let component = #MCP
})

type remoteTool = {
  name: string,
  definition: Types.Tool.t,
  inputSchema: JSON.t,
  outputSchema: option<JSON.t>,
  annotations: array<CustomHeaders.annotation>,
}

type toolValidationError =
  | InvalidTool(string)
  | ValidationCancelled

type clientState =
  | Disconnected
  | Connected({tools: array<remoteTool>, @live serverInfo: Types.Implementation.t})
  | Error(string)

type cache = {
  tools: array<remoteTool>,
  serverInfo: Types.Implementation.t,
  expiresAt: float,
}

type t = {
  baseUrl: string,
  requestHeaders: Dict.t<string>,
  state: ref<clientState>,
  nextId: ref<int>,
  cache: ref<option<cache>>,
  connectGeneration: ref<int>,
  connectController: ref<option<WebAPI.EventAPI.abortController>>,
}

type responseId = {id: JsonRpc.Id.t}
type resultEnvelope<'result> = {result: 'result}
type errorEnvelope = {error: JsonRpc.RpcError.t}
type resultDiscriminator = {resultType: string}
type receivedResult<'result> = Complete('result) | InputRequired

type unsupportedVersionData = {requested: string, supported: array<string>}
type unsupportedVersionError = {code: int, data: unsupportedVersionData}
type unsupportedVersionEnvelope = {@as("error") unsupportedError: unsupportedVersionError}

let unsupportedVersionEnvelopeSchema = S.object(s => {
  unsupportedError: s.field(
    "error",
    S.object(s => {
      code: s.field("code", S.int),
      data: s.field(
        "data",
        S.object(
          s => {
            requested: s.field("requested", S.string),
            supported: s.field("supported", S.array(S.string)),
          },
        ),
      ),
    }),
  ),
})

let maxPages = 32
let maxTools = 256
let maxCursorBytes = 4096
let maxToolBytes = 65536
let maxCatalogBytes = 1048576
let absoluteTimeoutMs = 600000

type timeoutId
type requestTerminal = Active | Completed | TimedOut | CallerCancelled

@val external setTimeout: (unit => unit, int) => timeoutId = "setTimeout"
@val external clearTimeout: timeoutId => unit = "clearTimeout"
@val @scope("performance") external monotonicNow: unit => float = "now"

@get external byteLength: Uint8Array.t => int = "byteLength"

let utf8Bytes = value => WebStreams.makeTextEncoder()->WebStreams.encode(value)->byteLength

@@live
let make = (~baseUrl: string, ~requestHeaders: Dict.t<string>=Dict.make()): t => {
  baseUrl: baseUrl->String.endsWith("/") ? baseUrl->String.slice(~start=0, ~end=-1) : baseUrl,
  requestHeaders: requestHeaders->Dict.copy,
  state: ref(Disconnected),
  nextId: ref(1),
  cache: ref(None),
  connectGeneration: ref(0),
  connectController: ref(None),
}

let isConnected = client =>
  switch client.state.contents {
  | Connected(_) => true
  | Disconnected | Error(_) => false
  }

let getState = client => client.state.contents

let requestMeta = (): Types.RequestMeta.t => {
  let clientInfo: Types.Implementation.t = {
    name: "frontman-browser-client",
    version: "1.0.0",
    title: None,
    description: None,
    websiteUrl: None,
    icons: None,
  }
  Dict.fromArray([
    ("io.modelcontextprotocol/protocolVersion", JSON.Encode.string(Types.protocolVersion)),
    ("io.modelcontextprotocol/clientCapabilities", JSON.Encode.object(Dict.make())),
    (
      "io.modelcontextprotocol/clientInfo",
      clientInfo->S.decodeOrThrow(~from=Types.Implementation.schema, ~to=S.json),
    ),
  ])
}

let nextRequestId = client => {
  let id = client.nextId.contents
  client.nextId := id + 1
  JsonRpc.Id.fromInt(id)
}

let sameId = (left, right) =>
  JSON.stringify(JsonRpc.Id.toJson(left)) == JSON.stringify(JsonRpc.Id.toJson(right))

let endpoint = client => `${client.baseUrl}/mcp`

let normalizeAbsentResultType = json =>
  switch json->JSON.Decode.object {
  | Some(fields) =>
    switch fields->Dict.get("result")->Option.flatMap(JSON.Decode.object) {
    | Some(result) if !(result->Dict.has("resultType")) =>
      let normalizedResult = result->Dict.copy
      normalizedResult->Dict.set("resultType", JSON.Encode.string("complete"))
      let normalizedFields = fields->Dict.copy
      normalizedFields->Dict.set("result", JSON.Encode.object(normalizedResult))
      JSON.Encode.object(normalizedFields)
    | Some(_) | None => json
    }
  | None => json
  }

let responseJson = async (
  response: WebAPI.FetchAPI.response,
  ~signal: option<WebAPI.EventAPI.abortSignal>,
  ~onNotification: option<JSON.t => unit>,
): result<JSON.t, string> => {
  let mediaType =
    response.headers
    ->WebAPI.Headers.get("Content-Type")
    ->Null.toOption
    ->Option.map(value =>
      value->String.split(";")->Array.get(0)->Option.getOrThrow->String.trim->String.toLowerCase
    )
  switch mediaType {
  | Some("application/json") =>
    switch await ResponseBody.readText(response, ~signal?) {
    | Error(BodyTooLarge) => Error("MCP response exceeds the byte limit")
    | Error(ReadFailed(message)) => Error(message)
    | Ok(source) if ResponseBody.exceedsDepth(source) =>
      Error("MCP response exceeds the JSON depth limit")
    | Ok(source) =>
      try {
        Ok(JSON.parseOrThrow(source))
      } catch {
      | exn =>
        Error(
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Invalid JSON response"),
        )
      }
    }
  | Some("text/event-stream") => await SSE.readStream(response, ~signal?, ~onNotification?)
  | Some(value) => Error(`Unsupported MCP response media type: ${value}`)
  | None => Error("MCP response is missing Content-Type")
  }
}

let post = async (
  client,
  ~id,
  ~method_,
  ~name=?,
  ~body,
  ~customHeaders=?,
  ~signal=?,
  ~onNotification=?,
): result<JSON.t, string> => {
  let requestController = WebAPI.AbortController.make()
  let effectiveSignal =
    signal->Option.mapOr(requestController.signal, value =>
      WebAPI.AbortSignal.any([value, requestController.signal])
    )
  let headers = client.requestHeaders->Dict.copy
  [
    ("Content-Type", "application/json"),
    ("Accept", "application/json, text/event-stream"),
    ("MCP-Protocol-Version", Types.protocolVersion),
    ("Mcp-Method", method_),
  ]->Array.forEach(((name, value)) => headers->Dict.set(name, value))
  name->Option.forEach(value => headers->Dict.set("Mcp-Name", HeaderValue.encode(value)))
  customHeaders->Option.forEach(values =>
    values->Dict.forEachWithKey((value, key) => headers->Dict.set(key, value))
  )

  let terminal = ref(Active)
  let deadlineTimer = ref(None)
  let callerAbortListener = ref(None)
  let resultResolver = ref(None)
  let result: promise<result<JSON.t, string>> = Promise.make((resolve, _reject) =>
    resultResolver := Some(resolve)
  )
  let cleanup = () => {
    deadlineTimer.contents->Option.forEach(clearTimeout)
    deadlineTimer := None
    callerAbortListener.contents->Option.forEach(listener =>
      signal->Option.forEach(value =>
        value->WebAPI.AbortSignal.removeEventListener(Abort, listener)
      )
    )
    callerAbortListener := None
  }
  let settle = (reason, outcome, ~abort) => {
    switch terminal.contents {
    | Active =>
      terminal := reason
      cleanup()
      switch abort {
      | true => requestController->WebAPI.AbortController.abort
      | false => ()
      }
      (resultResolver.contents->Option.getOrThrow)(outcome)
    | Completed | TimedOut | CallerCancelled => ()
    }
  }
  let onCallerAbort = _event => settle(CallerCancelled, Error("Request cancelled"), ~abort=true)
  callerAbortListener := Some(onCallerAbort)
  signal->Option.forEach(value => value->WebAPI.AbortSignal.addEventListener(Abort, onCallerAbort))
  switch signal->Option.mapOr(false, value => value.aborted) {
  | true => settle(CallerCancelled, Error("Request cancelled"), ~abort=true)
  | false =>
    let deadline = monotonicNow() +. absoluteTimeoutMs->Int.toFloat
    deadlineTimer :=
      Some(
        setTimeout(
          () => settle(TimedOut, Error("MCP request timed out"), ~abort=true),
          absoluteTimeoutMs + 1,
        ),
      )
    let send = async () => {
      let outcome: result<JSON.t, string> = try {
        let response = await WebAPI.Global.fetch(
          endpoint(client),
          ~init={
            method: "POST",
            headers: WebAPI.HeadersInit.fromDict(headers),
            body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
            signal: Null.make(effectiveSignal),
          },
        )
        let parsed = await responseJson(response, ~signal=Some(effectiveSignal), ~onNotification)
        switch parsed {
        | Error(message) => Error(message)
        | Ok(json) =>
          let json = normalizeAbsentResultType(json)
          switch json->Decoders.parseSchema(JsonRpc.Wire.responseSchema) {
          | Error(message) => Error(`Invalid MCP response: ${message}`)
          | Ok(_) =>
            try {
              let responseId: responseId = json->S.parseOrThrow(
                ~to=S.object(s => {
                  id: s.field("id", JsonRpc.Id.schema),
                }),
              )
              switch sameId(id, responseId.id) {
              | false => Error("MCP response ID does not match request ID")
              | true => Ok(json)
              }
            } catch {
            | S.Exn(_) => Error("MCP error response has no correlatable ID")
            | exn => throw(exn)
            }
          }
        }
      } catch {
      | exn =>
        switch terminal.contents {
        | CallerCancelled => Error("Request cancelled")
        | TimedOut => Error("MCP request timed out")
        | Active | Completed =>
          Error(
            exn
            ->JsExn.fromException
            ->Option.flatMap(JsExn.message)
            ->Option.getOr("MCP fetch failed"),
          )
        }
      }
      switch terminal.contents {
      | Active =>
        switch monotonicNow() <= deadline {
        | true =>
          switch outcome {
          | Ok(_) => settle(Completed, outcome, ~abort=false)
          | Error(_) => settle(Completed, outcome, ~abort=true)
          }
        | false => settle(TimedOut, Error("MCP request timed out"), ~abort=true)
        }
      | Completed | TimedOut | CallerCancelled => ()
      }
    }
    send()->ignore
  }
  await result
}

let resultFromResponse = (json, schema): result<receivedResult<'result>, string> =>
  try {
    let envelope: resultEnvelope<JSON.t> =
      json->S.parseOrThrow(~to=S.object(s => {result: s.field("result", S.json)}))
    let discriminator: resultDiscriminator =
      envelope.result->S.parseOrThrow(
        ~to=S.object(s => {resultType: s.field("resultType", S.string)}),
      )
    switch discriminator.resultType {
    | "complete" =>
      try {
        Ok(Complete(envelope.result->S.parseOrThrow(~to=schema)))
      } catch {
      | S.Exn(_) => Error("Invalid MCP result response")
      | exn => throw(exn)
      }
    | "input_required" =>
      try {
        envelope.result->S.parseOrThrow(~to=Types.InputRequiredResult.schema)->ignore
        Ok(InputRequired)
      } catch {
      | S.Exn(_) => Error("Invalid MCP input_required result")
      | exn => throw(exn)
      }
    | resultType => Error(`Unsupported MCP result type: ${resultType}`)
    }
  } catch {
  | S.Exn(_) =>
    try {
      let envelope: errorEnvelope = json->S.parseOrThrow(
        ~to=S.object(s => {
          error: s.field("error", JsonRpc.RpcError.schema),
        }),
      )
      Error(JsonRpc.RpcError.message(envelope.error))
    } catch {
    | S.Exn(_) => Error("Invalid MCP result response")
    | exn => throw(exn)
    }
  | exn => throw(exn)
  }

let errorCode = json => {
  try {
    let envelope: errorEnvelope = json->S.parseOrThrow(
      ~to=S.object(s => {
        error: s.field("error", JsonRpc.RpcError.schema),
      }),
    )
    Some(JsonRpc.RpcError.code(envelope.error))
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}

let serverInfo = result =>
  result.Types.DiscoverResult._meta
  ->Option.flatMap(meta => meta->Dict.get("io.modelcontextprotocol/serverInfo"))
  ->Option.map(value => {
    try {
      Ok(value->S.parseOrThrow(~to=Types.Implementation.schema))
    } catch {
    | S.Exn(_) => Error("MCP discovery contains invalid serverInfo")
    | exn => throw(exn)
    }
  })
  ->Option.getOr(Error("MCP discovery is missing serverInfo"))

let validateTool = async (
  definition: Types.Tool.t,
  ~signal: option<WebAPI.EventAPI.abortSignal>,
): result<remoteTool, toolValidationError> => {
  let definitionJson = definition->S.decodeOrThrow(~from=Types.Tool.schema, ~to=S.json)
  let inputSchema = Types.ToolSchema.toJson(definition.Types.Tool.inputSchema)
  let outputSchema = definition.Types.Tool.outputSchema->Option.map(Types.ToolSchema.toJson)
  switch utf8Bytes(JSON.stringify(definitionJson)) > maxToolBytes {
  | true => Error(InvalidTool("Tool definition exceeds the byte limit"))
  | false =>
    switch await RemoteSchema.compileSchema(~schema=inputSchema, ~signal?) {
    | Error(Cancelled) => Error(ValidationCancelled)
    | Error(Invalid(reason)) => Error(InvalidTool(`Invalid input schema: ${reason}`))
    | Error(TimedOut) => Error(InvalidTool("Input schema validation timed out"))
    | Error(WorkerFailed(reason)) => Error(InvalidTool(`Input schema worker failed: ${reason}`))
    | Ok() =>
      let outputValidation = switch outputSchema {
      | None => Ok()
      | Some(schema) =>
        switch await RemoteSchema.compileSchema(~schema, ~signal?) {
        | Error(Cancelled) => Error(ValidationCancelled)
        | Error(Invalid(reason)) => Error(InvalidTool(`Invalid output schema: ${reason}`))
        | Error(TimedOut) => Error(InvalidTool("Output schema validation timed out"))
        | Error(WorkerFailed(reason)) =>
          Error(InvalidTool(`Output schema worker failed: ${reason}`))
        | Ok() => Ok()
        }
      }
      outputValidation->Result.flatMap(() =>
        CustomHeaders.discover(inputSchema)
        ->Result.mapError(reason => InvalidTool(reason))
        ->Result.map(annotations => {
          name: definition.name,
          definition,
          inputSchema,
          outputSchema,
          annotations,
        })
      )
    }
  }
}

let discoveryRequest = async (client, ~signal): result<JSON.t, string> => {
  let id = nextRequestId(client)
  let request: Types.DiscoverRequest.t = {
    jsonrpc: "2.0",
    id,
    method: "server/discover",
    params: {_meta: requestMeta()},
  }
  let body = request->S.decodeOrThrow(~from=Types.DiscoverRequest.schema, ~to=S.json)
  await post(client, ~id, ~method_="server/discover", ~body, ~signal?)
}

let requestsSameVersionRetry = json => {
  try {
    let envelope = json->S.parseOrThrow(~to=unsupportedVersionEnvelopeSchema)
    envelope.unsupportedError.code == -32022 &&
    envelope.unsupportedError.data.requested == Types.protocolVersion &&
    envelope.unsupportedError.data.supported->Array.includes(Types.protocolVersion)
  } catch {
  | S.Exn(_) => false
  | exn => throw(exn)
  }
}

type discovery = {result: Types.DiscoverResult.t, expiresAt: float}

let fetchDiscovery = async (client, ~signal): result<discovery, string> => {
  let response = switch await discoveryRequest(client, ~signal) {
  | Ok(json) if requestsSameVersionRetry(json) => await discoveryRequest(client, ~signal)
  | response => response
  }
  let receivedAt = Date.now()
  switch response {
  | Error(message) => Error(message)
  | Ok(json) =>
    switch resultFromResponse(json, Types.DiscoverResult.schema) {
    | Ok(Complete(result)) => Ok({result, expiresAt: receivedAt +. result.ttlMs})
    | Ok(InputRequired) => Error("Unsupported MCP result type: input_required")
    | Error(message) => Error(message)
    }
  }
}

type pages = {
  tools: array<Types.Tool.t>,
  cacheScope: Types.CacheScope.t,
  expiresAt: float,
}
type listFailure = Message(string) | InvalidCursor(string)

let rec fetchTools = async (client, ~signal, ~canRestart=true): result<pages, string> => {
  let cursor = ref(None)
  let tools = ref([])
  let cacheScope = ref(None)
  let expiresAt = ref(None)
  let pageCount = ref(0)
  let failure = ref(None)
  let complete = ref(false)

  while !complete.contents && failure.contents->Option.isNone {
    pageCount := pageCount.contents + 1
    switch pageCount.contents > maxPages {
    | true => failure := Some(Message("MCP tools/list exceeded the page limit"))
    | false =>
      let id = nextRequestId(client)
      let request: Types.ListToolsRequest.t = {
        jsonrpc: "2.0",
        id,
        method: "tools/list",
        params: {_meta: requestMeta(), cursor: cursor.contents},
      }
      let body = request->S.decodeOrThrow(~from=Types.ListToolsRequest.schema, ~to=S.json)
      switch await post(client, ~id, ~method_="tools/list", ~body, ~signal?) {
      | Error(message) => failure := Some(Message(message))
      | Ok(json) =>
        let receivedAt = Date.now()
        switch resultFromResponse(json, Types.ListToolsResult.schema) {
        | Error(message) if cursor.contents->Option.isSome && errorCode(json) == Some(-32602) =>
          failure := Some(InvalidCursor(message))
        | Error(message) => failure := Some(Message(message))
        | Ok(InputRequired) =>
          failure := Some(Message("Unsupported MCP result type: input_required"))
        | Ok(Complete(page)) =>
          let pageExpiresAt = receivedAt +. page.ttlMs
          switch (expiresAt.contents, cacheScope.contents) {
          | (None, None) =>
            expiresAt := Some(pageExpiresAt)
            cacheScope := Some(page.cacheScope)
          | (Some(expectedExpiry), Some(expectedScope)) =>
            expiresAt :=
              Some(
                switch expectedExpiry < pageExpiresAt {
                | true => expectedExpiry
                | false => pageExpiresAt
                },
              )
            switch expectedScope == page.cacheScope {
            | true => ()
            | false =>
              failure := Some(Message("MCP tools/list pages use inconsistent cache scopes"))
            }
          | (Some(_), None) | (None, Some(_)) => JsError.throwWithMessage("Incomplete cache state")
          }
          tools := Array.concat(tools.contents, page.tools)
          switch tools.contents->Array.length > maxTools {
          | true => failure := Some(Message("MCP tools/list exceeded the tool limit"))
          | false =>
            switch page.nextCursor {
            | None => complete := true
            | Some(next) if utf8Bytes(next) > maxCursorBytes =>
              failure := Some(Message("MCP tools/list cursor exceeds the byte limit"))
            | Some(next) => cursor := Some(next)
            }
          }
        }
      }
    }
  }

  switch failure.contents {
  | Some(InvalidCursor(_)) if canRestart => await fetchTools(client, ~signal, ~canRestart=false)
  | Some(InvalidCursor(message)) | Some(Message(message)) => Error(message)
  | None =>
    Ok({
      tools: tools.contents,
      cacheScope: cacheScope.contents->Option.getOrThrow,
      expiresAt: expiresAt.contents->Option.getOrThrow,
    })
  }
}

let connect = async (client, ~signal=?): result<unit, string> => {
  client.connectController.contents->Option.forEach(controller =>
    controller->WebAPI.AbortController.abort
  )
  let generation = client.connectGeneration.contents + 1
  let controller = WebAPI.AbortController.make()
  client.connectGeneration := generation
  client.connectController := Some(controller)
  let signal = switch signal {
  | Some(signal) => WebAPI.AbortSignal.any([signal, controller.signal])
  | None => controller.signal
  }
  let ownsConnection = () => client.connectGeneration.contents == generation
  let finish = (result: result<unit, string>) => {
    switch ownsConnection() {
    | true => client.connectController := None
    | false => ()
    }
    result
  }
  switch client.cache.contents {
  | Some(cache) if Date.now() < cache.expiresAt =>
    client.state := Connected({tools: cache.tools, serverInfo: cache.serverInfo})
    finish(Ok())
  | Some(_) | None =>
    switch await fetchDiscovery(client, ~signal=Some(signal)) {
    | _ if !ownsConnection() => Error("Request cancelled")
    | Error(message) =>
      client.state := Error(message)
      finish(Error(message))
    | Ok(discovery)
      if !(discovery.result.supportedVersions->Array.includes(Types.protocolVersion)) =>
      let message = `MCP server does not support ${Types.protocolVersion}`
      client.state := Error(message)
      finish(Error(message))
    | Ok(discovery) =>
      switch await fetchTools(client, ~signal=Some(signal)) {
      | _ if !ownsConnection() => Error("Request cancelled")
      | Error(message) =>
        client.state := Error(message)
        finish(Error(message))
      | Ok(pages) =>
        let tools = ref([])
        let index = ref(0)
        let validationCancelled = ref(false)
        while index.contents < pages.tools->Array.length && !validationCancelled.contents {
          let definition = pages.tools[index.contents]->Option.getOrThrow
          switch await validateTool(definition, ~signal=Some(signal)) {
          | _ if !ownsConnection() => validationCancelled := true
          | Ok(tool) => tools := Array.concat(tools.contents, [tool])
          | Error(ValidationCancelled) => validationCancelled := true
          | Error(InvalidTool(reason)) =>
            Log.warning(
              ~ctx={"tool": definition.name, "reason": reason},
              "Excluded invalid remote MCP tool",
            )
          }
          index := index.contents + 1
        }
        let tools = tools.contents
        let catalogBytes =
          tools->Array.reduce(0, (total, tool) =>
            total +
            utf8Bytes(
              JSON.stringify(tool.definition->S.decodeOrThrow(~from=Types.Tool.schema, ~to=S.json)),
            )
          )
        switch ownsConnection() {
        | false => Error("Request cancelled")
        | true =>
          switch validationCancelled.contents {
          | true =>
            let message = "Request cancelled"
            client.state := Error(message)
            finish(Error(message))
          | false if catalogBytes > maxCatalogBytes =>
            let message = "MCP tool catalog exceeds the byte limit"
            client.state := Error(message)
            finish(Error(message))
          | false =>
            switch serverInfo(discovery.result) {
            | Error(message) =>
              client.state := Error(message)
              finish(Error(message))
            | Ok(serverInfo) =>
              let expiresAt = switch discovery.expiresAt < pages.expiresAt {
              | true => discovery.expiresAt
              | false => pages.expiresAt
              }
              client.cache := Some({tools, serverInfo, expiresAt})
              client.state := Connected({tools, serverInfo})
              finish(Ok())
            }
          }
        }
      }
    }
  }
}

@@live
let disconnect = client => {
  client.connectGeneration := client.connectGeneration.contents + 1
  client.connectController.contents->Option.forEach(controller =>
    controller->WebAPI.AbortController.abort
  )
  client.connectController := None
  client.state := Disconnected
}

let getToolsJson = client =>
  switch client.state.contents {
  | Connected({tools}) =>
    tools->Array.map(tool => tool.definition->S.decodeOrThrow(~from=Types.Tool.schema, ~to=S.json))
  | Disconnected | Error(_) => []
  }

let findTool = (client, name) =>
  switch client.state.contents {
  | Connected({tools}) => tools->Array.find(tool => tool.definition.name == name)
  | Disconnected | Error(_) => None
  }

let hasTool = (client, name) => client->findTool(name)->Option.isSome

let toolMetadata = (client, name) =>
  client->findTool(name)->Option.flatMap(tool => tool.definition._meta)

let validateToolOutput = async (tool, result, ~signal) =>
  switch tool.outputSchema {
  | None => Ok(result)
  | Some(schema) =>
    let json = result->S.decodeOrThrow(~from=Types.CallToolResult.schema, ~to=S.json)
    let structuredContent =
      json->JSON.Decode.object->Option.getOrThrow->Dict.get("structuredContent")
    switch structuredContent {
    | None => Error("Tool result is missing structuredContent required by outputSchema")
    | Some(value) =>
      switch await RemoteSchema.validateValue(~schema, ~value, ~signal?) {
      | Ok() => Ok(result)
      | Error(Cancelled) => Error("Request cancelled")
      | Error(TimedOut) => Error("Tool output validation timed out")
      | Error(Invalid(_) | WorkerFailed(_)) =>
        Error("Tool structuredContent does not match outputSchema")
      }
    }
  }

let rec executeToolWithRetry = async (
  client,
  ~name,
  ~arguments,
  ~onProgress,
  ~signal,
  ~canRelist,
): result<Types.CallToolResult.t, string> => {
  switch client->findTool(name) {
  | None => Error(`Tool not found: ${name}`)
  | Some(tool) =>
    let argumentJson = arguments->Option.getOr(Dict.make())->JSON.Encode.object
    switch await RemoteSchema.validateValue(
      ~schema=tool.inputSchema,
      ~value=argumentJson,
      ~signal?,
    ) {
    | Error(Cancelled) => Error("Request cancelled")
    | Error(TimedOut) => Error("Tool argument validation timed out")
    | Error(Invalid(_) | WorkerFailed(_)) => Error("Invalid tool arguments")
    | Ok() =>
      let customHeaders = Dict.make()
      switch CustomHeaders.apply(
        ~headers=customHeaders,
        ~arguments,
        ~annotations=tool.annotations,
      ) {
      | Error(message) => Error(message)
      | Ok() =>
        let id = nextRequestId(client)
        let request: Types.CallToolRequest.t = {
          jsonrpc: "2.0",
          id,
          method: "tools/call",
          params: {_meta: requestMeta(), name, arguments, inputResponses: None, requestState: None},
        }
        let body = request->S.decodeOrThrow(~from=Types.CallToolRequest.schema, ~to=S.json)
        let onNotification =
          onProgress->Option.map(callback => json => callback(JSON.stringify(json)))
        switch await post(
          client,
          ~id,
          ~method_="tools/call",
          ~name,
          ~body,
          ~customHeaders,
          ~signal?,
          ~onNotification?,
        ) {
        | Error(message) => Error(message)
        | Ok(json) if errorCode(json) == Some(-32020) && canRelist =>
          client.cache := None
          switch await connect(client, ~signal?) {
          | Error(message) => Error(message)
          | Ok() =>
            await executeToolWithRetry(
              client,
              ~name,
              ~arguments,
              ~onProgress,
              ~signal,
              ~canRelist=false,
            )
          }
        | Ok(json) =>
          switch resultFromResponse(json, Types.CallToolResult.schema) {
          | Error(message) => Error(message)
          | Ok(InputRequired) => Error("MCP tool requires additional input")
          | Ok(Complete(result)) => await validateToolOutput(tool, result, ~signal)
          }
        }
      }
    }
  }
}

let executeTool = async (client, ~name, ~arguments=?, ~onProgress=?, ~signal=?): result<
  Types.CallToolResult.t,
  string,
> => await executeToolWithRetry(client, ~name, ~arguments, ~onProgress, ~signal, ~canRelist=true)
