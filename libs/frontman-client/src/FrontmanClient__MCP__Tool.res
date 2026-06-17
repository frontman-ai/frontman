// Re-export from protocol package
module ProtocolTool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

module type Tool = ProtocolTool.BrowserTool
module ToolNames = ProtocolTool.ToolNames

let jsonResult = ProtocolTool.jsonResult
let imageResult = ProtocolTool.imageResult
