// Re-export from protocol package
type toolResult<'a> = AskTheLlmFrontmanProtocol.FrontmanProtocol__Tool.toolResult<'a>
module type Tool = AskTheLlmFrontmanProtocol.FrontmanProtocol__Tool.BrowserTool
