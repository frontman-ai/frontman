module Types = Client__Types
module AgentTaskMessage = AskTheLlmAgent.Agent__Task__Message

let useSSE = (newEventCallback: AgentTaskMessage.t => unit) => {
  React.useEffect(() => {
    let eventSource = WebAPI.EventSource.make(~url="/api/ask-the-llm/chat-sse")
    let onOpen = _ => {
      Console.log("[SSE] Connection opened")
    }
    let onMessage = event => {
      Console.log2("[SSE] Message received:", event->WebAPI.MessageEvent.data)
      let msg = event->WebAPI.MessageEvent.data->S.parseOrThrow(AgentTaskMessage.schema)
      Console.log2("[SSE] Parsed message:", msg)
      newEventCallback(msg)
    }
    let onError = error => {
      Console.log2("[SSE] Error occurred:", error)
      eventSource->WebAPI.EventSource.close
    }
    eventSource->WebAPI.EventSource.addEventListener(Custom("open"), onOpen)
    eventSource->WebAPI.EventSource.addEventListener(Custom("message"), onMessage)
    eventSource->WebAPI.EventSource.addEventListener(Custom("error"), onError)

    Some(
      () => {
        eventSource->WebAPI.EventSource.removeEventListener(Custom("open"), onOpen)
        eventSource->WebAPI.EventSource.removeEventListener(Custom("message"), onMessage)
        eventSource->WebAPI.EventSource.removeEventListener(Custom("error"), onError)
        eventSource->WebAPI.EventSource.close
      },
    )
  }, newEventCallback)
}
