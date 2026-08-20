module Protocol = FrontmanAiFrontmanProtocol
module JsonRpc = Protocol.FrontmanProtocol__JsonRpc
module MCP = Protocol.FrontmanProtocol__MCP
module RequestHeaders = FrontmanCore__MCP__RequestHeaders

@schema
type unsupportedVersionData = {
  requested: string,
  supported: array<string>,
}

@schema
type standardErrorResponse = {
  @live
  jsonrpc: string,
  @live
  id: option<JsonRpc.Id.t>,
  @live
  error: JsonRpc.RpcError.t,
}

let rpcError = error =>
  switch error {
  | RequestHeaders.HeaderMismatch(header) =>
    JsonRpc.RpcError.make(
      ~code=MCP.ModernErrorCode.headerMismatch,
      ~message=`Header mismatch: ${header}`,
      ~data=None,
    )
  | RequestHeaders.UnsupportedProtocolVersion({requested, supported}) =>
    let data: unsupportedVersionData = {requested, supported}
    let data = data->S.decodeOrThrow(~from=unsupportedVersionDataSchema, ~to=S.json)
    JsonRpc.RpcError.make(
      ~code=MCP.ModernErrorCode.unsupportedProtocolVersion,
      ~message="Unsupported protocol version",
      ~data=Some(data),
    )
  }

let make = (
  ~id: JsonRpc.Id.t,
  ~error: RequestHeaders.validationError,
): WebAPI.FetchAPI.response => {
  let data = JsonRpc.Response.makeErrorPayloadWithId(~id, ~error=rpcError(error))
  WebAPI.Response.jsonR(~data, ~init={status: 400})
}

let invalidRequest = (~id: option<JsonRpc.Id.t>): WebAPI.FetchAPI.response => {
  let payload: standardErrorResponse = {
    jsonrpc: JsonRpc.version,
    id,
    error: JsonRpc.RpcError.make(
      ~code=MCP.ModernErrorCode.invalidRequest,
      ~message="Invalid Request",
      ~data=None,
    ),
  }
  let data = payload->S.decodeOrThrow(~from=standardErrorResponseSchema, ~to=S.json)
  WebAPI.Response.jsonR(~data, ~init={status: 400})
}

let parseError = (): WebAPI.FetchAPI.response => {
  let payload: standardErrorResponse = {
    jsonrpc: JsonRpc.version,
    id: None,
    error: JsonRpc.RpcError.make(
      ~code=MCP.ModernErrorCode.parseError,
      ~message="Parse error: Invalid JSON",
      ~data=None,
    ),
  }
  let data = payload->S.decodeOrThrow(~from=standardErrorResponseSchema, ~to=S.json)
  WebAPI.Response.jsonR(~data, ~init={status: 400})
}

let invalidRequestMetadata = (~id: JsonRpc.Id.t): WebAPI.FetchAPI.response => {
  let error = JsonRpc.RpcError.make(
    ~code=MCP.ModernErrorCode.invalidParams,
    ~message="Invalid request metadata",
    ~data=None,
  )
  let data = JsonRpc.Response.makeErrorPayloadWithId(~id, ~error)
  WebAPI.Response.jsonR(~data, ~init={status: 400})
}

let missingRequiredClientCapability = (
  ~id: JsonRpc.Id.t,
  ~requiredCapabilities: MCP.ClientCapabilities.t,
): WebAPI.FetchAPI.response => {
  let fields: MCP.MissingRequiredClientCapabilityError.dataFields = {
    requiredCapabilities: requiredCapabilities,
  }
  let data =
    fields->S.decodeOrThrow(~from=MCP.MissingRequiredClientCapabilityError.dataSchema, ~to=S.json)
  let error = JsonRpc.RpcError.make(
    ~code=MCP.ModernErrorCode.missingRequiredClientCapability,
    ~message="Missing required client capability",
    ~data=Some(data),
  )
  let data = JsonRpc.Response.makeErrorPayloadWithId(~id, ~error)
  WebAPI.Response.jsonR(~data, ~init={status: 400})
}

let invalidMethodParams = (~id: JsonRpc.Id.t): WebAPI.FetchAPI.response => {
  let error = JsonRpc.RpcError.make(
    ~code=MCP.ModernErrorCode.invalidParams,
    ~message="Invalid method parameters",
    ~data=None,
  )
  let data = JsonRpc.Response.makeErrorPayloadWithId(~id, ~error)
  WebAPI.Response.jsonR(~data, ~init={status: 200})
}

let unknownTool = (~id: JsonRpc.Id.t, ~name: string): WebAPI.FetchAPI.response => {
  let error = JsonRpc.RpcError.make(
    ~code=MCP.ModernErrorCode.invalidParams,
    ~message=`Unknown tool: ${name}`,
    ~data=None,
  )
  let data = JsonRpc.Response.makeErrorPayloadWithId(~id, ~error)
  WebAPI.Response.jsonR(~data, ~init={status: 200})
}

let toolOutputSchemaMismatch = (~id: JsonRpc.Id.t): WebAPI.FetchAPI.response => {
  let error = JsonRpc.RpcError.make(
    ~code=MCP.ModernErrorCode.internalError,
    ~message="Tool output did not match output schema",
    ~data=None,
  )
  let data = JsonRpc.Response.makeErrorPayloadWithId(~id, ~error)
  WebAPI.Response.jsonR(~data, ~init={status: 200})
}

let methodNotFound = (~id: JsonRpc.Id.t): WebAPI.FetchAPI.response => {
  let error = JsonRpc.RpcError.make(
    ~code=MCP.ModernErrorCode.methodNotFound,
    ~message="Method not found",
    ~data=None,
  )
  let data = JsonRpc.Response.makeErrorPayloadWithId(~id, ~error)
  WebAPI.Response.jsonR(~data, ~init={status: 404})
}
