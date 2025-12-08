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

// Query Next.js error portal from shadow DOM
let getNextJsPortalError: WebAPI.DOMAPI.document => option<string> = %raw(`
  function(doc) {
    try {
      const portal = doc.querySelector("nextjs-portal");
      if (!portal || !portal.shadowRoot) return undefined;
      const errorDesc = portal.shadowRoot.querySelector("#nextjs__container_errors_desc");
      if (!errorDesc || !errorDesc.innerText) return undefined;
      return errorDesc.innerText;
    } catch (e) {
      return undefined;
    }
  }
`)

let execute = async (input: input): toolResult<output> => {
  let state = AskTheLlmReactStatestore.StateStore.getState(Client__State__Store.store)
  let limit = input.limit->Option.getOr(100)

  let task = state.currentTaskId->Option.flatMap(taskId => Dict.get(state.tasks, taskId))

  let consoleErrors: array<error> =
    task
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

  // If no console errors, check for Next.js portal errors
  let errors = if Array.length(consoleErrors) == 0 {
    let nextJsError =
      task
      ->Option.flatMap(task => task.previewFrame.contentDocument)
      ->Option.flatMap(getNextJsPortalError)

    switch nextJsError {
    | Some(message) => [
        {
          createdAt: Date.now(),
          message,
          stack: "",
          name: Some("NextJsError"),
        },
      ]
    | None => []
    }
  } else {
    consoleErrors
  }

  Ok({errors: errors})
}
