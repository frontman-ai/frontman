// Agentic loop - handles a single LLM iteration
// Follows the AI SDK manual agent loop pattern:
// https://ai-sdk.dev/cookbook/node/manual-agent-loop

module Adapter = Agent__Adapters__Vercel

// Run a single iteration: call LLM with current history and return commands
let runIteration = async (
  llm: Adapter.t,
  task: Agent__Task.t,
  ~emitEvent: Agent__EventBus.events => unit,
): array<Agent__Task.cmd> => {
  let history = task->Agent__Task.getHistory
  Console.log(`=== Calling LLM with ${history->Array.length->Int.toString} messages`)

  let result = await Adapter.streamText(llm, history)
  let stream = result->Adapter.getFullStream

  // Process stream and emit ALL events to EventBus
  await Adapter.processAsyncIterable(stream, async event => {
    // Emit to EventBus FIRST
    emitEvent(StreamEvent(task, event))

    // Then log for debugging (keep existing console logs)
    switch event {
    | TextDelta({delta, _}) => Console.log(delta)
    | ToolCall({toolName, _}) => Console.log(`\nCalling tool: ${toolName}`)
    | Start(_)
    | StartStep(_)
    | TextStart(_)
    | TextEnd(_)
    | ReasoningStart(_)
    | ReasoningDelta(_)
    | ReasoningEnd(_)
    | Source(_)
    | File(_)
    | ToolInputStart(_)
    | ToolInputDelta(_)
    | ToolInputEnd(_)
    | ToolResult(_)
    | ToolError(_)
    | FinishStep(_)
    | Finish(_)
    | Error(_)
    | Raw(_) => ()
    }
  })

  // Get LLM generated messages
  let response = await result->Adapter.getResponse

  // Convert messages to domain commands, filtering out None (tool results we don't want)
  let commands =
    response.messages
    ->Array.filterMap(vercelMsg => Adapter.messageFromVercel(vercelMsg))
    ->Array.map(domainMessage => {
      Agent__Task.AddMessage({task, message: domainMessage})
    })

  Console.log("=== Iteration complete")
  commands
}
