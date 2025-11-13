module AgentTypes = AskTheLlmAgent.Agent__Task__Message__Part
module ToolResultPart = AgentTypes.ToolResultPart

let submitResult = async (
  ~toolCallId: string,
  ~toolName: string,
  ~output: ToolResultPart.Output.t,
): unit => {
  let headers = WebAPI.Headers.make()
  headers->WebAPI.Headers.set(~name="Content-Type", ~value="application/json")

  let result: ToolResultPart.t = {
    toolCallId,
    toolName,
    output,
    providerOptions: None,
  }

  let body =
    result
    ->S.reverseConvertToJsonOrThrow(ToolResultPart.schema)
    ->JSON.stringify

  try {
    let response = await WebAPI.Global.fetch(
      "/ask-the-llm/tool-results",
      ~init={
        method: "POST",
        headers: WebAPI.HeadersInit.fromHeaders(headers),
        body: WebAPI.BodyInit.fromString(body),
      },
    )

    if response.ok {
      Console.log2("[ToolExecutor] Result submitted successfully:", toolCallId)
    } else {
      // Note: response doesn't have text method in our WebAPI bindings, so just log status
      Console.error2("[ToolExecutor] Server error:", response.status)
    }
  } catch {
  | exn => {
      let msg =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Console.error2("[ToolExecutor] Failed to submit result:", msg)
    }
  }
}

// Execute client tool and submit result
let handleToolCall = async (
  ~toolCallId: string,
  ~toolName: string,
  ~args: option<JSON.t>,
): unit => {
  Console.log2("[ToolExecutor] Executing client tool:", toolName)

  // Execute via registry
  let output = switch args {
  | None => ToolResultPart.Output.ErrorText("No arguments provided for client tool")
  | Some(args) =>
    switch await Client__ToolRegistry.execute(~toolName, ~args) {
    | Ok(resultJson) => {
        Console.log2("[ToolExecutor] Tool execution successful:", toolName)
        ToolResultPart.Output.JSON(resultJson)
      }
    | Error(msg) => {
        Console.error2("[ToolExecutor] Tool execution failed:", msg)
        ToolResultPart.Output.ErrorText(msg)
      }
    }
  }

  // Submit result
  await submitResult(~toolCallId, ~toolName, ~output)
}
