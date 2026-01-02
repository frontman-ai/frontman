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
 * Optimized to use immutable array operations instead of mutations
 */
let mergeChronologically = (
  messages: array<Message.t>,
  batchEvents: array<StateTypes.TodoBatchEvent.t>,
  statusEvents: array<StateTypes.TodoStatusEvent.t>,
): array<chronoItem> => {
  // Convert messages to chrono items
  let messageItems = messages->Array.map(msg => 
    ChronoMessage(msg, getMessageCreatedAt(msg))
  )

  // Convert batch events to chrono items
  let batchItems = batchEvents->Array.map(event => ChronoBatchEvent(event))

  // Convert status events to chrono items
  let statusItems = statusEvents->Array.map(event => ChronoStatusEvent(event))

  // Concatenate all items and sort by timestamp
  messageItems->Array.concat(batchItems)->Array.concat(statusItems)->Array.toSorted((a, b) => {
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
 * Optimized to reduce array mutations and improve performance
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
  // Merge everything chronologically
  let chronoItems = mergeChronologically(messages, batchEvents, statusEvents)

  // Helper to flush batch events by merging them into one
  let flushBatchEvents = (pending: array<StateTypes.TodoBatchEvent.t>): option<displayItem> => {
    if Array.length(pending) > 0 {
      // Merge all entries from consecutive batch events
      let allEntries = pending->Array.flatMap(e => e.entries)
      let totalCount = pending->Array.reduce(0, (acc, e) => acc + e.count)
      let firstEvent = pending->Array.getUnsafe(0)

      Some(TodoBatch({
        id: firstEvent.id,
        entries: allEntries,
        count: totalCount,
        createdAt: firstEvent.createdAt,
      }))
    } else {
      None
    }
  }

  // Helper to flush tool calls by grouping them
  let flushToolCalls = (pending: array<(Message.toolCall, int)>): array<displayItem> => {
    if Array.length(pending) == 0 {
      []
    } else {
      let toolCalls = pending->Array.map(((tc, _)) => tc)
      let firstIndex = pending->Array.getUnsafe(0)->Pair.second
      let grouped = ToolGroupUtils.groupToolCalls(toolCalls, ~minGroupSize=1)

      grouped->Array.map(item => {
        switch item {
        | ToolGroupTypes.SingleTool(tc) =>
          if TodoUtils.isTodoTool(tc.toolName) {
            TodoToolCall(tc, firstIndex)
          } else {
            SingleToolCall(tc, firstIndex)
          }
        | ToolGroupTypes.SpawnerTool(tc) => SpawnerToolCall(tc, firstIndex)
        | ToolGroupTypes.ToolGroup(group) => ToolGroup(group, firstIndex)
        }
      })
    }
  }

  // Process all items using reduce for better performance
  let (result, pendingToolCalls, pendingBatchEvents) = chronoItems->Array.reduceWithIndex(
    ([], [], []),
    ((accResult, accToolCalls, accBatchEvents), chronoItem, index) => {
      switch chronoItem {
      | ChronoMessage(msg, _) =>
        switch msg {
        | Message.ToolCall(tc) =>
          // Accumulate tool calls
          (accResult, accToolCalls->Array.concat([(tc, index)]), accBatchEvents)
        | Message.User(_) =>
          // Flush all pending, then add user message
          let flushedTools = flushToolCalls(accToolCalls)
          let flushedBatch = flushBatchEvents(accBatchEvents)
          let newItems = flushedTools
            ->Array.concat(flushedBatch->Option.mapOr([], item => [item]))
            ->Array.concat([UserMsg(msg, index)])
          (accResult->Array.concat(newItems), [], [])
        | Message.Assistant(_) =>
          // Flush all pending, then add assistant message
          let flushedTools = flushToolCalls(accToolCalls)
          let flushedBatch = flushBatchEvents(accBatchEvents)
          let newItems = flushedTools
            ->Array.concat(flushedBatch->Option.mapOr([], item => [item]))
            ->Array.concat([AssistantMsg(msg, index)])
          (accResult->Array.concat(newItems), [], [])
        }
      | ChronoBatchEvent(event) =>
        // Flush tool calls, then accumulate batch events
        let flushedTools = flushToolCalls(accToolCalls)
        let newResult = accResult->Array.concat(flushedTools)
        (newResult, [], accBatchEvents->Array.concat([event]))
      | ChronoStatusEvent(event) =>
        // Flush everything first
        let flushedTools = flushToolCalls(accToolCalls)
        let flushedBatch = flushBatchEvents(accBatchEvents)
        let newItems = flushedTools
          ->Array.concat(flushedBatch->Option.mapOr([], item => [item]))
          ->Array.concat([TodoStatus(event)])
        (accResult->Array.concat(newItems), [], [])
      }
    },
  )

  // Flush any remaining items
  let flushedTools = flushToolCalls(pendingToolCalls)
  let flushedBatch = flushBatchEvents(pendingBatchEvents)
  result
    ->Array.concat(flushedTools)
    ->Array.concat(flushedBatch->Option.mapOr([], item => [item]))
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
  let lastToolGroupIndex = React.useMemo1(() => {
    displayItems->Array.reduceWithIndex(-1, (acc, item, idx) => {
      switch item {
      | ToolGroup(_, _) => idx
      | _ => acc
      }
    })
  }, [displayItems])

  // Render a single display item - memoized to avoid recreating on every render
  let renderDisplayItem = React.useCallback4((item: displayItem, itemIndex: int) => {
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
  }, (totalItems, lastToolGroupIndex, displayItems, isAgentRunning))

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

