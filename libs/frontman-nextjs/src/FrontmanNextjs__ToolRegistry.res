// Tool registry - holds all available tools

module Protocol = AskTheLlmFrontmanProtocol
module Tool = Protocol.FrontmanProtocol__Tool

type tool = module(Tool.ServerTool)

type t = {
  tools: array<tool>,
}

// Create registry with default tools
let make = (): t => {
  tools: [
    module(FrontmanNextjs__Tool__ReadFile),
    module(FrontmanNextjs__Tool__WriteFile),
    module(FrontmanNextjs__Tool__ListFiles),
    module(FrontmanNextjs__Tool__FileExists),
  ],
}

// Get tool by name
let getToolByName = (registry: t, name: string): option<tool> => {
  registry.tools->Array.find(m => {
    module T = unpack(m)
    T.name == name
  })
}

// JSONSchema.t is JSON.t at runtime
external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

// Serialize a single tool to relay format
let serializeTool = (m: tool): Protocol.FrontmanProtocol__Relay.remoteTool => {
  module T = unpack(m)
  {
    name: T.name,
    description: T.description,
    inputSchema: T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
  }
}

// Get all tools as definitions
let getToolDefinitions = (registry: t): array<Protocol.FrontmanProtocol__Relay.remoteTool> => {
  registry.tools->Array.map(serializeTool)
}
