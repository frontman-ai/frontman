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

module Message = Client__State__Types.Message

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

type displayItem =
  | UserMsg({
      id: string,
      content: array<Client__State__Types.UserContentPart.t>,
      annotations: array<Message.MessageAnnotation.t>,
      agentId: string,
    })
  | AssistantMsg(Message.assistantMessage)
  | SingleToolCall(Message.toolCall)
  | ToolGroup(ToolGroupTypes.toolGroup)
  | TodoToolCall(Message.toolCall)
  | ErrorMsg(Message.ErrorMessage.t)

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

  let flushToolCalls = () => {
    let pending = pendingToolCalls.contents
    if Array.length(pending) > 0 {
      let grouped = ToolGroupUtils.groupToolCalls(pending, ~minGroupSize=1)

      grouped->Array.forEach(item => {
        switch item {
        | ToolGroupTypes.SingleTool(tc) =>
          switch TodoUtils.isTodoTool(tc.toolName) {
          | true => result->Array.push(TodoToolCall(tc))
          | false => result->Array.push(SingleToolCall(tc))
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
    | Message.User({id, content, annotations, agentId}) =>
      flushToolCalls()
      result->Array.push(UserMsg({id, content, annotations, agentId}))
    | Message.Assistant(message) =>
      flushToolCalls()
      result->Array.push(AssistantMsg(message))
    | Message.Error(err) =>
      flushToolCalls()
      result->Array.push(ErrorMsg(err))
    }
  })

  flushToolCalls()

  result
}

let shouldRenderTurnError = (messages: array<Message.t>, turnErrorId: string): bool =>
  !(
    messages->Array.some(message =>
      switch message {
      | Message.Error(error) => Message.ErrorMessage.id(error) == turnErrorId
      | _ => false
      }
    )
  )

let selectGetStartedTask = (~providerSetupRequired, ~onConfigureProvider, ~onSelect, text) => {
  switch providerSetupRequired {
  | true => onConfigureProvider()
  | false => onSelect(text)
  }
}

module ExecutePlanAction = {
  @react.component
  let make = (~pendingPlanHandoff, ~selectedModelValue, ~onExecute) => {
    switch (pendingPlanHandoff, selectedModelValue) {
    | (Some(_), Some(_)) => <Client__ExecutePlanBanner onExecute />
    | _ => React.null
    }
  }
}

@react.component
let make = (~onConfigureProvider: unit => unit) => {
  let {session, createSession} = Client__FrontmanProvider.useFrontman()

  let messages = Client__State.useSelector(Client__State.Selectors.messages)
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)
  let hasActiveACPSession = Client__State.useSelector(Client__State.Selectors.hasActiveACPSession)
  let planEntries = Client__State.useSelector(Client__State.Selectors.currentPlanEntries)
  let queuedUserMessages = Client__State.useSelector(Client__State.Selectors.queuedUserMessages)
  let turnError = Client__State.useSelector(Client__State.Selectors.turnError)
  let currentTaskId = Client__State.useSelector(Client__State.Selectors.currentTaskId)
  let retryStatus = Client__State.useSelector(Client__State.Selectors.retryStatus)
  let configOptions = Client__State.useSelector(Client__State.Selectors.configOptions)
  let agentCatalog = Client__State.useSelector(Client__State.Selectors.agentCatalog)
  let selectedAgentId = Client__State.useSelector(Client__State.Selectors.selectedAgentId)
  let selectedModelValue = Client__State.useSelector(Client__State.Selectors.selectedModelValue)
  let providerSetupRequired = Client__State.useSelector(
    Client__State.Selectors.providerSetupRequired,
  )
  let webPreviewIsSelecting = Client__State.useSelector(
    Client__State.Selectors.webPreviewIsSelecting,
  )
  let annotations = Client__State.useSelector(Client__State.Selectors.annotations)
  let hasEnrichingAnnotations = Client__State.useSelector(
    Client__State.Selectors.hasEnrichingAnnotations,
  )
  let modelConfigOption =
    configOptions->Option.flatMap(opts =>
      FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.findConfigOptionByCategory(opts, Model)
    )
  let isModelsConfigLoading = configOptions->Option.isNone
  let agentForId = agentId => Client__Agent.findOrThrow(agentCatalog, agentId)

  let (thinkingState, thinkingMessageId) = UseThinkingState.useWithMessageId(
    ~messages,
    ~isAgentRunning,
    ~hasActiveACPSession,
  )

  let hasPendingQuestion =
    Client__State.useSelector(Client__State.Selectors.pendingQuestion)->Option.isSome
  let hasAnnotations = Array.length(annotations) > 0

  let sendUserMessage = (
    ~content: array<Client__State.UserContentPart.t>,
    ~annotations: array<Client__Message.MessageAnnotation.t>,
    ~agentId: string,
  ) => {
    let sendMessage = (sessionId: string) => {
      Client__State.Actions.addUserMessage(~sessionId, ~content, ~annotations, ~agentId)
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

  let pendingPlanHandoff = Client__State.useSelector(Client__State.Selectors.pendingPlanHandoff)

  let handleSubmit = (~text: string, ~inputItems: array<Client__PromptInput.inputItem>) => {
    let agentId = selectedAgentId->Option.getOrThrow(~message="Selected agent is required")
    let messageAnnotations =
      annotations->Array.map(Client__Message.MessageAnnotation.fromAnnotation)

    let sendWithContent = content => {
      switch Array.length(content) > 0 || Array.length(messageAnnotations) > 0 {
      | false => ()
      | true => sendUserMessage(~content, ~annotations=messageAnnotations, ~agentId)
      }
    }

    let textParts = switch text != "" {
    | true => [Client__State.UserContentPart.Text({text: text})]
    | false => []
    }

    switch Array.length(inputItems) {
    | 0 => sendWithContent(textParts)
    | _ =>
      let _ =
        inputItems
        ->Array.map(item => {
          switch item {
          | Client__PromptInput.FileAttachment({id, name, mediaType, dataUrl}) =>
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
          }
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

  let lastToolGroupIndex = displayItems->Array.reduceWithIndex(-1, (acc, item, idx) => {
    switch item {
    | ToolGroup(_) => idx
    | _ => acc
    }
  })

  let renderDisplayItem = (item: displayItem, itemIndex: int) => {
    let isLastItem = itemIndex == totalItems - 1
    let isLastToolGroup = itemIndex == lastToolGroupIndex

    switch item {
    | UserMsg({id, content, annotations, agentId}) =>
      let messageId = `user-${id}`
      <UserMessage
        key={messageId} content annotations messageId agent={agentForId(agentId)} isNew={isLastItem}
      />

    | AssistantMsg(Streaming({id, textBuffer, agentId, _})) =>
      let messageId = `assistant-${id}`
      <div key={messageId} className="frontman-content-auto">
        <AssistantMessage
          variant=AssistantMessage.Streaming
          content={textBuffer}
          agent={agentForId(agentId)}
          isNew={isLastItem}
        />
      </div>

    | AssistantMsg(Completed({id, content, agentId, _})) =>
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
              agent={agentForId(agentId)}
              isNew={isLastItem && i == 0}
            />

          | Client__State__Types.AssistantContentPart.ToolCall({toolCallId: _, toolName, input}) =>
            <ToolCallBlock
              key={partKey}
              toolName
              state=Message.OutputAvailable
              input={Some(input)}
              inputBuffer=""
              result=None
              errorText=None
              defaultExpanded=false
            />
          }
        })
        ->React.array}
      </div>

    | SingleToolCall(tc) =>
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
        />
      </div>

    | ToolGroup(group) =>
      <div key={group.id} className="frontman-content-auto">
        <ToolGroupBlock group isLastToolGroup isLastItem isAgentRunning />
      </div>

    | TodoToolCall(tc) =>
      let messageId = `todo-${tc.id}`
      let isLoading = tc.state == InputStreaming || tc.state == InputAvailable
      let todos = switch tc.state {
      | OutputAvailable =>
        tc.result
        ->Option.flatMap(result => result.rawOutput)
        ->Option.getOrThrow(~message="Completed todo tool is missing rawOutput")
        ->TodoUtils.extractResult
      | InputStreaming | InputAvailable | OutputError =>
        tc.input->Option.mapOr([], TodoUtils.extractInput)
      }

      <div key={messageId} className="frontman-content-auto">
        <TodoListBlock todos isLoading messageId />
      </div>

    | ErrorMsg(err) =>
      <div key={`error-${Message.ErrorMessage.id(err)}`} className="frontman-content-auto">
        <ErrorBanner
          error={Message.ErrorMessage.error(err)}
          category={Message.ErrorMessage.category(err)}
          onConfigureProvider
          onRetry={switch currentTaskId {
          | Some(taskId) =>
            () =>
              Client__State.Actions.retryTurn(~taskId, ~retriedErrorId=Message.ErrorMessage.id(err))
          | None => () => ()
          }}
        />
      </div>
    }
  }

  <div className="relative flex flex-col h-full bg-[#130d20] text-zinc-200">
    <Client__UpdateBanner />
    <ScrollContainer className="flex-grow overflow-x-hidden">
      <ScrollContainer.ContentWrapper>
        {switch hasActiveACPSession {
        | true => React.null
        | false =>
          <div className="flex items-center gap-2 py-3 px-4 text-[13px] text-zinc-400">
            <span className="shimmer-text"> {React.string("Loading project context...")} </span>
          </div>
        }}

        {switch (hasActiveACPSession, totalItems) {
        | (true, 0) =>
          <Client__GetStartedTasks
            onSelect={text =>
              selectGetStartedTask(
                ~providerSetupRequired,
                ~onConfigureProvider,
                ~onSelect=text => handleSubmit(~text, ~inputItems=[]),
                text,
              )}
          />
        | _ => React.null
        }}

        {displayItems
        ->Array.mapWithIndex((item, index) => renderDisplayItem(item, index))
        ->React.array}

        <ExecutePlanAction
          pendingPlanHandoff selectedModelValue onExecute={Client__State.Actions.executePendingPlan}
        />

        {switch (retryStatus, turnError, currentTaskId) {
        | (Some(rs), _, _) => <Client__RetryBanner retryStatus=rs />
        | (None, Some({id, message, category, retryErrorId}), Some(taskId))
          if shouldRenderTurnError(messages, id) =>
          let onRetry =
            retryErrorId->Option.map(retriedErrorId =>
              () => Client__State.Actions.retryTurn(~taskId, ~retriedErrorId)
            )
          <ErrorBanner error=message category onConfigureProvider onRetry=?onRetry />
        | _ => React.null
        }}

        <ThinkingIndicator
          show={thinkingState.showThinking}
          context=?{thinkingState.thinkingContext}
          messageId={thinkingMessageId}
        />
      </ScrollContainer.ContentWrapper>
    </ScrollContainer>
    <Client__PlanList entries=planEntries />
    <Client__QueuedMessagesDrawer messages=queuedUserMessages />
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
          agentCatalog
          selectedAgentId
          onAgentChange={agentId => Client__State.Actions.setSelectedAgentId(~agentId)}
          onConfigureProvider
          isAgentRunning
          hasActiveACPSession
          onSelectElement={Client__State.Actions.toggleWebPreviewSelection}
          isSelecting={webPreviewIsSelecting}
          hasAnnotations
          isEnrichingAnnotations={hasEnrichingAnnotations}
        />
      }}
    </div>
  </div>
}
