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

// Import Frontman UI components
module UserMessage = Client__UserMessage
module AssistantMessage = Client__AssistantMessage
module ToolCallBlock = Client__ToolCallBlock
module ToolGroupBlock = Client__ToolGroupBlock
module ToolGroupTypes = Client__ToolGroupTypes
module ToolGroupUtils = Client__ToolGroupUtils
module TodoListBlock = Client__TodoListBlock
module TodoBatchBlock = Client__TodoBatchBlock
module TodoStatusNotification = Client__TodoStatusNotification
module ThinkingIndicator = Client__ThinkingIndicator
module TodoUtils = Client__TodoUtils
module UseThinkingState = Client__UseThinkingState
module ScrollContainer = Client__ScrollContainer
module PromptInput = Client__PromptInput

// Display item for grouped rendering
type displayItem =
  | UserMsg(Message.t, int) // Message, originalIndex
  | AssistantMsg(Message.t, int)
  | SingleToolCall(Message.toolCall, int)
  | SpawnerToolCall(Message.toolCall, int) // Subagent spawner - indigo styling
  | ToolGroup(ToolGroupTypes.toolGroup, int) // First tool's original index
  | TodoToolCall(Message.toolCall, int)
  // New todo UX display items
  | TodoBatch(StateTypes.TodoBatchEvent.t)
  | TodoStatus(StateTypes.TodoStatusEvent.t)

// Item type for chronological sorting - all items must have timestamps
type chronoItem =
  | ChronoMessage(Message.t, float)
  | ChronoBatchEvent(StateTypes.TodoBatchEvent.t)
  | ChronoStatusEvent(StateTypes.TodoStatusEvent.t)

// Get timestamp from a message
let getMessageCreatedAt = (msg: Message.t): float => {
  switch msg {
  | Message.User({createdAt, _}) => createdAt
  | Message.Assistant(Streaming({createdAt, _})) => createdAt
  | Message.Assistant(Completed({createdAt, _})) => createdAt
  | Message.ToolCall({createdAt, _}) => createdAt
  }
}

/**
 * Merge messages and todo events into a chronologically sorted list
 */
let mergeChronologically = (
  messages: array<Message.t>,
  batchEvents: array<StateTypes.TodoBatchEvent.t>,
  statusEvents: array<StateTypes.TodoStatusEvent.t>,
): array<chronoItem> => {
  let items: array<chronoItem> = []

  // Add all messages
  messages->Array.forEach(msg => {
    items->Array.push(ChronoMessage(msg, getMessageCreatedAt(msg)))
  })

  // Add all batch events
  batchEvents->Array.forEach(event => {
    items->Array.push(ChronoBatchEvent(event))
  })

  // Add all status events
  statusEvents->Array.forEach(event => {
    items->Array.push(ChronoStatusEvent(event))
  })

  // Sort by timestamp
  items->Array.toSorted((a, b) => {
    let timeA = switch a {
    | ChronoMessage(_, t) => t
    | ChronoBatchEvent(e) => e.createdAt
    | ChronoStatusEvent(e) => e.createdAt
    }
    let timeB = switch b {
    | ChronoMessage(_, t) => t
    | ChronoBatchEvent(e) => e.createdAt
    | ChronoStatusEvent(e) => e.createdAt
    }
    timeA -. timeB
  })
}

/**
 * Transform messages into display items, grouping consecutive tool calls
 * 
 * Algorithm:
 * 1. Merge messages with todo events chronologically
 * 2. Collect consecutive tool calls (including todos)
 * 3. Let the grouping utility handle them - it will group exploration tools
 * 4. Todo tools will be rendered as singles (they break groups naturally via breaksGrouping)
 * 5. Todo batch events are merged when consecutive (multiple todo_add calls become one "Added X todos")
 * 6. Todo status events are rendered with dedicated notification components
 */
let groupMessagesWithEvents = (
  messages: array<Message.t>,
  batchEvents: array<StateTypes.TodoBatchEvent.t>,
  statusEvents: array<StateTypes.TodoStatusEvent.t>,
): array<displayItem> => {
  let result: array<displayItem> = []
  let pendingToolCalls: ref<array<(Message.toolCall, int)>> = ref([])
  let pendingBatchEvents: ref<array<StateTypes.TodoBatchEvent.t>> = ref([])

  // Merge everything chronologically
  let chronoItems = mergeChronologically(messages, batchEvents, statusEvents)

  // Flush pending batch events by merging them into one
  let flushBatchEvents = () => {
    let pending = pendingBatchEvents.contents
    if Array.length(pending) > 0 {
      // Merge all entries from consecutive batch events
      let allEntries = pending->Array.flatMap(e => e.entries)
      let totalCount = pending->Array.reduce(0, (acc, e) => acc + e.count)
      // Use first event's id and timestamp for the merged batch
      let firstEvent = pending->Array.getUnsafe(0)

      let mergedEvent: StateTypes.TodoBatchEvent.t = {
        id: firstEvent.id,
        entries: allEntries,
        count: totalCount,
        createdAt: firstEvent.createdAt,
      }

      result->Array.push(TodoBatch(mergedEvent))
      pendingBatchEvents := []
    }
  }

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
        | ToolGroupTypes.SpawnerTool(tc) =>
          // Subagent spawner tool - render with indigo styling
          result->Array.push(SpawnerToolCall(tc, firstIndex))
        | ToolGroupTypes.ToolGroup(group) => result->Array.push(ToolGroup(group, firstIndex))
        }
      })

      pendingToolCalls := []
    }
  }

  // Flush all pending items
  let flushAll = () => {
    flushToolCalls()
    flushBatchEvents()
  }

  chronoItems->Array.forEachWithIndex((chronoItem, index) => {
    switch chronoItem {
    | ChronoMessage(msg, _) =>
      switch msg {
      | Message.ToolCall(tc) =>
        // Don't flush batch events here - todo_add calls interleave with their batch events
        // and we want to batch consecutive adds together
        pendingToolCalls.contents->Array.push((tc, index))
      | Message.User(_) =>
        // Flush all pending, then add user message
        flushAll()
        result->Array.push(UserMsg(msg, index))
      | Message.Assistant(_) =>
        // Flush all pending, then add assistant message
        flushAll()
        result->Array.push(AssistantMsg(msg, index))
      }
    | ChronoBatchEvent(event) =>
      // Flush tool calls, then accumulate batch events
      flushToolCalls()
      pendingBatchEvents.contents->Array.push(event)
    | ChronoStatusEvent(event) =>
      // Status events break batch grouping - flush everything first
      flushAll()
      result->Array.push(TodoStatus(event))
    }
  })

  // Flush any remaining items
  flushAll()

  result
}

// Legacy function for backwards compatibility (used in tests)
let groupMessages = (messages: array<Message.t>): array<displayItem> => {
  groupMessagesWithEvents(messages, [], [])
}

let models: array<PromptInput.model> = [
  {name: "GPT 4o", value: "openai/gpt-4o"},
  {name: "Deepseek R1", value: "deepseek/deepseek-r1"},
]

@react.component
let make = () => {
  let (input, setInput) = React.useState(() => "")
  let (model, setModel) = React.useState(() => Array.getUnsafe(models, 0).value)

  // Get messages from our state store
  let messages = Client__State.useSelector(Client__State.Selectors.messages)
  let isStreaming = Client__State.useSelector(Client__State.Selectors.isStreaming)
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)
  let isConnected = Client__State.useSelector(Client__State.Selectors.isConnected)
  let _planEntries = Client__State.useSelector(Client__State.Selectors.currentPlanEntries)
  let sessionInitialized = Client__State.useSelector(Client__State.Selectors.sessionInitialized)

  // Get todo events for the current task
  let todoBatchEvents = Client__State.useSelector(Client__State.Selectors.currentTodoBatchEvents)
  let todoStatusEvents = Client__State.useSelector(Client__State.Selectors.currentTodoStatusEvents)

  // Use the thinking state hook
  let (thinkingState, thinkingMessageId) = UseThinkingState.useWithMessageId(
    ~messages,
    ~isStreaming,
    ~isConnected,
    ~sessionInitialized,
  )

  let handleSubmit = () => {
    if input !== "" {
      let content = [Client__State.UserContentPart.Text({text: input})]
      Client__State.Actions.addUserMessage(~content)
      setInput(_ => "")
    }
  }

  // Group messages for display (with todo events)
  let displayItems = React.useMemo3(
    () => groupMessagesWithEvents(messages, todoBatchEvents, todoStatusEvents),
    (messages, todoBatchEvents, todoStatusEvents),
  )
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

    | SpawnerToolCall(tc, _) =>
      // Subagent spawner tool - render with indigo styling
      let messageId = `spawner-${tc.id}`
      <React.Fragment key={messageId}>
        <ToolCallBlock
          toolName={tc.toolName}
          state={tc.state}
          input={tc.input}
          inputBuffer={tc.inputBuffer}
          result={tc.result}
          errorText={tc.errorText}
          defaultExpanded=false
          isSpawner=true
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
          todos isLoading messageId operationLabel={TodoUtils.getTodoOperationLabel(tc.toolName, tc.state)}
        />
      </React.Fragment>

    | TodoBatch(event) =>
      // Render "Added X todos" with expand/collapse
      let messageId = `todo-batch-${event.id}`
      <React.Fragment key={messageId}>
        <TodoBatchBlock
          entries={event.entries} count={event.count} createdAt={event.createdAt} messageId
        />
      </React.Fragment>

    | TodoStatus(event) =>
      // Render "Starting: X" or "Finished: X" notification
      let messageId = `todo-status-${event.id}`
      <React.Fragment key={messageId}>
        <TodoStatusNotification content={event.content} eventType={event.eventType} messageId />
      </React.Fragment>

    // Handle any unexpected message types
    | UserMsg(_, _) | AssistantMsg(_, _) => React.null
    }
  }

  <div className="flex flex-col h-full bg-zinc-900 text-zinc-200">
    <TaskTabs />
    <ScrollContainer className="flex-grow overflow-hidden">
      <ScrollContainer.ContentWrapper>
        {
          // Show loading indicator while initializing
          if !sessionInitialized {
            <div className="flex items-center gap-2 py-3 px-4 text-[13px] text-zinc-400">
              <span className="shimmer-text">
                {React.string("Loading project context...")}
              </span>
            </div>
          } else {
            React.null
          }
        }
        
        // Render grouped messages
        {displayItems
        ->Array.mapWithIndex((item, index) => renderDisplayItem(item, index))
        ->React.array}
        
        // Thinking indicator (shows after last message when waiting for response)
        <ThinkingIndicator
          show={thinkingState.showThinking}
          context=?{thinkingState.thinkingContext}
          messageId={thinkingMessageId}
        />
      </ScrollContainer.ContentWrapper>
      <ScrollContainer.ScrollButton />
    </ScrollContainer>
    // <Client__PlanDisplay entries=planEntries />
    <Client__SelectedElementDisplay />
    <Client__FigmaNodeDisplay />
    <PromptInput
      value={input}
      onChange={v => setInput(_ => v)}
      onSubmit={handleSubmit}
      models
      selectedModel={model}
      onModelChange={v => setModel(_ => v)}
      isAgentRunning
      isConnected
    />
  </div>
}
