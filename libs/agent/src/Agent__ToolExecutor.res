// Tool execution logic
// Handles extraction, lookup, decoding, execution, and result formatting

module Part = Agent__Task__Message__Part
module ToolCallPart = Part.ToolCallPart
module ToolResultPart = Part.ToolResultPart

// Extract tool calls from an assistant message
let extractToolCalls = (message: Agent__Task__Message.t): array<ToolCallPart.t> => {
  switch message {
  | Assistant({content: List(parts), _}) =>
    parts->Array.filterMap(part =>
      switch part {
      | ToolCall(toolCall) => Some(toolCall)
      | _ => None
      }
    )
  | _ => []
  }
}

// Execute a single tool call
let executeSingleTool = async (
  config: Agent__Config.t,
  toolRegistry: Agent__ToolsRegistry.t,
  toolCall: ToolCallPart.t,
): ToolResultPart.t => {
  // Helper to create result parts
  let makeResult = (output: ToolResultPart.Output.t): ToolResultPart.t => {
    toolCallId: toolCall.toolCallId,
    toolName: toolCall.toolName,
    output,
    providerOptions: None,
  }

  // Find tool in registry
  let toolOption = toolRegistry->Array.find(tool => {
    module Tool = unpack(tool: Agent__Tool.T)
    Tool.name == toolCall.toolName
  })

  switch toolOption {
  | None => makeResult(ErrorText(`Tool '${toolCall.toolName}' not found in registry`))
  | Some(tool) => {
      module Tool = unpack(tool: Agent__Tool.T)

      switch Tool.decodeInput(toolCall.args) {
      | Error(error) =>
        // Convert S.error to string using Sury's formatting
        makeResult(ErrorText(`Invalid arguments for tool '${toolCall.toolName}': ${error.message}`))
      | Ok(input) =>
        try {
          switch await Tool.execute(config, input) {
          | Error(msg) => makeResult(ErrorText(msg))
          | Ok(output) => makeResult(JSON(Tool.encodeOutput(output)))
          }
        } catch {
        | exn => {
            let msg =
              exn
              ->JsExn.fromException
              ->Option.flatMap(JsExn.message)
              ->Option.getOr("Unknown exception")
            makeResult(ErrorText(`Unexpected error executing tool '${toolCall.toolName}': ${msg}`))
          }
        }
      }
    }
  }
}

// Execute all tool calls from a message
let executeToolCalls = async (
  config: Agent__Config.t,
  toolRegistry: Agent__ToolsRegistry.t,
  taskId: Agent__Task__Id.t,
  toolCalls: array<ToolCallPart.t>,
): Agent__Task__Message.t => {
  // Execute all tools sequentially
  let results = await toolCalls
  ->Array.map(async toolCall => await executeSingleTool(config, toolRegistry, toolCall))
  ->Promise.all

  // Create Tool message with results
  Agent__Task__Message.Tool({
    taskId: Some(taskId),
    content: results,
  })
}
