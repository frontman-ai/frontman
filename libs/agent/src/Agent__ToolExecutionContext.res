// Context provided to tools during execution
// Extracted to avoid circular dependency: Tool -> Config -> ToolsRegistry -> Tool

type t = {
  projectRoot: string,
}
