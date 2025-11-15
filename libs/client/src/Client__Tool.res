type toolResult<'a> = AskTheLlmAgent.Agent__Tool.toolResult<'a>

module type T = {
  include AskTheLlmAgent.Agent__Tool.Metadata
  type output
  let outputSchema: S.t<output>
  let decodeInput: JSON.t => result<input, S.error>
  let encodeOutput: output => JSON.t
  let execute: (Client__State__Types.state, input) => promise<toolResult<output>>
}
