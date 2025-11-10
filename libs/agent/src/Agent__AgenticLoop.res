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
  let id = WebAPI.Global.crypto->WebAPI.Crypto.randomUUID
  let result = await Adapter.streamText(llm, history)
  let stream = result->Adapter.getFullStream

  await Adapter.processAsyncIterable(stream, async event => {
    let event = switch event {
    | TextDelta(props) => Agent__Bindings__Vercel.TextDelta({...props, id})
    | Start(_) as evt => evt
    | StartStep(_) as evt => evt
    | TextStart(_) => TextStart({id: id})
    | TextEnd(_) => TextEnd({id: id})
    | ReasoningStart(_) => ReasoningStart({id: id})
    | ReasoningDelta(props) => ReasoningDelta({...props, id})
    | ReasoningEnd(_) => ReasoningEnd({id: id})
    | Source(props) => Source({...props, id})
    | File(_) as evt => evt
    | ToolCall(_) as evt => evt
    | FinishStep(_) as evt => evt
    | Finish(_) as evt => evt
    | Abort(_) as evt => evt
    | Error(_) as evt => evt
    | Raw(_) as evt => evt
    | ToolInputStart(props) => Agent__Bindings__Vercel.ToolInputStart(props)
    | ToolInputDelta(props) => Agent__Bindings__Vercel.ToolInputDelta(props)
    | ToolInputEnd(props) => Agent__Bindings__Vercel.ToolInputEnd(props)
    | ToolResult(props) => Agent__Bindings__Vercel.ToolResult(props)
    | ToolError(props) => Agent__Bindings__Vercel.ToolError(props)
    | ToolOutputDenied(props) => Agent__Bindings__Vercel.ToolOutputDenied(props)
    | ToolApprovalRequest(props) => Agent__Bindings__Vercel.ToolApprovalRequest(props)
    }
    Js.Console.error(event)
    emitEvent(StreamEvent(task.id, event))
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
