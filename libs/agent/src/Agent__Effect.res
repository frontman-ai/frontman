// Effect system for pure side-effect handling
//
// Effects are pure descriptions of side effects. Event handlers emit effects,
// and Agent.run() executes them at the system edge, returning commands to continue flow.

// ============================================================================
// Effect Types
// ============================================================================

module ExecuteToolEffect = {
  type t = {
    taskId: Agent__Task__Id.t,
    toolCalls: array<Agent__Task__Message__Part.ToolCallPart.t>,
    toolRegistry: Agent__ToolsRegistry.t,
  }
}

module RunIterationEffect = {
  type t = {task: Agent__Task.t, llm: Agent__Adapters__Vercel.t}
}

type t =
  | ExecuteToolsCalls(ExecuteToolEffect.t)
  | RunIteration(RunIterationEffect.t)

// ============================================================================
// Tool Execution Helpers (Private)
// ============================================================================

module ToolCallPart = Agent__Task__Message__Part.ToolCallPart
module ToolResultPart = Agent__Task__Message__Part.ToolResultPart

let executeSingleTool = async (
  config: Agent__Config.t,
  toolRegistry: Agent__ToolsRegistry.t,
  toolCall: ToolCallPart.t,
): ToolResultPart.t => {
  Console.log2("=== Executing tool:", toolCall.toolName)
  Console.log2("=== Tool args:", toolCall.args)

  // Create context for tool execution
  let ctx: Agent__ToolExecutionContext.t = {projectRoot: config.projectRoot}

  let makeResult = (output: ToolResultPart.Output.t): ToolResultPart.t => {
    toolCallId: toolCall.toolCallId,
    toolName: toolCall.toolName,
    output,
    providerOptions: None,
  }

  let toolOption = toolRegistry->Array.find(tool => {
    module Tool = unpack(tool: Agent__Tool.T)
    Tool.name == toolCall.toolName
  })

  switch toolOption {
  | None => makeResult(ErrorText(`Tool '${toolCall.toolName}' not found in registry`))
  | Some(tool) => {
      module Tool = unpack(tool: Agent__Tool.T)

      switch Tool.decodeInput(toolCall.args) {
      | Error(error) => {
          Console.log2("=== Tool execution failed (decode error):", error.message)
          makeResult(ErrorText(`Invalid arguments for tool '${toolCall.toolName}': ${error.message}`))
        }
      | Ok(input) =>
        try {
          switch await Tool.execute(ctx, input) {
          | Error(msg) => {
              Console.log2("=== Tool execution failed:", msg)
              makeResult(ErrorText(msg))
            }
          | Ok(output) => {
              Console.log2("=== Tool execution succeeded:", toolCall.toolName)
              makeResult(JSON(Tool.encodeOutput(output)))
            }
          }
        } catch {
        | exn => {
            let msg =
              exn
              ->JsExn.fromException
              ->Option.flatMap(JsExn.message)
              ->Option.getOr("Unknown exception")
            Console.log2("=== Tool execution exception:", msg)
            makeResult(ErrorText(`Unexpected error executing tool '${toolCall.toolName}': ${msg}`))
          }
        }
      }
    }
  }
}

let executeToolCalls = async (
  task: Agent__Task.t,
  toolCalls: array<ToolCallPart.t>,
  ~config: Agent__Config.t,
  ~toolRegistry: Agent__ToolsRegistry.t,
): Agent__Task__Message.t => {
  let results = await toolCalls
  ->Array.map(async toolCall => await executeSingleTool(config, toolRegistry, toolCall))
  ->Promise.all

  Agent__Task__Message.Tool({
    taskId: Some(task.id),
    content: results,
  })
}

// ============================================================================
// Public API
// ============================================================================

let execute = async (
  config: Agent__Config.t,
  effect: Agent__Command.Effect.t,
  ~toolRegistry: Agent__ToolsRegistry.t,
  ~llm: Agent__Adapters__Vercel.t,
): result<array<Agent__Task.cmd>, string> => {
  switch effect {
  | ExecuteTools({task, toolCalls}) =>
    try {
      let message = await executeToolCalls(task, toolCalls, ~config, ~toolRegistry)
      Ok([Agent__Task.AddMessage({task, message})])
    } catch {
    | exn => {
        let msg =
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Unknown exception during effect execution")
        Error(`Effect execution failed: ${msg}`)
      }
    }

  | RunLLMIteration({task}) =>
    try {
      let commands = await Agent__AgenticLoop.runIteration(llm, task)
      Ok(commands)
    } catch {
    | exn => {
        let msg =
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Unknown exception during iteration execution")
        Error(`Iteration execution failed: ${msg}`)
      }
    }
  }
}
