/**
 * Client__Chatbox - Main chat interface component
 *
 * Renders the conversation with Frontman-style UI components:
 * - User and assistant messages
 * - Tool call blocks with icons and status
 * - TODO list integration
 * - Thinking indicators
 */
module Log = FrontmanLogs.Logs.Make({
  let component = #Chatbox
})

module Icons = Bindings__RadixUI__Icons
module Message = Client__State__Types.Message
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
  | UserMsg(Message.t)
  | AssistantMsg(Message.t)
  | SingleToolCall(Message.toolCall)
  | ToolGroup(ToolGroupTypes.toolGroup)
  | TodoToolCall(Message.toolCall)
  | ErrorMsg(Message.t)

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
  let pendingToolCalls: ref<array<Message.toolCall>> = ref([])

  // Flush pending tool calls by grouping them
  let flushToolCalls = () => {
    let pending = pendingToolCalls.contents
    if Array.length(pending) > 0 {
      // Use the grouping utility - it handles what to group vs not
      let grouped = ToolGroupUtils.groupToolCalls(pending, ~minGroupSize=1)

      grouped->Array.forEach(item => {
        switch item {
        | ToolGroupTypes.SingleTool(tc) =>
          // Check if it's a TODO tool - render with special component
          if TodoUtils.isTodoTool(tc.toolName) {
            result->Array.push(TodoToolCall(tc))
          } else {
            result->Array.push(SingleToolCall(tc))
          }
        | ToolGroupTypes.ToolGroup(group) => result->Array.push(ToolGroup(group))
        }
      })

      pendingToolCalls := []
    }
  }

  messages->Array.forEach(msg => {
    switch msg {
    | Message.ToolCall(tc) => pendingToolCalls.contents->Array.push(tc)
    | Message.User(_) =>
      flushToolCalls()
      result->Array.push(UserMsg(msg))
    | Message.Assistant(_) =>
      flushToolCalls()
      result->Array.push(AssistantMsg(msg))
    | Message.Error(_) =>
      flushToolCalls()
      result->Array.push(ErrorMsg(msg))
    }
  })

  // Flush any remaining tool calls
  flushToolCalls()

  result
}

@react.component
let make = () => {
  let {session, createSession} = Client__FrontmanProvider.useFrontman()

  let messages = Client__State.useSelector(Client__State.Selectors.messages)
  let isStreaming = Client__State.useSelector(Client__State.Selectors.isStreaming)
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)
  let hasActiveACPSession = Client__State.useSelector(Client__State.Selectors.hasActiveACPSession)
  let sessionInitialized = Client__State.useSelector(Client__State.Selectors.sessionInitialized)
  let planEntries = Client__State.useSelector(Client__State.Selectors.currentPlanEntries)
  let turnError = Client__State.useSelector(Client__State.Selectors.turnError)
  let lastErrorId = Client__State.useSelector(Client__State.Selectors.lastErrorId)
  let currentTaskId = Client__State.useSelector(Client__State.Selectors.currentTaskId)
  let retryStatus = Client__State.useSelector(Client__State.Selectors.retryStatus)
  let usageInfo = Client__State.useSelector(Client__State.Selectors.usageInfo)
  let configOptions = Client__State.useSelector(Client__State.Selectors.configOptions)
  let selectedModelValue = Client__State.useSelector(Client__State.Selectors.selectedModelValue)
  let hasProviderConfigured = Client__State.useSelector(
    Client__State.Selectors.hasAnyProviderConfigured,
  )
  let webPreviewIsSelecting = Client__State.useSelector(
    Client__State.Selectors.webPreviewIsSelecting,
  )
  let annotations = Client__State.useSelector(Client__State.Selectors.annotations)
  let hasEnrichingAnnotations = Client__State.useSelector(
    Client__State.Selectors.hasEnrichingAnnotations,
  )
  let runtimeConfig = RuntimeConfig.read()
  let hasEnvKey = RuntimeConfig.hasAnyProviderKey(runtimeConfig)
  let hasAnyKey = hasProviderConfigured || hasEnvKey

  let modelConfigOption =
    configOptions->Option.flatMap(opts =>
      FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.findConfigOptionByCategory(opts, Model)
    )
  let isModelsConfigLoading = configOptions->Option.isNone

  let isUsageExhausted = switch (usageInfo, hasAnyKey) {
  | (Some({remaining: Some(remaining), hasServerKey: Some(true)}), false) if remaining <= 0 => true
  | _ => false
  }

  let (thinkingState, thinkingMessageId) = UseThinkingState.useWithMessageId(
    ~messages,
    ~isStreaming,
    ~isAgentRunning,
    ~hasActiveACPSession,
    ~sessionInitialized,
  )

  let hasPendingQuestion =
    Client__State.useSelector(Client__State.Selectors.pendingQuestion)->Option.isSome
  let hasAnnotations = Array.length(annotations) > 0

  let handleSubmit = (~text: string, ~inputItems: array<Client__PromptInput.inputItem>) => {
    // Snapshot live annotations into serializable MessageAnnotation records
    let messageAnnotations =
      annotations->Array.map(Client__Message.MessageAnnotation.fromAnnotation)

    let sendWithContent = content => {
      // Allow send if there's content OR annotations (annotations are first-class message content)
      switch Array.length(content) > 0 || Array.length(messageAnnotations) > 0 {
      | false => ()
      | true =>
        let sendMessage = (sessionId: string) => {
          Client__State.Actions.addUserMessage(
            ~sessionId,
            ~content,
            ~annotations=messageAnnotations,
          )
        }
        switch session {
        | Some(sess) => sendMessage(sess.sessionId)
        | None =>
          createSession(~onComplete=result => {
            switch result {
            | Ok(sessionId) => sendMessage(sessionId)
            | Error(err) => Log.error(~ctx={"error": err}, "Session creation failed")
            }
          })
        }
      }
    }

    let textParts = switch text != "" {
    | true => [Client__State.UserContentPart.Text({text: text})]
    | false => []
    }

    let fileData = inputItems->Array.filterMap(item =>
      switch item {
      | Client__PromptInput.FileAttachment({id, name, mediaType, dataUrl}) =>
        Some((id, name, mediaType, dataUrl))
      | Client__PromptInput.PastedText(_) => None
      }
    )

    switch Array.length(fileData) > 0 {
    | false => sendWithContent(textParts)
    | true =>
      let _ =
        fileData
        ->Array.map(((id, name, mediaType, dataUrl)) => {
          Client__ImageLimits.constrainDataUrl(
            dataUrl,
            Client__ImageLimits.conservative,
          )->Promise.then(constrained => {
            let actualMediaType = switch constrained->String.startsWith("data:image/jpeg") {
            | true => "image/jpeg"
            | false => mediaType
            }
            Promise.resolve(
              Client__State.UserContentPart.Image({
                id: Some(id),
                image: constrained,
                mediaType: Some(actualMediaType),
                name: Some(name),
              }),
            )
          })
        })
        ->Promise.all
        ->Promise.then(fileParts => {
          sendWithContent(Array.concat(textParts, fileParts))
          Promise.resolve()
        })
        ->Promise.catch(err => {
          Log.error(~error=JsExn.fromException(err), "Image resize failed")
          sendWithContent(textParts)
          Promise.resolve()
        })
    }
  }

  // Group messages for display, with referential stability for tool groups.
  // MessageStore.update does a shallow Array.copy, so unchanged toolCall records
  // keep the same reference. We cache previous groups by ID and reuse them when
  // all constituent tool calls are reference-equal — this lets React skip
  // re-rendering groups that haven't actually changed during streaming.
  let groupCacheRef: React.ref<Dict.t<ToolGroupTypes.toolGroup>> = React.useRef(Dict.make())
  let displayItems = React.useMemo1(() => {
    let items = groupMessages(messages)
    let prevCache = groupCacheRef.current
    let newCache = Dict.make()

    let stableItems = items->Array.map(item => {
      switch item {
      | ToolGroup(group) =>
        let stableGroup: ToolGroupTypes.toolGroup = switch prevCache->Dict.get(group.id) {
        | Some(prev)
          if Array.length(prev.toolCalls) == Array.length(group.toolCalls) &&
            prev.toolCalls->Array.everyWithIndex(
              (prevTc, i) => {
                prevTc === group.toolCalls->Array.getUnsafe(i)
              },
            ) => prev
        | _ => group
        }
        newCache->Dict.set(stableGroup.id, stableGroup)
        ToolGroup(stableGroup)
      | other => other
      }
    })

    groupCacheRef.current = newCache
    stableItems
  }, [messages])
  let totalItems = Array.length(displayItems)

  // Find the index of the last ToolGroup in displayItems
  // This is used to determine which group should show "Exploring..." state
  let lastToolGroupIndex = displayItems->Array.reduceWithIndex(-1, (acc, item, idx) => {
    switch item {
    | ToolGroup(_) => idx
    | _ => acc
    }
  })

  // Render a single display item
  let renderDisplayItem = (item: displayItem, itemIndex: int) => {
    let isLastItem = itemIndex == totalItems - 1
    let isLastToolGroup = itemIndex == lastToolGroupIndex

    switch item {
    | UserMsg(Message.User({id, content, annotations, _})) =>
      // Use stable message ID for key
      // frontman-content-auto: browser skips layout/paint for off-screen messages
      let messageId = `user-${id}`
      <div key={messageId} className="frontman-content-auto">
        <UserMessage content annotations messageId isNew={isLastItem} />
      </div>

    | AssistantMsg(Message.Assistant(Streaming({id, textBuffer, _}))) =>
      // Use stable message ID for key
      let messageId = `assistant-${id}`
      <div key={messageId} className="frontman-content-auto">
        <AssistantMessage
          variant=AssistantMessage.Streaming content={textBuffer} messageId isNew={isLastItem}
        />
      </div>

    | AssistantMsg(Message.Assistant(Completed({id, content, _}))) =>
      // Use stable message ID for key
      let messageId = `assistant-${id}`
      <div key={messageId} className="frontman-content-auto">
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
      </div>

    | SingleToolCall(tc) =>
      // Use stable tool call ID for key
      let messageId = `tool-${tc.id}`
      <div key={messageId} className="frontman-content-auto">
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
      </div>

    | ToolGroup(group) =>
      // group.id is now stable (based on first tool call's ID)
      // Pass both isLastToolGroup and isLastItem - group is "open" only if both are true
      // This ensures groups close when items (like assistant messages) appear after them
      <div key={group.id} className="frontman-content-auto">
        <ToolGroupBlock group messageId={group.id} isLastToolGroup isLastItem isAgentRunning />
      </div>

    | TodoToolCall(tc) =>
      // Use stable tool call ID for key
      let messageId = `todo-${tc.id}`
      let todos = TodoUtils.extractTodos(~input=tc.input, ~result=tc.result)
      let isLoading = switch tc.state {
      | InputStreaming | InputAvailable => true
      | OutputAvailable | OutputError => false
      }

      <div key={messageId} className="frontman-content-auto">
        <TodoListBlock todos isLoading messageId />
      </div>

    | ErrorMsg(Message.Error(err)) =>
      <div key={`error-${Message.ErrorMessage.id(err)}`} className="frontman-content-auto">
        <ErrorBanner
          error={Message.ErrorMessage.error(err)}
          category={Message.ErrorMessage.category(err)}
          onRetry={switch currentTaskId {
          | Some(taskId) =>
            () =>
              Client__State.Actions.retryTurn(~taskId, ~retriedErrorId=Message.ErrorMessage.id(err))
          | None => () => ()
          }}
        />
      </div>

    // Handle any unexpected message types
    | UserMsg(_) | AssistantMsg(_) | ErrorMsg(_) => React.null
    }
  }

  <div className="relative flex flex-col h-full bg-[#130d20] text-zinc-200">
    <Client__UpdateBanner />
    <ScrollContainer className="flex-grow overflow-x-hidden">
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

        // Error banner (shows when there's a turn error, or retry banner during countdown)
        {switch (retryStatus, turnError, currentTaskId) {
        | (Some(rs), _, _) => <Client__RetryBanner retryStatus=rs />
        | (None, Some({message, category}), Some(taskId)) =>
          <ErrorBanner
            error=message
            category
            onRetry={() =>
              Client__State.Actions.retryTurn(
                ~taskId,
                ~retriedErrorId=lastErrorId->Option.getOr(""),
              )}
          />
        | _ => React.null
        }}

        // Thinking indicator (shows after last message when waiting for response)
        <ThinkingIndicator
          show={thinkingState.showThinking}
          context=?{thinkingState.thinkingContext}
          messageId={thinkingMessageId}
        />
      </ScrollContainer.ContentWrapper>
    </ScrollContainer>
    <Client__PlanList entries=planEntries />
    {switch (usageInfo, hasAnyKey) {
    | (Some({limit: Some(limit), remaining: Some(remaining), hasServerKey: Some(true)}), false) =>
      <div className="px-4 pb-1 text-xs text-zinc-400 shrink-0">
        {React.string(
          `Free requests remaining: ${remaining->Int.toString} / ${limit->Int.toString}. Add your API key in Settings to remove limits.`,
        )}
      </div>
    | _ => React.null
    }}
    <div className="border-t border-white/8 shrink-0">
      <Client__SelectedElementDisplay />
      {switch hasPendingQuestion {
      | true => <Client__QuestionDrawer />
      | false =>
        <PromptInput
          onSubmit={handleSubmit}
          onCancel={Client__State.Actions.cancelTurn}
          modelConfigOption
          isModelsConfigLoading
          selectedModelValue
          onModelChange={value => Client__State.Actions.setSelectedModelValue(~value)}
          isAgentRunning
          hasActiveACPSession
          disabled={isUsageExhausted}
          disabledPlaceholder="Free requests exhausted. Add your API key in Settings to continue."
          onSelectElement={Client__State.Actions.toggleWebPreviewSelection}
          isSelecting={webPreviewIsSelecting}
          hasAnnotations
          isEnrichingAnnotations={hasEnrichingAnnotations}
        />
      }}
    </div>
  </div>
}
