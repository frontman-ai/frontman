// Agentic loop - handles a single LLM iteration
// Follows the AI SDK manual agent loop pattern:
// https://ai-sdk.dev/cookbook/node/manual-agent-loop

module Adapter = Agent__Adapters__Vercel

// Run a single iteration: call LLM with current history and return commands
let runIteration = async (llm: Adapter.t, task: Agent__Task.t): array<Agent__Task.cmd> => {
  let history = task->Agent__Task.getHistory
  Console.log(`=== Calling LLM with ${history->Array.length->Int.toString} messages`)

  let result = await Adapter.streamText(llm, history)
  let stream = result->Adapter.getFullStream

  await Adapter.processAsyncIterable(stream, async event => {
    switch event {
    | TextStart => ()
    | TextDelta({textDelta}) => Console.log(textDelta)
    | TextEnd => ()
    | ToolCall({toolName, _}) => Console.log(`\nCalling tool: ${toolName}`)
    | Start
    | StartStep(_)
    | ReasoningStart
    | ReasoningDelta(_)
    | ReasoningEnd
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
