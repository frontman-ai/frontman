// Client-side Tool Registry - composable browser tool collection
// Mirrors the server-side FrontmanCore__ToolRegistry pattern

module FrontmanClient = FrontmanFrontmanClient
module MCPServer = FrontmanClient.FrontmanClient__MCP__Server
module Tool = FrontmanClient.FrontmanClient__MCP__Tool

type tool = module(Tool.Tool)

type t = {tools: array<tool>}

// Create empty registry
let make = (): t => {
  tools: [],
}

let coreBrowserTools = (): t => {
  tools: [
    module(Client__Tool__TakeScreenshot),
    module(Client__Tool__Navigate),
    module(Client__Tool__SetDeviceMode),
    module(Client__Tool__GetInteractiveElements),
    module(Client__Tool__InteractWithElement),
    module(Client__Tool__GetDom),
    module(Client__Tool__SearchText),
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

// Register all tools from registry into an MCP server
let registerAll = (registry: t, mcpServer: MCPServer.t): MCPServer.t => {
  registry.tools->Array.reduce(mcpServer, (srv, toolModule) =>
    srv->MCPServer.registerToolModule(toolModule)
  )
}

// Get count of tools
let count = (registry: t): int => {
  registry.tools->Array.length
}
