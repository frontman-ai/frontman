/**
 * Client__Chatbox - Main chat interface component
 *
 * Renders the conversation with Frontman-style UI components:
 * - User and assistant messages
 * - Tool call blocks with icons and status
 * - TODO list integration
 * - Thinking indicators
 */
module Icons = Bindings__RadixUI__Icons
module TaskTabs = Client__TaskTabs
module Message = Client__State__Types.Message
module StateTypes = Client__State__Types
module RuntimeConfig = Client__RuntimeConfig

// Import Frontman UI components
module UserMessage = Client__UserMessage
module AssistantMessage = Client__AssistantMessage
module ToolCallBlock = Client__ToolCallBlock
module ToolGroupBlock = Client__ToolGroupBlock
module ToolGroupTypes = Client__ToolGroupTypes
module ToolGroupUtils = Client__ToolGroupUtils
module TodoListBlock = Client__TodoListBlock
module ThinkingIndicator = Client__ThinkingIndicator
module TodoUtils = Client__TodoUtils
module UseThinkingState = Client__UseThinkingState
module ScrollContainer = Client__ScrollContainer
module PromptInput = Client__PromptInput
module ErrorBanner = Client__ErrorBanner

// Display item for grouped rendering
type displayItem =
  | UserMsg(Message.t, int) // Message, originalIndex
  | AssistantMsg(Message.t, int)
  | SingleToolCall(Message.toolCall, int)
  | ToolGroup(ToolGroupTypes.toolGroup, int) // First tool's original index
  | TodoToolCall(Message.toolCall, int)

/**
 * Transform messages into display items, grouping consecutive tool calls
 *
 * Algorithm:
 * 1. Iterate through messages in order
 * 2. Collect consecutive tool calls
 * 3. Let the grouping utility handle them - it will group exploration tools
 * 4. Todo tools will be rendered as singles (they break groups naturally via breaksGrouping)
 */
let groupMessages = (messages: array<Message.t>): array<displayItem> => {
  let result: array<displayItem> = []
  let pendingToolCalls: ref<array<(Message.toolCall, int)>> = ref([])

  // Flush pending tool calls by grouping them
  let flushToolCalls = () => {
    let pending = pendingToolCalls.contents
    if Array.length(pending) > 0 {
      // Extract just the tool calls for grouping
      let toolCalls = pending->Array.map(((tc, _)) => tc)
      let firstIndex = pending->Array.getUnsafe(0)->Pair.second

      // Use the grouping utility - it handles what to group vs not
      let grouped = ToolGroupUtils.groupToolCalls(toolCalls, ~minGroupSize=1)

      grouped->Array.forEach(item => {
        switch item {
        | ToolGroupTypes.SingleTool(tc) =>
          // Check if it's a TODO tool - render with special component
          if TodoUtils.isTodoTool(tc.toolName) {
            result->Array.push(TodoToolCall(tc, firstIndex))
          } else {
            result->Array.push(SingleToolCall(tc, firstIndex))
          }
        | ToolGroupTypes.ToolGroup(group) => result->Array.push(ToolGroup(group, firstIndex))
        }
      })

      pendingToolCalls := []
    }
  }

  messages->Array.forEachWithIndex((msg, index) => {
    switch msg {
    | Message.ToolCall(tc) => pendingToolCalls.contents->Array.push((tc, index))
    | Message.User(_) =>
      flushToolCalls()
      result->Array.push(UserMsg(msg, index))
    | Message.Assistant(_) =>
      flushToolCalls()
      result->Array.push(AssistantMsg(msg, index))
    }
  })

  // Flush any remaining tool calls
  flushToolCalls()

  result
}

@react.component
let make = (~onSettingsClick: unit => unit) => {
  let {session, createSession} = Client__FrontmanProvider.useFrontman()

  let messages = Client__State.useSelector(Client__State.Selectors.messages)
  let isStreaming = Client__State.useSelector(Client__State.Selectors.isStreaming)
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)
  let hasActiveACPSession = Client__State.useSelector(Client__State.Selectors.hasActiveACPSession)
  let sessionInitialized = Client__State.useSelector(Client__State.Selectors.sessionInitialized)
  let planEntries = Client__State.useSelector(Client__State.Selectors.currentPlanEntries)
  let turnError = Client__State.useSelector(Client__State.Selectors.turnError)
  let usageInfo = Client__State.useSelector(Client__State.Selectors.usageInfo)
  let modelsConfig = Client__State.useSelector(Client__State.Selectors.modelsConfig)
  let selectedModel = Client__State.useSelector(Client__State.Selectors.selectedModel)
  let hasProviderConfigured = Client__State.useSelector(Client__State.Selectors.hasAnyProviderConfigured)
  let webPreviewIsSelecting = Client__State.useSelector(Client__State.Selectors.webPreviewIsSelecting)
  let hasEnvKey = RuntimeConfig.hasOpenrouterKey(RuntimeConfig.read())
  let hasAnyKey = hasProviderConfigured || hasEnvKey

  let providers = modelsConfig->Option.mapOr([], config => config.providers)

  let isUsageExhausted = switch (usageInfo, hasAnyKey) {
  | (Some({remaining: Some(remaining), hasServerKey: Some(true)}), false)
    if remaining <= 0 => true
  | _ => false
  }

  let (thinkingState, thinkingMessageId) = UseThinkingState.useWithMessageId(
    ~messages,
    ~isStreaming,
    ~isAgentRunning,
    ~hasActiveACPSession,
    ~sessionInitialized,
  )

  let handleSubmit = (~text: string, ~inputItems: array<Client__PromptInput.inputItem>) => {
    // text already has pasted-text chips expanded inline at their DOM position
    // (handled by getExpandedTextFromEditable in PromptInput's doSubmit)

    // Build file attachment content parts (images + PDFs)
    let fileParts = inputItems->Array.filterMap(item =>
      switch item {
      | Client__PromptInput.FileAttachment({name, dataUrl, mediaType}) =>
        Some(Client__State.UserContentPart.Image({image: dataUrl, mediaType: Some(mediaType), name: Some(name)}))
      | Client__PromptInput.PastedText(_) => None
      }
    )

    // Build content array: text first, then file parts
    let textParts = if text != "" {
      [Client__State.UserContentPart.Text({text: text})]
    } else {
      []
    }
    let content = Array.concat(textParts, fileParts)

    if Array.length(content) > 0 {
      let sendMessage = (sessionId: string) => {
        Client__State.Actions.addUserMessage(~sessionId, ~content)
      }
      switch session {
      | Some(sess) => sendMessage(sess.sessionId)
      | None =>
        createSession(~onComplete=result => {
          switch result {
          | Ok(sessionId) => sendMessage(sessionId)
          | Error(err) => Console.error2("[Chatbox] Session creation failed:", err)
          }
        })
      }
    }
  }

  // Group messages for display
  let displayItems = React.useMemo1(() => groupMessages(messages), [messages])
  let totalItems = Array.length(displayItems)

  // Find the index of the last ToolGroup in displayItems
  // This is used to determine which group should show "Exploring..." state
  let lastToolGroupIndex = displayItems->Array.reduceWithIndex(-1, (acc, item, idx) => {
    switch item {
    | ToolGroup(_, _) => idx
    | _ => acc
    }
  })

  // Render a single display item
  let renderDisplayItem = (item: displayItem, itemIndex: int) => {
    let isLastItem = itemIndex == totalItems - 1
    let isLastToolGroup = itemIndex == lastToolGroupIndex

    switch item {
    | UserMsg(Message.User({id, content, _}), _) =>
      // Use stable message ID for key
      let messageId = `user-${id}`
      <React.Fragment key={messageId}>
        <UserMessage content messageId isNew={isLastItem} />
      </React.Fragment>

    | AssistantMsg(Message.Assistant(Streaming({id, textBuffer, _})), _) =>
      // Use stable message ID for key
      let messageId = `assistant-${id}`
      <React.Fragment key={messageId}>
        <AssistantMessage
          variant=AssistantMessage.Streaming content={textBuffer} messageId isNew={isLastItem}
        />
      </React.Fragment>

    | AssistantMsg(Message.Assistant(Completed({id, content, _})), _) =>
      // Use stable message ID for key
      let messageId = `assistant-${id}`
      <React.Fragment key={messageId}>
        {content
        ->Array.mapWithIndex((part, i) => {
          let partKey = `${messageId}-${Int.toString(i)}`

          switch part {
          | Client__State__Types.AssistantContentPart.Text({text}) =>
            <AssistantMessage
              key={partKey}
              variant=AssistantMessage.Completed
              content={text}
              messageId={partKey}
              isNew={isLastItem && i == 0}
            />

          | Client__State__Types.AssistantContentPart.ToolCall({toolCallId: _, toolName, input}) =>
            // Embedded tool calls in completed messages (legacy format)
            <ToolCallBlock
              key={partKey}
              toolName
              state=Message.OutputAvailable
              input={Some(input)}
              inputBuffer=""
              result=None
              errorText=None
              defaultExpanded=false
              messageId={partKey}
            />
          }
        })
        ->React.array}
      </React.Fragment>

    | SingleToolCall(tc, _) =>
      // Use stable tool call ID for key
      let messageId = `tool-${tc.id}`
      <React.Fragment key={messageId}>
        <ToolCallBlock
          toolName={tc.toolName}
          state={tc.state}
          input={tc.input}
          inputBuffer={tc.inputBuffer}
          result={tc.result}
          errorText={tc.errorText}
          defaultExpanded=false
          messageId
        />
      </React.Fragment>

    | ToolGroup(group, _) =>
      // group.id is now stable (based on first tool call's ID)
      // Pass both isLastToolGroup and isLastItem - group is "open" only if both are true
      // This ensures groups close when items (like assistant messages) appear after them
      <React.Fragment key={group.id}>
        <ToolGroupBlock group messageId={group.id} isLastToolGroup isLastItem isAgentRunning />
      </React.Fragment>

    | TodoToolCall(tc, _) =>
      // Use stable tool call ID for key
      let messageId = `todo-${tc.id}`
      // Extract TODOs from input first (for todo_write), then result
      let todos = TodoUtils.extractTodos(~input=tc.input, ~result=tc.result)
      let isLoading = switch tc.state {
      | InputStreaming | InputAvailable => true
      | OutputAvailable | OutputError => false
      }

      <React.Fragment key={messageId}>
        <TodoListBlock
          todos
          isLoading
          messageId
          operationLabel={TodoUtils.getTodoOperationLabel(tc.toolName, tc.state)}
        />
      </React.Fragment>

    // Handle any unexpected message types
    | UserMsg(_, _) | AssistantMsg(_, _) => React.null
    }
  }

  <div className="flex flex-col h-full bg-[#180C2D] text-zinc-200">
    <TaskTabs onSettingsClick />
    <ScrollContainer className="flex-grow overflow-hidden">
      <ScrollContainer.ContentWrapper>
        {
          // Show loading indicator while initializing
          if !sessionInitialized {
            <div className="flex items-center gap-2 py-3 px-4 text-[13px] text-zinc-400">
              <span className="shimmer-text"> {React.string("Loading project context...")} </span>
            </div>
          } else {
            React.null
          }
        }

        // Render grouped messages
        {displayItems
        ->Array.mapWithIndex((item, index) => renderDisplayItem(item, index))
        ->React.array}

        // Error banner (shows when there's a turn error)
        {switch turnError {
        | Some(error) => <ErrorBanner error />
        | None => React.null
        }}

        // Thinking indicator (shows after last message when waiting for response)
        <ThinkingIndicator
          show={thinkingState.showThinking}
          context=?{thinkingState.thinkingContext}
          messageId={thinkingMessageId}
        />
      </ScrollContainer.ContentWrapper>
      <ScrollContainer.ScrollButton />
    </ScrollContainer>
    <Client__PlanDisplay entries=planEntries />
    <Client__SelectedElementDisplay />
    {switch (usageInfo, hasAnyKey) {
    | (Some({limit: Some(limit), remaining: Some(remaining), hasServerKey: Some(true)}), false) =>
      <div className="px-4 pb-1 text-xs text-zinc-400">
        {React.string(
          `Free requests remaining: ${remaining->Int.toString} / ${limit->Int.toString}. Add your API key in Settings to remove limits.`,
        )}
      </div>
    | _ => React.null
    }}
    <PromptInput
      onSubmit={handleSubmit}
      onCancel={Client__State.Actions.cancelTurn}
      providers
      selectedModel
      onModelChange={(~provider, ~value) =>
        Client__State.Actions.setSelectedModel(~provider, ~value)}
      isAgentRunning
      hasActiveACPSession
      disabled={isUsageExhausted}
      disabledPlaceholder="Free requests exhausted. Add your API key in Settings to continue."
      onSelectElement={Client__State.Actions.toggleWebPreviewSelection}
      isSelecting={webPreviewIsSelecting}
    />
  </div>
}
