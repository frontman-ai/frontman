module AIElements = Bindings__AIElements
module RadixUI__Icons = Bindings__RadixUI__Icons

// Import required types
module AgentEventBus = AskTheLlmAgent.Agent__EventBus
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel
module Agent = AskTheLlmAgent.Agent

@react.component
let make = () => {
  // Handle SSE events and dispatch to state
  let handleSSEEvent = React.useCallback((event: AgentEventBus.events) => {
    switch event {
    | StreamEvent(_task, TextStart({id})) => Client__State.Actions.streamingStarted(~id)

    | StreamEvent(_task, TextDelta({id, text})) =>
      Client__State.Actions.textDeltaReceived(~id, ~text)

    | StreamEvent(_task, TextEnd({id})) => Client__State.Actions.messageCompleted(~id)

    | StreamEvent(_task, ToolCall({toolCallId, toolName, input})) =>
      Client__State.Actions.toolCallReceived(
        ~toolCall={
          toolCallId,
          toolName,
          inputBuffer: "",
          input: Some(input),
          result: None,
          errorText: None,
          state: InputAvailable,
        },
      )

    | StreamEvent(_, Start(_))
    | StreamEvent(_, FinishStep(_))
    | StreamEvent(_, StartStep(_))
    | StreamEvent(_, Finish(_))
    | StreamEvent(_, ReasoningStart(_))
    | StreamEvent(_, ReasoningDelta(_))
    | StreamEvent(_, ReasoningEnd(_))
    | StreamEvent(_, Source(_))
    | StreamEvent(_, File(_))
    | StreamEvent(_, Abort(_))
    | StreamEvent(_, Error(_))
    | StreamEvent(_, Raw(_)) => ()

    | TaskEvent(_, MessageAdded({message: Tool(toolMessage)})) =>
      toolMessage.content->Array.forEach(toolResult => {
        let toolCallId = toolResult.toolCallId
        switch toolResult.output {
        | Text(text) => {
            let result = text->JSON.stringifyAny->Option.getOr("null")->JSON.parseOrThrow
            Client__State.Actions.toolResultReceived(~toolCallId, ~result)
          }

        | JSON(json) => Client__State.Actions.toolResultReceived(~toolCallId, ~result=json)

        | ErrorText(error) => Client__State.Actions.toolErrorReceived(~toolCallId, ~error)

        | ErrorJSON(errorJson) => {
            let error = errorJson->JSON.stringifyAny->Option.getOr("Unknown error")
            Client__State.Actions.toolErrorReceived(~toolCallId, ~error)
          }

        | Content(_contentParts) => {
            let result =
              JSON.stringifyAny("[Content with media - display not implemented]")
              ->Option.getOr("null")
              ->JSON.parseOrThrow
            Client__State.Actions.toolResultReceived(~toolCallId, ~result)
          }
        }
      })

    // Ignore other TaskEvent variants
    | TaskEvent(_, Created(_))
    | TaskEvent(_, ProcessingStarted(_))
    | TaskEvent(_, Completed(_))
    | TaskEvent(_, MessageAdded(_)) => ()
    }
  }, [])

  // Connect SSE
  Client__Hooks.useSSE(handleSSEEvent)

  let entrypointUrl = WebAPI.Global.document->WebAPI.Document.querySelector("#ask-the-llm-entrypoint-url")->Null.toOption->Option.map(element => {
    element->WebAPI.Element.asNode->WebAPI.Node.textContent->Null.toOption->Option.getOr("")
  })
  let currentUrl =
    WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)

  let originUrl = switch entrypointUrl {
  | Some(entrypointUrl) =>
    entrypointUrl
  | None => `${currentUrl.protocol}//${currentUrl.host}`
  }

  <div className="flex h-screen w-screen bg-background text-foreground">
    <div className="h-full w-96 border-r flex flex-col p-2 overflow-hidden">
      <Client__Chatbox />
    </div>
    <div className="grow h-full p-1">
      <Client__WebPreview url={originUrl} />
    </div>
  </div>
}
