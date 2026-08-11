module ProtocolTool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

module type Tool = ProtocolTool.BrowserTool
module ToolNames = ProtocolTool.ToolNames

@@live
let structuredResult = ProtocolTool.structuredResult

@@live
let unstructuredResult = ProtocolTool.unstructuredResult

@@live
let imageResult = ProtocolTool.imageResult
