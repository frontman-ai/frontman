module AIElements = Bindings__AIElements
module Icons = Bindings__RadixUI__Icons
module AISDK = Bindings__AISDK__React
module TaskTabs = Client__TaskTabs

type model = {
  name: string,
  value: string,
}

let models = [
  {name: "GPT 4o", value: "openai/gpt-4o"},
  {name: "Deepseek R1", value: "deepseek/deepseek-r1"},
]

// Convert internal toolCallState to AI SDK state string
let toolStateToString = (state: Client__State__StateReducer.toolCallState): string => {
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
  let (webSearch, setWebSearch) = React.useState(() => false)

  // Get messages from our state store
  let messages = Client__State.useSelector(Client__State.Selectors.messages)
  let isStreaming = Client__State.useSelector(Client__State.Selectors.isStreaming)

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
        {messages
        ->Array.map(message => {
          let messageId = Client__State__StateReducer.Selectors.getMessageId(message)

          switch message {
          | Client__State__StateReducer.Message.User({content}) =>
            // Render user message
            <div key={messageId} className="max-w-full">
              {content
              ->Array.mapWithIndex((part, index) => {
                switch part {
                | Text({text}) =>
                  <AIElements.Message key={`${messageId}-${index->Int.toString}`} from="user">
                    <AIElements.MessageContent>
                      <AIElements.Response> {React.string(text)} </AIElements.Response>
                    </AIElements.MessageContent>
                  </AIElements.Message>
                | _ => React.null // TODO: Handle Image and File parts
                }
              })
              ->React.array}
            </div>

          | Client__State__StateReducer.Message.Assistant(Streaming({textBuffer, _})) =>
            // Render streaming assistant message with visual indicator
            <div key={messageId} className="max-w-full">
              <React.Fragment key={`${messageId}-0`}>
                <AIElements.Message from="assistant">
                  <AIElements.MessageContent variant="flat" className="!bg-blue-500 px-4 py-3 transition-colors duration-500">
                    <AIElements.Response> {React.string(textBuffer)} </AIElements.Response>
                  </AIElements.MessageContent>
                </AIElements.Message>
              </React.Fragment>
            </div>

          | Client__State__StateReducer.Message.Assistant(Completed({content, _})) =>
            // Render completed assistant message
            <div key={messageId} className="max-w-full">
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
                        title={toolName} type_="tool-call" state="output-available"
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

          | Client__State__StateReducer.Message.ToolCall({toolName, state, input, result, errorText, _}) =>
            // Render tool call message
            <div key={messageId} className="max-w-full">
              <AIElements.Tool
                defaultOpen={switch state {
                | OutputAvailable | OutputError => true
                | _ => false
                }}
              >
                <AIElements.ToolHeader
                  title={toolName} type_="tool-call" state={toolStateToString(state)}
                />
                <AIElements.ToolContent>
                  {switch input {
                  | Some(input) => <AIElements.ToolInput input={input} />
                  | None => React.null
                  }}
                  {switch (result, errorText) {
                  | (Some(result), _) =>
                    <AIElements.ToolOutput
                      output={<AIElements.Response>
                        {React.string(JSON.stringifyAny(result)->Option.getOr("{}"))}
                      </AIElements.Response>}
                    />
                  | (None, Some(error)) => <AIElements.ToolOutput errorText={error} />
                  | (None, None) => React.null
                  }}
                </AIElements.ToolContent>
              </AIElements.Tool>
            </div>
          }
        })
        ->React.array}
      </AIElements.ConversationContent>
      <AIElements.ConversationScrollButton />
    </AIElements.Conversation>
    <Client__SelectedElementDisplay />
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
          <AIElements.PromptInputButton
            variant={webSearch ? "default" : "ghost"} onClick={() => setWebSearch(prev => !prev)}
          >
            <Icons.GlobeIcon style={{"width": "16px", "height": "16px"}} />
            <span> {React.string("Search")} </span>
          </AIElements.PromptInputButton>
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
          disabled={input === "" && !isStreaming} status={isStreaming ? "streaming" : "idle"}
        />
      </AIElements.PromptInputFooter>
    </AIElements.PromptInput>
  </div>
}
