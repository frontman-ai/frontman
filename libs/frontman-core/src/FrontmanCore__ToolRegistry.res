// Composable Tool Registry - holds and manages tools

module Protocol = FrontmanFrontmanProtocol
module Tool = Protocol.FrontmanProtocol__Tool
module Relay = Protocol.FrontmanProtocol__Relay

type tool = module(Tool.ServerTool)

type t = {tools: array<tool>}

// Create empty registry
let make = (): t => {
  tools: [],
}

let coreTools = (): t => {
  tools: [
    module(FrontmanCore__Tool__ReadFile),
    module(FrontmanCore__Tool__WriteFile),
    module(FrontmanCore__Tool__ListFiles),
    module(FrontmanCore__Tool__FileExists),
    module(FrontmanCore__Tool__LoadAgentInstructions),
    module(FrontmanCore__Tool__Grep),
    module(FrontmanCore__Tool__SearchFiles),
    module(FrontmanCore__Tool__Lighthouse),
  ],
}

// Add tools to registry
let addTools = (registry: t, newTools: array<tool>): t => {
  tools: Array.concat(registry.tools, newTools),
}

// Merge two registries
let merge = (a: t, b: t): t => {
  tools: Array.concat(a.tools, b.tools),
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
let serializeTool = (m: tool): Relay.remoteTool => {
  module T = unpack(m)
  {
    name: T.name,
    description: T.description,
    inputSchema: T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
    visibleToAgent: T.visibleToAgent,
  }
}

// Get all tools as definitions
let getToolDefinitions = (registry: t): array<Relay.remoteTool> => {
  registry.tools->Array.map(serializeTool)
}

// Get count of tools
let count = (registry: t): int => {
  registry.tools->Array.length
}
