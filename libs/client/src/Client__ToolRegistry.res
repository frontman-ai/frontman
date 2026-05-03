// Client-side Tool Registry - composable browser tool collection
// Mirrors the server-side FrontmanCore__ToolRegistry pattern

module FrontmanClient = FrontmanAiFrontmanClient
module MCPServer = FrontmanClient.FrontmanClient__MCP__Server
module Tool = FrontmanClient.FrontmanClient__MCP__Tool

type tool = module(Tool.Tool)

type t = {tools: array<tool>}

let coreBrowserTools: array<tool> = [
  module(Client__Tool__TakeScreenshot),
  module(Client__Tool__ExecuteJs),
  module(Client__Tool__SetDeviceMode),
  module(Client__Tool__GetInteractiveElements),
  module(Client__Tool__InteractWithElement),
  module(Client__Tool__GetDom),
  module(Client__Tool__SearchText),
  module(Client__Tool__Question),
]

// Register all tools from registry into an MCP server
let registerAll = (registry: t, mcpServer: MCPServer.t): MCPServer.t => {
  registry.tools->Array.reduce(mcpServer, (srv, toolModule) =>
    srv->MCPServer.registerToolModule(toolModule)
  )
}

// Build a registry with core browser tools + framework-specific tools
let forFramework = (framework: Client__RuntimeConfig.frameworkId): t => {
  let tools = switch framework {
  | Astro =>
    let getPreviewDoc = Client__Tool__ElementResolver.getPreviewDoc
    Array.concat(
      coreBrowserTools,
      FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry.browserTools(~getPreviewDoc),
    )
  | Nextjs | Vite | Wordpress => coreBrowserTools
  }
  {tools: tools}
}
