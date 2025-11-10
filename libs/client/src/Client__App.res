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
    | StreamEvent(taskId, TextStart({id})) => Client__State.Actions.streamingStarted(~taskId, ~id)
    | StreamEvent(taskId, TextDelta({id, text})) =>
      Client__State.Actions.textDeltaReceived(~taskId, ~id, ~text)
    | StreamEvent(taskId, TextEnd({id})) => Client__State.Actions.messageCompleted(~taskId, ~id)

    | StreamEvent(taskId, ToolCall({toolCallId, toolName, input})) =>
      Client__State.Actions.toolCallReceived(
        ~taskId,
        ~toolCall={
          id: toolCallId,
          toolName,
          inputBuffer: "",
          input: Some(input),
          result: None,
          errorText: None,
          state: InputAvailable,
          createdAt: Date.now(),
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
    | StreamEvent(taskId, ToolInputStart(toolInputStart)) =>
      Client__State.Actions.toolInputStartReceived(
        ~taskId,
        ~id=toolInputStart.id,
        ~toolName=toolInputStart.toolName,
      )
    | StreamEvent(taskId, ToolInputDelta(delta)) =>
      Client__State.Actions.toolInputDeltaReceived(~taskId, ~id=delta.id, ~delta=delta.delta)
    | StreamEvent(taskId, ToolInputEnd(end)) =>
      Client__State.Actions.toolInputEndReceived(~taskId, ~id=end.id)
    | StreamEvent(
        _,
        ToolResult(_)
        | ToolError(_)
        | ToolOutputDenied(_)
        | ToolApprovalRequest(_),
      ) =>
      failwith("TODO")
    | TaskEvent(taskId, MessageAdded({message: Tool(toolMessage)})) =>
      toolMessage.content->Array.forEach(toolResult => {
        let id = toolResult.toolCallId
        switch toolResult.output {
        | Text(text) => {
            let result = text->JSON.stringifyAny->Option.getOr("null")->JSON.parseOrThrow
            Client__State.Actions.toolResultReceived(~taskId, ~id, ~result)
          }

        | JSON(json) => Client__State.Actions.toolResultReceived(~taskId, ~id, ~result=json)

        | ErrorText(error) => Client__State.Actions.toolErrorReceived(~taskId, ~id, ~error)

        | ErrorJSON(errorJson) => {
            let error = errorJson->JSON.stringifyAny->Option.getOr("Unknown error")
            Client__State.Actions.toolErrorReceived(~taskId, ~id, ~error)
          }

        | Content(_contentParts) => {
            let result =
              JSON.stringifyAny("[Content with media - display not implemented]")
              ->Option.getOr("null")
              ->JSON.parseOrThrow
            Client__State.Actions.toolResultReceived(~taskId, ~id, ~result)
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

  let entrypointUrl =
    WebAPI.Global.document
    ->WebAPI.Document.querySelector("#ask-the-llm-entrypoint-url")
    ->Null.toOption
    ->Option.map(element => {
      element->WebAPI.Element.asNode->WebAPI.Node.textContent->Null.toOption->Option.getOr("")
    })
  let currentUrl =
    WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)

  let originUrl = switch entrypointUrl {
  | Some(entrypointUrl) => entrypointUrl
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
