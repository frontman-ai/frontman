type toolResult<'a> = result<'a, string>

module type Metadata = {
  let name: string
  let description: string
  type input
  let inputSchema: S.t<input>
}

module type ServerTool = {
  include Metadata
  type output
  let outputSchema: S.t<output>
  let decodeInput: JSON.t => result<input, S.error>
  let encodeOutput: output => JSON.t
  let execute: (Agent__ToolExecutionContext.t, input) => promise<toolResult<output>>
}
