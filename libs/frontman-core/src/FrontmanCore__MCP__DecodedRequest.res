module RequestAuthorities = FrontmanCore__MCP__RequestAuthorities
module RequestEnvelope = FrontmanCore__MCP__RequestEnvelope
module RequestHeaders = FrontmanCore__MCP__RequestHeaders
module ErrorResponse = FrontmanCore__MCP__ErrorResponse
module MethodRequest = FrontmanCore__MCP__MethodRequest
module CustomHeaders = FrontmanCore__MCP__CustomHeaders
module RawHeaders = FrontmanCore__MCP__RawHeaders
module ToolRegistry = FrontmanCore__ToolRegistry
module CoreServer = FrontmanCore__Server
module JsonSchema = FrontmanCore__MCP__JsonSchema
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

type requiredClientCapabilities = {
  value: MCP.ClientCapabilities.t,
  schema: S.t<MCP.ClientCapabilities.t>,
}

type serverIdentity = {
  serverName: string,
  serverVersion: string,
}

type accepted = {
  envelope: RequestEnvelope.t,
  authorities: RequestAuthorities.t,
  metadata: MCP.RequestMeta.t,
  registry: ToolRegistry.t,
  request: MethodRequest.selected,
}

type withAuthorities = {
  envelope: RequestEnvelope.t,
  authorities: RequestAuthorities.t,
}

type withMetadata = {
  envelope: RequestEnvelope.t,
  authorities: RequestAuthorities.t,
  metadata: MCP.RequestMeta.t,
}

type withMethod = {
  envelope: RequestEnvelope.t,
  authorities: RequestAuthorities.t,
  metadata: MCP.RequestMeta.t,
  request: MethodRequest.t,
}

type t =
  | Accepted(accepted)
  | Completed(WebAPI.FetchAPI.response)
  | Rejected(WebAPI.FetchAPI.response)

let parseMetadata = metadata => {
  switch metadata {
  | None => Error()
  | Some(metadata) =>
    try {
      Ok(metadata->S.parseOrThrow(~to=MCP.RequestMeta.schema))
    } catch {
    | S.Exn(_) => Error()
    | exn => throw(exn)
    }
  }
}

let hasRequiredClientCapabilities = (~metadata, ~required) => {
  let fields = metadata->S.parseOrThrow(~to=MCP.RequestMeta.knownFieldsSchema)
  try {
    fields.clientCapabilities
    ->MCP.ClientCapabilities.toJson
    ->S.parseOrThrow(~to=required.schema)
    ->ignore
    true
  } catch {
  | S.Exn(_) => false
  | exn => throw(exn)
  }
}

let validateHeaders = (~headers, envelope): result<withAuthorities, WebAPI.FetchAPI.response> => {
  let authorities = RequestAuthorities.extract(envelope)
  switch RequestHeaders.validate(~headers, ~request=authorities.headers) {
  | Error(error) => Error(ErrorResponse.make(~id=envelope.id, ~error))
  | Ok() => Ok({envelope, authorities})
  }
}

let validateMetadata = (request: withAuthorities): result<
  withMetadata,
  WebAPI.FetchAPI.response,
> => {
  let {envelope, authorities} = request
  switch parseMetadata(authorities.metadata) {
  | Error() => Error(ErrorResponse.invalidRequestMetadata(~id=envelope.id))
  | Ok(metadata) => Ok({envelope, authorities, metadata})
  }
}

let validateCapabilities = (~requiredClientCapabilities, request: withMetadata) => {
  switch requiredClientCapabilities {
  | Some(required) if !hasRequiredClientCapabilities(~metadata=request.metadata, ~required) =>
    Error(
      ErrorResponse.missingRequiredClientCapability(
        ~id=request.envelope.id,
        ~requiredCapabilities=required.value,
      ),
    )
  | None | Some(_) => Ok(request)
  }
}

let validateMethod = (validated: withMetadata): result<withMethod, WebAPI.FetchAPI.response> => {
  let {envelope, authorities, metadata} = validated
  switch MethodRequest.validate(envelope) {
  | Error(MethodRequest.MethodNotFound) => Error(ErrorResponse.methodNotFound(~id=envelope.id))
  | Error(MethodRequest.InvalidParams) => Error(ErrorResponse.invalidMethodParams(~id=envelope.id))
  | Ok(request) => Ok({envelope, authorities, metadata, request})
  }
}

let selectTool = (~registry, validated: withMethod): result<accepted, WebAPI.FetchAPI.response> => {
  let {envelope, authorities, metadata, request} = validated
  switch MethodRequest.select(~registry, request) {
  | Error(MethodRequest.UnknownTool(name)) =>
    Error(ErrorResponse.unknownTool(~id=envelope.id, ~name))
  | Ok(request) => Ok({envelope, authorities, metadata, registry, request})
  }
}

let validateCustomHeaders = (~rawHeaders, accepted: accepted): result<
  accepted,
  WebAPI.FetchAPI.response,
> => {
  switch accepted.request {
  | MethodRequest.SelectedDiscover(_) | MethodRequest.SelectedListTools(_) => Ok(accepted)
  | MethodRequest.SelectedCallTool({params, tool}) =>
    module SelectedTool = unpack(tool)
    switch SelectedTool.inputSchema->S.toJSONSchema->CustomHeaders.discover {
    | Error(_) => failwith("Invalid x-mcp-header annotation in selected tool schema")
    | Ok([]) => Ok(accepted)
    | Ok(annotations) =>
      let rawHeaders = switch rawHeaders {
      | Some(rawHeaders) => rawHeaders
      | None => failwith("Raw physical headers are required for x-mcp-header validation")
      }
      switch CustomHeaders.validate(~rawHeaders, ~arguments=params.arguments, ~annotations) {
      | Ok() => Ok(accepted)
      | Error(CustomHeaders.HeaderMismatch(header)) =>
        Error(
          ErrorResponse.make(
            ~id=accepted.envelope.id,
            ~error=RequestHeaders.HeaderMismatch(header),
          ),
        )
      }
    }
  }
}

let completeToolResult = (~id, ~result, ~serverIdentity): WebAPI.FetchAPI.response => {
  let result = result->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json)
  let result = switch serverIdentity {
  | None => result
  | Some({serverName, serverVersion}) =>
    let fields = result->S.parseOrThrow(~to=S.dict(S.json))
    let metadata =
      fields
      ->Dict.get("_meta")
      ->Option.mapOr(Dict.make(), metadata => metadata->S.parseOrThrow(~to=S.dict(S.json)))
    let serverMetadata =
      CoreServer.resultMeta(~serverName, ~serverVersion)->S.decodeOrThrow(
        ~from=MCP.ResultMeta.schema,
        ~to=S.dict(S.json),
      )
    serverMetadata->Dict.forEachWithKey((value, key) => metadata->Dict.set(key, value))
    fields->Dict.set("_meta", JSON.Encode.object(metadata))
    JSON.Encode.object(fields)
  }
  let data = JsonRpc.Response.makeSuccessPayloadWithId(~id, ~result)
  WebAPI.Response.jsonR(~data, ~init={status: 200})
}

let completeDiscoverResult = (~id, ~result): WebAPI.FetchAPI.response => {
  let result = result->S.decodeOrThrow(~from=MCP.DiscoverResult.schema, ~to=S.json)
  let data = JsonRpc.Response.makeSuccessPayloadWithId(~id, ~result)
  WebAPI.Response.jsonR(~data, ~init={status: 200})
}

let completeListToolsResult = (~id, ~result): WebAPI.FetchAPI.response => {
  let result = result->S.decodeOrThrow(~from=MCP.ListToolsResult.schema, ~to=S.json)
  let data = JsonRpc.Response.makeSuccessPayloadWithId(~id, ~result)
  WebAPI.Response.jsonR(~data, ~init={status: 200})
}

type callToolResultFields = {
  @live
  content: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.t>,
  structuredContent: option<JSON.t>,
  @live
  isError: option<bool>,
  @live
  _meta: option<MCP.ResultMeta.t>,
  @live
  resultType: string,
}

let callToolResultFieldsSchema = S.object(s => {
  content: s.field(
    "content",
    S.array(FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.schema),
  ),
  structuredContent: s.field("structuredContent", S.option(S.json)),
  isError: s.field("isError", S.option(S.bool)),
  _meta: s.field("_meta", S.option(MCP.ResultMeta.schema)),
  resultType: s.field("resultType", S.literal("complete")),
})

let invalidToolArguments = (~id, ~serverIdentity) => {
  let result = MCP.CallToolResult.makeError("Invalid tool arguments")
  completeToolResult(~id, ~result, ~serverIdentity)
}

let validateToolOutput = async (~tool: ToolRegistry.tool, result: MCP.CallToolResult.t): result<
  MCP.CallToolResult.t,
  unit,
> => {
  module SelectedTool = unpack(tool)
  let fields =
    result->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=callToolResultFieldsSchema)
  switch SelectedTool.outputJsonSchema {
  | None => Ok(result)
  | Some(schema) =>
    switch fields.structuredContent {
    | Some(structuredContent)
      if await JsonSchema.validateBounded(
        schema->ToolRegistry.jsonSchemaAsJson,
        structuredContent,
      ) =>
      Ok(result)
    | None | Some(_) => Error()
    }
  }
}

let validateToolArguments = (~serverIdentity, accepted: accepted): result<
  accepted,
  WebAPI.FetchAPI.response,
> => {
  switch accepted.request {
  | MethodRequest.SelectedDiscover(_) | MethodRequest.SelectedListTools(_) => Ok(accepted)
  | MethodRequest.SelectedCallTool({params, tool}) =>
    module SelectedTool = unpack(tool)
    let arguments =
      params.arguments
      ->Option.getOr(Dict.make())
      ->S.decodeOrThrow(~from=S.dict(S.json), ~to=S.json)
    try {
      arguments->S.parseOrThrow(~to=SelectedTool.inputSchema)->ignore
      Ok(accepted)
    } catch {
    | S.Exn(_) => Error(invalidToolArguments(~id=accepted.envelope.id, ~serverIdentity))
    | exn => throw(exn)
    }
  }
}

let execute = async (
  ~ctx: CoreServer.executionContext,
  ~serverName: string,
  ~serverVersion: string,
  accepted: accepted,
): t => {
  switch accepted.request {
  | MethodRequest.SelectedDiscover(_) =>
    Completed(
      completeDiscoverResult(
        ~id=accepted.envelope.id,
        ~result=CoreServer.discoverResult(~serverName, ~serverVersion),
      ),
    )
  | MethodRequest.SelectedListTools(_) =>
    Completed(
      completeListToolsResult(
        ~id=accepted.envelope.id,
        ~result=CoreServer.listToolsResult(
          ~registry=accepted.registry,
          ~serverName,
          ~serverVersion,
        ),
      ),
    )
  | MethodRequest.SelectedCallTool({params, tool}) =>
    let execution = await CoreServer.executeSelectedTool(~tool, ~ctx, ~arguments=params.arguments)
    let result = switch execution {
    | CoreServer.Ok(result) => result
    | CoreServer.InvalidInput(_) => MCP.CallToolResult.makeError("Invalid tool arguments")
    | CoreServer.ExecutionError(_) => MCP.CallToolResult.makeError("Tool execution failed")
    }
    switch await result->validateToolOutput(~tool) {
    | Ok(result) =>
      Completed(
        completeToolResult(
          ~id=accepted.envelope.id,
          ~result,
          ~serverIdentity=Some({serverName, serverVersion}),
        ),
      )
    | Error() => Completed(ErrorResponse.toolOutputSchemaMismatch(~id=accepted.envelope.id))
    }
  }
}

let validate = (
  ~headers: WebAPI.FetchAPI.headers,
  ~rawHeaders: option<RawHeaders.t>=None,
  ~json: JSON.t,
  ~registry: ToolRegistry.t,
  ~requiredClientCapabilities: option<requiredClientCapabilities>=None,
  ~serverIdentity: option<serverIdentity>=None,
): t => {
  let result =
    RequestEnvelope.classify(json)
    ->Result.mapError(error =>
      switch error {
      | RequestEnvelope.InvalidEnvelopeOrDirection =>
        ErrorResponse.invalidRequest(~id=RequestEnvelope.recoverId(json))
      }
    )
    ->Result.flatMap(envelope => validateHeaders(~headers, envelope))
    ->Result.flatMap(validateMetadata)
    ->Result.flatMap(request => validateCapabilities(~requiredClientCapabilities, request))
    ->Result.flatMap(validateMethod)
    ->Result.flatMap(request => selectTool(~registry, request))
    ->Result.flatMap(request => validateCustomHeaders(~rawHeaders, request))

  switch result {
  | Ok(request) =>
    switch validateToolArguments(~serverIdentity, request) {
    | Ok(request) => Accepted(request)
    | Error(response) => Completed(response)
    }
  | Error(response) => Rejected(response)
  }
}
