// Agentic loop - handles a single LLM iteration
// Follows the AI SDK manual agent loop pattern:
// https://ai-sdk.dev/cookbook/node/manual-agent-loop

module Adapter = Agent__Adapters__Vercel

// Run a single iteration: call LLM with current history and return commands
let runIteration = async (llm: Adapter.t, task: Agent__Task.t): array<Agent__Task.cmd> => {
  Console.log("=== Running single LLM iteration")

  let history = task->Agent__Task.getHistory
  Console.log(`=== Calling LLM with ${history->Array.length->Int.toString} messages`)

  let result = await Adapter.streamText(llm, history)
  let stream = result->Adapter.getFullStream

  await Adapter.processAsyncIterable(stream, async event => {
    switch event {
    | Text({text}) => Console.log(text)
    | ToolCall({toolName, _}) => Console.log(`\nCalling tool: ${toolName}`)
    | _ => ()
    }
  })

  // Get LLM generated messages
  let response = await result->Adapter.getResponse
  Console.log2("Response messages count:", response.messages->Array.length)
  Console.log2("Response messages:", response.messages)

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
