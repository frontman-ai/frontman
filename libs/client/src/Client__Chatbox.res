module AIElements = Bindings__AIElements
module Icons = Bindings__RadixUI__Icons
module AISDK = Bindings__AISDK__React
module TaskTabs = Client__TaskTabs

type model = {
  name: string,
  value: string,
}

// Helper component to handle fade-out animation
// When show becomes false, it fades out smoothly
// When show is false from the start (e.g., streaming started), it doesn't render at all
module ThinkingShimmer = {
  @react.component
  let make = (~show: bool, ~messageId: string) => {
  let (wasShowing, setWasShowing) = React.useState(() => show)
  let (shouldRender, setShouldRender) = React.useState(() => show)
  
  React.useEffect(() => {
    if show {
      // Start showing
      setWasShowing(_ => true)
      setShouldRender(_ => true)
      None
    } else if wasShowing {
      // Was showing, now hide - fade out then unmount
      let timer = Js.Global.setTimeout(() => {
        setShouldRender(_ => false)
      }, 300) // Match CSS transition duration
      Some(() => Js.Global.clearTimeout(timer))
    } else {
      // Never was showing (e.g., streaming started immediately) - don't render
      setShouldRender(_ => false)
      None
    }
  }, [show, wasShowing])
  
  if !shouldRender {
    React.null
  } else {
    <div 
      key={`${messageId}-thinking`}
      className={
        show 
          ? "max-w-full animate-in fade-in-0 px-4 py-3" 
          : "max-w-full animate-out fade-out-0 duration-300 px-4 py-3"
      }
    >
      <AIElements.Shimmer>
        {React.string("Thinking...")}
      </AIElements.Shimmer>
    </div>
  }
  }
}

let models = [
  {name: "GPT 4o", value: "openai/gpt-4o"},
  {name: "Deepseek R1", value: "deepseek/deepseek-r1"},
]

// Convert internal toolCallState to AI SDK state string
let toolStateToString = (state: Client__State__StateReducer.Message.toolCallState): string => {
  switch state {
  | InputStreaming => "input-streaming"
  | InputAvailable => "input-available"
  | OutputAvailable => "output-available"
  | OutputError => "output-error"
  }
}

@react.component
let make = () => {
  let (input, setInput) = React.useState(() => "")
  let (model, setModel) = React.useState(() => Array.getUnsafe(models, 0).value)

  // Get messages from our state store
  let messages = Client__State.useSelector(Client__State.Selectors.messages)
  let isStreaming = Client__State.useSelector(Client__State.Selectors.isStreaming)
  let isConnected = Client__State.useSelector(Client__State.Selectors.isConnected)
  let planEntries = Client__State.useSelector(Client__State.Selectors.currentPlanEntries)

  let handleSubmit = (message: {"text": string, "files": option<array<WebAPI.FileAPI.file>>}) => {
    let hasText = message["text"] !== ""
    let hasAttachments = message["files"]->Option.mapOr(false, files => files->Array.length > 0)

    if hasText || hasAttachments {
      let content = {
        let textPart = hasText ? [Client__State.UserContentPart.Text({text: message["text"]})] : []

        // TODO: Handle file attachments when we add support
        textPart
      }
      Client__State.Actions.addUserMessage(~content)
      setInput(_ => "")
    }
  }

  <div className="flex flex-col h-full">
    <TaskTabs />
    <AIElements.Conversation className="flex-grow overflow-hidden">
      <AIElements.ConversationContent>
        {{
          // Check if the last message in the conversation is completed (turn ended)
          // or streaming (hide shimmer immediately)
          let lastMessage = messages->Array.get(Array.length(messages) - 1)
          let isTurnEnded = switch lastMessage {
          | Some(Client__State__StateReducer.Message.Assistant(Completed(_))) => true
          | _ => false
          }
          let isLastMessageStreaming = switch lastMessage {
          | Some(Client__State__StateReducer.Message.Assistant(Streaming(_))) => true
          | Some(Client__State__StateReducer.Message.ToolCall({state: InputStreaming | InputAvailable, _})) => true
          | _ => false
          }
          
          messages
          ->Array.mapWithIndex((message, index) => {
            let messageId = Client__State__StateReducer.Selectors.getMessageId(message)
            let isLastMessage = index == Array.length(messages) - 1
            
            // Check if next message is an assistant message or tool call
            let nextMessage = Array.get(messages, index + 1)
            let hasAssistantResponse = switch nextMessage {
            | Some(Client__State__StateReducer.Message.Assistant(_)) => true
            | Some(Client__State__StateReducer.Message.ToolCall(_)) => true
            | _ => false
            }
            
            // Check if next message is a streaming assistant message (hide shimmer immediately)
            let isNextStreaming = switch nextMessage {
            | Some(Client__State__StateReducer.Message.Assistant(Streaming(_))) => true
            | _ => false
            }

            switch message {
            | Client__State__StateReducer.Message.User({content}) =>
            // Render user message
            <React.Fragment key={messageId}>
              <div className="max-w-full">
                {content
                ->Array.mapWithIndex((part, partIndex) => {
                  switch part {
                  | Text({text}) =>
                    <AIElements.Message key={`${messageId}-${partIndex->Int.toString}`} from="user">
                      <AIElements.MessageContent>
                        <AIElements.Response> {React.string(text)} </AIElements.Response>
                      </AIElements.MessageContent>
                    </AIElements.Message>
                  | _ => React.null // TODO: Handle Image and File parts
                  }
                })
                ->React.array}
              </div>
              // Show "Thinking..." shimmer only after the last message
              // Hide if turn ended or if last message is streaming
              {if isLastMessage && !hasAssistantResponse && !isNextStreaming && !isTurnEnded && !isLastMessageStreaming {
                <ThinkingShimmer show={true} messageId={messageId} />
              } else {
                React.null
              }}
            </React.Fragment>

            | Client__State__StateReducer.Message.Assistant(Streaming({textBuffer, _})) =>
            // Render streaming assistant message with visual indicator
            <React.Fragment key={messageId}>
              <div className="max-w-full">
                <React.Fragment key={`${messageId}-0`}>
                  <AIElements.Message from="assistant">
                    <AIElements.MessageContent
                      className="!bg-blue-500 transition-colors duration-500"
                    >
                      <AIElements.Response> {React.string(textBuffer)} </AIElements.Response>
                    </AIElements.MessageContent>
                  </AIElements.Message>
                </React.Fragment>
              </div>
              // Show shimmer only after the last streaming message
              // Hide if turn ended or if last message is streaming
              {if isLastMessage && !hasAssistantResponse && !isNextStreaming && !isTurnEnded && !isLastMessageStreaming {
                <ThinkingShimmer show={true} messageId={messageId} />
              } else {
                React.null
              }}
            </React.Fragment>

            | Client__State__StateReducer.Message.Assistant(Completed({content, _})) =>
            // Render completed assistant message
            <React.Fragment key={messageId}>
              <div className="max-w-full">
                {content
                ->Array.mapWithIndex((part, i) => {
                  switch part {
                  | Text({text}) =>
                    <React.Fragment key={`${messageId}-${i->Int.toString}`}>
                      <AIElements.Message from="assistant">
                        <AIElements.MessageContent variant="flat" className="bg-secondary px-4 py-3 transition-colors duration-500">
                          <AIElements.Response> {React.string(text)} </AIElements.Response>
                        </AIElements.MessageContent>
                      </AIElements.Message>
                      <AIElements.Actions className="mt-2">
                        <AIElements.Action
                          onClick={() => {
                            let _ =
                              WebAPI.Global.navigator.clipboard->WebAPI.Clipboard.writeText(text)
                          }}
                          label="Copy"
                        >
                          <Icons.CopyIcon style={{"width": "12px", "height": "12px"}} />
                        </AIElements.Action>
                      </AIElements.Actions>
                    </React.Fragment>
                  | Client__State__StateReducer.AssistantContentPart.ToolCall({toolCallId: _, toolName, input}) =>
                    <React.Fragment key={`${messageId}-tool-${i->Int.toString}`}>
                      <AIElements.Tool defaultOpen={true}>
                        <AIElements.ToolHeader
                          title={<span> {React.string(toolName)} </span>} type_="tool-call" state="output-available"
                        />
                        <AIElements.ToolContent>
                          <AIElements.ToolInput input={input} />
                          <AIElements.ToolOutput
                            output={<AIElements.Response>
                              {React.string("Tool execution completed")}
                            </AIElements.Response>}
                          />
                        </AIElements.ToolContent>
                      </AIElements.Tool>
                    </React.Fragment>
                  }
                })
                ->React.array}
              </div>
              // Show shimmer only after the last completed message
              // Hide if turn ended or if last message is streaming
              {if isLastMessage && !hasAssistantResponse && !isNextStreaming && !isTurnEnded && !isLastMessageStreaming {
                <ThinkingShimmer show={true} messageId={messageId} />
              } else {
                React.null
              }}
            </React.Fragment>

            | ToolCall({toolName, state, input, inputBuffer, result, errorText, _}) =>
            // Hide todo tool calls from UI
            let isTodoTool = String.includes(toolName, "todo_list") ||
                             String.includes(toolName, "todo_add") ||
                             String.includes(toolName, "todo_update") ||
                             String.includes(toolName, "todo_remove")
            if isTodoTool {
              React.null
            } else {
              <React.Fragment key={messageId}>
              <div className="max-w-full">
                <AIElements.Tool
                  defaultOpen={switch state {
                  | OutputAvailable | OutputError => true
                  | _ => false
                  }}
                >
                  <AIElements.ToolHeader
                    title={
                      switch state {
                      | InputStreaming | InputAvailable =>
                        // Show shimmer on tool title when streaming
                        <AIElements.Shimmer>
                          {React.string(toolName)}
                        </AIElements.Shimmer>
                      | _ =>
                        <span> {React.string(toolName)} </span>
                      }
                    } type_="tool-call" state={toolStateToString(state)}
                  />
                  <AIElements.ToolContent>
                    {switch (state, input, inputBuffer) {
                    // InputStreaming: show the streaming buffer as raw text
                    | (InputStreaming, None, buffer) if String.length(buffer) > 0 =>
                      <div className="font-mono text-sm opacity-70 whitespace-pre-wrap">
                        {React.string(buffer)}
                      </div>
                    // InputAvailable or completed states: show parsed input
                    | (_, Some(input), _) => <AIElements.ToolInput input={input} />
                    | _ => React.null
                    }}
                    {switch (state, result, errorText) {
                    // Show result when available
                    | (_, Some(result), _) =>
                      <AIElements.ToolOutput
                        output={<AIElements.Response>
                          {React.string(JSON.stringifyAny(result)->Option.getOr("{}"))}
                        </AIElements.Response>}
                      />
                    // Show error when present
                    | (_, None, Some(error)) => <AIElements.ToolOutput errorText={error} />
                    // InputAvailable: show executing indicator
                    | (InputAvailable, None, None) =>
                      <div className="text-sm text-muted-foreground italic py-2">
                        {React.string("Executing...")}
                      </div>
                    // Otherwise show nothing
                    | _ => React.null
                    }}
                  </AIElements.ToolContent>
                </AIElements.Tool>
              </div>
              // Show shimmer only after the last tool call
              // Hide if turn ended, if last message is streaming, or if tool call has error (agent will respond)
              {if isLastMessage && !hasAssistantResponse && !isNextStreaming && !isTurnEnded && !isLastMessageStreaming && state != OutputError {
                <ThinkingShimmer show={true} messageId={messageId} />
              } else {
                React.null
              }}
              </React.Fragment>
            }
            }
          })
          ->React.array
        }
        }
      </AIElements.ConversationContent>
      <AIElements.ConversationScrollButton />
    </AIElements.Conversation>
    <Client__PlanDisplay entries=planEntries />
    <Client__SelectedElementDisplay />
    <Client__FigmaNodeDisplay />
    <AIElements.PromptInput
      onSubmit={() => handleSubmit({"text": input, "files": None})}
      className=""
      globalDrop={true}
      multiple={true}
    >
      <AIElements.PromptInputHeader>
        <AIElements.PromptInputAttachments>
          {attachment => <AIElements.PromptInputAttachment data={attachment} />}
        </AIElements.PromptInputAttachments>
      </AIElements.PromptInputHeader>
      <AIElements.PromptInputBody>
        <AIElements.PromptInputTextarea
          onChange={e => {
            let target = ReactEvent.Form.target(e)
            setInput(_ => target["value"])
          }}
          value={input}
        />
      </AIElements.PromptInputBody>
      <AIElements.PromptInputFooter>
        <AIElements.PromptInputTools>
          <AIElements.PromptInputActionMenu>
            <AIElements.PromptInputActionMenuTrigger />
            <AIElements.PromptInputActionMenuContent>
              <AIElements.PromptInputActionAddAttachments />
            </AIElements.PromptInputActionMenuContent>
          </AIElements.PromptInputActionMenu>
          <AIElements.PromptInputModelSelect
            onValueChange={value => setModel(_ => value)} value={model}
          >
            <AIElements.PromptInputModelSelectTrigger>
              <AIElements.PromptInputModelSelectValue />
            </AIElements.PromptInputModelSelectTrigger>
            <AIElements.PromptInputModelSelectContent>
              {models
              ->Array.map(model => {
                <AIElements.PromptInputModelSelectItem key={model.value} value={model.value}>
                  {React.string(model.name)}
                </AIElements.PromptInputModelSelectItem>
              })
              ->React.array}
            </AIElements.PromptInputModelSelectContent>
          </AIElements.PromptInputModelSelect>
        </AIElements.PromptInputTools>
        <AIElements.PromptInputSubmit
          disabled={!isConnected || (input === "" && !isStreaming)}
          status={isStreaming ? "streaming" : "idle"}
        />
      </AIElements.PromptInputFooter>
    </AIElements.PromptInput>
  </div>
}
