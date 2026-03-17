// Client tool that asks the user questions via an interactive drawer.
// The execute function returns a promise that blocks until the user responds.
// The server routes this as an interactive MCP tool call (24h safety-net timeout).

S.enableJson()
module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool

type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.question
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Interactive

let description = `Ask the user one or more questions. Each question has a header, body text, and predefined options. The user can select options, type a custom answer, or skip. Use this tool when you need clarification or a decision from the user before proceeding.

Guidelines:
- Keep questions concise and actionable
- Provide clear, distinct options with helpful descriptions
- Set multiple: true when more than one option can apply
- Group related questions into a single call when possible`

@schema
type input = {
  @s.describe("Array of questions to ask the user")
  questions: array<Client__Question__Types.questionItem>,
}

// Per-question answer in the tool output
@schema
type questionAnswerOutput = {
  question: string,
  answer: option<array<string>>,
}

@schema
type output = {
  @s.describe("Array of per-question answers")
  answers: array<questionAnswerOutput>,
  @s.describe("True if the user skipped all questions")
  skippedAll: bool,
  @s.describe("True if the user cancelled (stopped the agent)")
  cancelled: bool,
}

let execute = async (
  input: input,
  ~taskId: string,
  ~toolCallId: string,
): toolResult<output> => {
  // Create a promise that blocks until the user responds via the drawer.
  // The resolveOk/resolveError callbacks are stored in pendingQuestion state
  // so the task reducer can call them when the user submits/skips/cancels.
  let result = await Promise.make((resolve, _reject) => {
    // resolveOk: receives the formatted output JSON, signals Ok
    let resolveOk = (json: JSON.t) => {
      resolve(Ok(json))
    }
    // resolveError: receives an error message, signals Error
    let resolveError = (msg: string) => {
      resolve(Error(msg))
    }

    // Dispatch to state machine — stores the pending question + resolver callbacks
    Client__State.Actions.questionReceived(
      ~taskId,
      ~questions=input.questions,
      ~toolCallId,
      ~resolveOk,
      ~resolveError,
    )
  })

  // Convert the raw result back to typed output
  switch result {
  | Ok(json) =>
    try {
      Ok(json->S.parseOrThrow(outputSchema))
    } catch {
    | _ => Error("Failed to parse question tool output")
    }
  | Error(msg) => Error(msg)
  }
}
