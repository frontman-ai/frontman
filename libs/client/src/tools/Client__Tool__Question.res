module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool

let name = Tool.ToolNames.question
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Write
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Interactive

let description = `Ask the user one or more questions with predefined options. Use this tool when:
- Offering a choice between multiple options or approaches (fix approaches, design alternatives, etc.)
- Needing clarification on ambiguous requests
- Asking for approval on destructive or irreversible actions
- Requesting values that cannot be inferred from context

The user selects options or types a custom answer via an interactive drawer. Never present choices in a text response — always structure them through this tool.

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

@schema
type questionAnswerOutput = {
  @live
  question: string,
  @live
  answer: option<array<string>>,
}

@schema
type output = {
  @s.describe("Array of per-question answers") @live
  answers: array<questionAnswerOutput>,
  @s.describe("True if the user skipped all questions") @live
  skippedAll: bool,
  @s.describe("True if the user cancelled (stopped the agent)") @live
  cancelled: bool,
}

let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

let execute = async (
  input: input,
  ~taskId: string,
  ~toolCallId: string,
  ~signal=?,
): Tool.MCP.CallToolResult.t => {
  let result = await Promise.make((resolve, _reject) => {
    let settled = ref(false)
    let cleanup = ref(() => ())
    let detach = ref(() => ())
    let settle = result =>
      switch settled.contents {
      | true => ()
      | false =>
        settled := true
        cleanup.contents()
        resolve(result)
      }
    let resolveOk = (json: JSON.t) => {
      settle(Ok(json))
    }
    let resolveError = (msg: string) => {
      settle(Error(msg))
    }

    let onAbort = () => {
      detach.contents()
      resolveError("Question request aborted")
    }
    switch signal {
    | Some(signal) =>
      FrontmanAiFrontmanClient.FrontmanClient__ACP.onAbort(signal, onAbort)
      cleanup := (() => FrontmanAiFrontmanClient.FrontmanClient__ACP.offAbort(signal, onAbort))
      switch signal.aborted {
      | true => onAbort()
      | false => ()
      }
    | None => ()
    }
    switch settled.contents {
    | true => ()
    | false =>
      detach :=
        Client__State.Actions.questionReceived(
          ~taskId,
          ~questions=input.questions,
          ~toolCallId,
          ~resolveOk,
          ~resolveError,
        )
      switch settled.contents {
      | true => detach.contents()
      | false => ()
      }
    }
  })

  switch result {
  | Ok(json) =>
    try {
      Tool.structuredResult(json->S.parseOrThrow(~to=outputSchema), outputSchema)
    } catch {
    | _ => Tool.MCP.CallToolResult.makeError("Failed to parse question tool output")
    }
  | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
  }
}
