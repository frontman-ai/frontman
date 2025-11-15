// // Server tool with type-erased executor
// // Stores metadata module and an execution function that works with JSON
// type serverToolWithExecutor = {
//   metadata: module(Agent__Tool.Metadata),
//   execute: (Agent__ToolExecutionContext.t, JSON.t) => promise<result<JSON.t, string>>,
// }

type tool =
  | ServerTool(module(Agent__Tool.ServerTool))
  | ClientTool(module(Agent__Tool.Metadata))

type pendingExecution = {
  toolCallId: string,
  toolName: string,
  resolve: Agent__Task__Message__Part.ToolResultPart.t => unit,
  timeoutId: Js.Global.timeoutId,
}

type t = {
  tools: array<tool>,
  pendingClientExecutions: ref<Map.t<string, pendingExecution>>,
}

let make = (): t => {
  tools: [
    ServerTool(module(Agent__Tool__ListFiles)),
    ServerTool(module(Agent__Tool__ReadFile)),
    ServerTool(module(Agent__Tool__WriteFile)),
    ClientTool(module(Agent__Tool__Metadata__GetErrors)),
  ],
  pendingClientExecutions: ref(Map.make()),
}

// Get tool name from any tool
let getToolName = (tool: tool): string => {
  switch tool {
  | ServerTool(tool) => {
      module Tool = unpack(tool)
      Tool.name
    }

  | ClientTool(tool) => {
      module Tool = unpack(tool)
      Tool.name
    }
  }
}

let getTools = (registry: t): array<tool> => registry.tools

let getByName = (registry: t, name: string): option<tool> =>
  registry.tools->Array.find(tool => getToolName(tool) == name)

let registerClientExecution = (
  registry: t,
  ~toolCallId: string,
  ~toolName: string,
  ~timeoutMs: int,
  ~onTimeout: unit => Agent__Task__Message__Part.ToolResultPart.t,
): promise<Agent__Task__Message__Part.ToolResultPart.t> => {
  Promise.make((resolve, _reject) => {
    let timeoutId = Js.Global.setTimeout(() => {
      registry.pendingClientExecutions.contents->Map.delete(toolCallId)->ignore
      let timeoutResult = onTimeout()
      resolve(timeoutResult)
    }, timeoutMs)

    Agent__Logger.Log.info(`registering a clientside ToolExecution ${toolCallId}`)
    registry.pendingClientExecutions.contents->Map.set(
      toolCallId,
      {
        toolCallId,
        toolName,
        resolve,
        timeoutId,
      },
    )
  })
}

let resolveClientExecution = (
  registry: t,
  result: Agent__Task__Message__Part.ToolResultPart.t,
): bool => {
  switch registry.pendingClientExecutions.contents->Map.get(result.toolCallId) {
  | None => {
      Agent__Logger.Log.warn(
        `[Registry] No pending execution found for toolCallId: ${result.toolCallId}`,
      )
      false
    }
  | Some(pending) => {
      Js.Global.clearTimeout(pending.timeoutId)
      registry.pendingClientExecutions.contents->Map.delete(result.toolCallId)->ignore
      pending.resolve(result)
      Agent__Logger.Log.info(`[Registry] Resolved client tool execution: ${pending.toolName}`)
      true
    }
  }
}

// Get count of pending executions (useful for debugging/testing)
let getPendingCount = (registry: t): int => {
  registry.pendingClientExecutions.contents->Map.size
}
