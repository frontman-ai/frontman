// Re-export from protocol package
module ProtocolTool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

module type Tool = ProtocolTool.BrowserTool
module ToolNames = ProtocolTool.ToolNames

@@live
let jsonResult = ProtocolTool.jsonResult

@@live
let imageResult = ProtocolTool.imageResult
