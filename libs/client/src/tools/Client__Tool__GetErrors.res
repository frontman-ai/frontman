// Client tool that demonstrates accessing client state
// Lives in client library, implements Client__Tool.T

include AskTheLlmAgent.Agent.ClientToolMetadata.GetErrors

@schema
type error = {
  createdAt: @s.matches(AskTheLlmAgent.Agent__DateISO.schema) Js.Date.t,
  message: string,
  stack: string,
  name: option<string>,
}

@schema
type output = {errors: array<error>}

let decodeInput = (json: JSON.t): result<input, S.error> => {
  try {
    Ok(json->S.parseJsonOrThrow(inputSchema))
  } catch {
  | S.Error(error) => Error(error)
  }
}

let encodeOutput = (output: output): JSON.t => {
  output->S.reverseConvertToJsonOrThrow(outputSchema)
}

let execute = async (state: Client__State__Types.state, _input: input) => {
  let errors: array<error> =
    state.currentTaskId
    ->Option.flatMap(Dict.get(state.tasks, _))
    ->Option.map(task => task.previewFrame.errors)
    ->Option.getOr([])
    ->Array.map(clientError => {
      {
        createdAt: clientError.createdAt,
        message: clientError.message,
        stack: clientError.stack,
        name: clientError.name,
      }
    })

  Ok({
    errors: errors,
  })
}
