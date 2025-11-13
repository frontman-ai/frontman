// Example client-side tool that gets the current page title
// This tool executes in the browser, not on the server

let name = "get_page_title"
let description = "Gets the title of the current page"

// Empty object for input since tool takes no parameters
// Anthropic requires type: "object", so we use an object with optional field
@schema
type input = {@s.optional _unused: option<string>}

@schema
type output = {title: string}

let decodeInput = (json: JSON.t): result<input, S.error> => {
  try {
    Ok(json->S.parseOrThrow(inputSchema))
  } catch {
  | S.Error(error) => Error(error)
  }
}

let encodeOutput = (output: output): JSON.t => {
  output->S.reverseConvertToJsonOrThrow(outputSchema)
}

let execute = async (_ctx: Agent__ToolExecutionContext.t, _input: input) => {
  Ok({title: WebAPI.Global.document.title})
}
