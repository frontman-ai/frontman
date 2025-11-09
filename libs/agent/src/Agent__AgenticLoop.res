// Agentic loop - handles a single LLM iteration
// Follows the AI SDK manual agent loop pattern:
// https://ai-sdk.dev/cookbook/node/manual-agent-loop

module Adapter = Agent__Adapters__Vercel

let runIteration = async (
  llm: Adapter.t,
  task: Agent__Task.t,
  ~emitEvent: Agent__EventBus.events => unit,
): array<Agent__Task.cmd> => {
  let history = task->Agent__Task.getHistory

  let result = await Adapter.streamText(llm, history)
  let stream = result->Adapter.getFullStream

  await Adapter.processAsyncIterable(stream, async event => {
    emitEvent(StreamEvent(task, event))
  })

  let response = await result->Adapter.getResponse

  let commands =
    response.messages
    ->Array.filterMap(vercelMsg => Adapter.messageFromVercel(vercelMsg, task.id))
    ->Array.map(domainMessage => {
      Agent__Task.AddMessage({task, message: domainMessage})
    })

  Agent__Logger.Log.debug("Iteration complete")
  commands
}
