// MCP Tool module type for type-safe browser-side tool definitions
// Similar to Agent__Tool.res but for client-side MCP tools

type toolResult<'a> = result<'a, string>

module type Tool = {
  let name: string
  let description: string
  type input
  type output
  let inputSchema: S.t<input>
  let outputSchema: S.t<output>
  let execute: input => promise<toolResult<output>>
}
