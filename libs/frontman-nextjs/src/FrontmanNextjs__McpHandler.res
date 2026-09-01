module Core = FrontmanAiFrontmanCore
module Endpoint = Core.FrontmanCore__MCP__Endpoint
module NodeHttp = FrontmanBindings.NodeHttp
module Config = FrontmanNextjs__Config
module ToolRegistry = FrontmanNextjs__ToolRegistry
module NodeApiAdapter = FrontmanNextjs__NodeApiAdapter

type handler = (NodeHttp.incomingMessage, NodeHttp.serverResponse) => promise<unit>

let make = (configInput: Config.jsConfigInput): handler => {
  let config = Config.makeFromObject(configInput)
  let security = switch config.mcpSecurity {
  | Some(security) => security
  | None => failwith("Frontman createMcpHandler requires explicit mcp security configuration")
  }
  let endpointConfig: Endpoint.config = {
    security,
    registry: ToolRegistry.make(),
    projectRoot: config.projectRoot,
    sourceRoot: config.sourceRoot,
    serverName: config.serverName,
    serverVersion: config.serverVersion,
    allowedPreflightHeaders: [],
  }
  async (request, response) => {
    switch await NodeApiAdapter.handleEndpoint(request, response, ~config=endpointConfig) {
    | NodeApiAdapter.Chassis.Responded
    | NodeApiAdapter.Chassis.Cancelled
    | NodeApiAdapter.Chassis.TimedOut => ()
    | NodeApiAdapter.Chassis.Passed => failwith("The Next.js MCP endpoint passed through")
    }
  }
}
