// Client tool that returns console errors from the web preview
// Implements BrowserTool interface, accesses state internally

module Tool = AskTheLlmFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = "get_errors"
let description = "Get console errors from the web preview frame. Returns an array of error objects with message, stack trace, and timestamp."

@schema
type input = {
  @s.describe("Maximum number of errors to return")
  limit: option<int>,
}

@schema
type error = {
  @s.describe("Unix timestamp in milliseconds")
  createdAt: float,
  message: string,
  stack: string,
  name: option<string>,
}

@schema
type output = {errors: array<error>}

let execute = async (input: input): toolResult<output> => {
  let state = AskTheLlmReactStatestore.StateStore.getState(Client__State__Store.store)
  let limit = input.limit->Option.getOr(100)

  let errors: array<error> =
    state.currentTaskId
    ->Option.flatMap(taskId => Dict.get(state.tasks, taskId))
    ->Option.map(task => task.previewFrame.errors)
    ->Option.getOr([])
    ->Array.slice(~start=0, ~end=limit)
    ->Array.map(clientError => {
      {
        createdAt: clientError.createdAt->Js.Date.getTime,
        message: clientError.message,
        stack: clientError.stack,
        name: clientError.name,
      }
    })

  Ok({errors: errors})
}
