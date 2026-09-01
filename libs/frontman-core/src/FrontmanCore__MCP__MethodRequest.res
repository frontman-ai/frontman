module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP
module RequestEnvelope = FrontmanCore__MCP__RequestEnvelope
module ToolRegistry = FrontmanCore__ToolRegistry

type t =
  | Discover(MCP.DiscoverRequest.params)
  | ListTools(MCP.ListToolsRequest.params)
  | CallTool(MCP.CallToolRequestParams.t)

type validationError =
  | MethodNotFound
  | InvalidParams

type selected =
  | SelectedDiscover(MCP.DiscoverRequest.params)
  | SelectedListTools(MCP.ListToolsRequest.params)
  | SelectedCallTool({params: MCP.CallToolRequestParams.t, tool: ToolRegistry.tool})

type selectionError = UnknownTool(string)

let parseKnown = (~raw, ~schema, ~make) => {
  try {
    Ok(raw->S.parseOrThrow(~to=schema)->make)
  } catch {
  | S.Exn(_) => Error(InvalidParams)
  | exn => throw(exn)
  }
}

let validateListTools = raw => {
  switch parseKnown(~raw, ~schema=MCP.ListToolsRequest.schema, ~make=request => ListTools(
    request.params,
  )) {
  | Ok(ListTools({cursor: Some(_)})) => Error(InvalidParams)
  | result => result
  }
}

let validate = (envelope: RequestEnvelope.t): result<t, validationError> => {
  switch envelope.method {
  | "server/discover" =>
    parseKnown(~raw=envelope.raw, ~schema=MCP.DiscoverRequest.schema, ~make=request => Discover(
      request.params,
    ))
  | "tools/list" => validateListTools(envelope.raw)
  | "tools/call" =>
    parseKnown(~raw=envelope.raw, ~schema=MCP.CallToolRequest.schema, ~make=request => CallTool(
      request.params,
    ))
  | _ => Error(MethodNotFound)
  }
}

let select = (~registry: ToolRegistry.t, request: t): result<selected, selectionError> => {
  switch request {
  | Discover(params) => Ok(SelectedDiscover(params))
  | ListTools(params) => Ok(SelectedListTools(params))
  | CallTool(params) =>
    switch registry->ToolRegistry.getToolByName(params.name) {
    | Some(tool) => Ok(SelectedCallTool({params, tool}))
    | None => Error(UnknownTool(params.name))
    }
  }
}
