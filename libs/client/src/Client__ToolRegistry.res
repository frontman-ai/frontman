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

let registerAll = (registry: t, mcpServer: MCPServer.t): MCPServer.t => {
  registry.tools->Array.reduce(mcpServer, (srv, toolModule) =>
    srv->MCPServer.registerToolModule(toolModule)
  )
}

let forFramework = (framework: Client__RuntimeConfig.frameworkId): t => {
  let frameworkTools = switch framework {
  | Astro =>
    let getPreviewDoc = Client__Tool__PreviewContext.get
    Array.concat(
      [
        FrontmanAiAstroBrowser.FrontmanAstroBrowser__Tool__GetDom.make(
          ~getPreviewDoc,
          ~inspect=Client__Tool__GetDom.inspect,
          ~description=Client__Tool__GetDom.description,
        ),
      ],
      FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry.browserTools(~getPreviewDoc),
    )
  | Nextjs | Vite | Wordpress => []
  }
  let sharedTools = coreBrowserTools->Array.filter(coreTool => {
    module Core = unpack(coreTool)
    !(
      frameworkTools->Array.some(frameworkTool => {
        module Framework = unpack(frameworkTool)
        Core.name == Framework.name
      })
    )
  })
  {tools: Array.concat(sharedTools, frameworkTools)}
}
