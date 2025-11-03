// Tool module type for registry integration
type toolResult<'a> = result<'a, string>

module type T = {
  let name: string
  let description: string
  type input
  type output
  let inputSchema: S.t<input>
  let outputSchema: S.t<output>
  let decodeInput: JSON.t => result<input, S.error>
  let encodeOutput: output => JSON.t
  let execute: (Agent__ToolExecutionContext.t, input) => promise<toolResult<output>>
}
