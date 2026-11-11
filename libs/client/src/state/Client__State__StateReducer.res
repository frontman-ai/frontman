let name = "Client::StateReducer"

include Client__State__Protocol

module Task = Client__State__Types.Task
module Lens = Client__State__TaskUpdates.Lens
let addUserMessageToState = Client__State__TaskUpdates.addUserMessageToState

let getInitialUrl = Client__BrowserUrl.getInitialUrl

let updateApiKeySettings = (state: state, provider, update) =>
  switch provider {
  | OpenRouter => {...state, openrouterKeySettings: update(state.openrouterKeySettings)}
  | Anthropic => {...state, anthropicKeySettings: update(state.anthropicKeySettings)}
  | Fireworks => {...state, fireworksKeySettings: update(state.fireworksKeySettings)}
  | Nvidia => {...state, nvidiaKeySettings: update(state.nvidiaKeySettings)}
  }

let setApiKeySource = (state, provider, source) =>
  updateApiKeySettings(state, provider, settings => {...settings, source})

let setApiKeySaveStatus = (state, provider, saveStatus) =>
  updateApiKeySettings(state, provider, settings => {...settings, saveStatus})

let markApiKeySaved = (state, provider) =>
  updateApiKeySettings(state, provider, _settings => {source: UserOverride, saveStatus: Saved})

let setAllApiKeySources = (state: state, source) => {
  ...state,
  openrouterKeySettings: {...state.openrouterKeySettings, source},
  anthropicKeySettings: {...state.anthropicKeySettings, source},
  fireworksKeySettings: {...state.fireworksKeySettings, source},
  nvidiaKeySettings: {...state.nvidiaKeySettings, source},
}

module Selectors = Client__State__Selectors

let validateSubmission = Client__State__Prompt.validateSubmission
let updateInfoForVersions = Client__State__UpdateInfo.updateInfoForVersions

let upsertCustomProvider = (
  existing: option<array<Client__State__Types.customProvider>>,
  provider: Client__State__Types.customProvider,
): array<Client__State__Types.customProvider> => {
  let providers = existing->Option.getOr([])
  switch providers->Array.findIndexOpt(existing => existing.id == provider.id) {
  | Some(idx) =>
    let merged = providers->Array.copy
    merged[idx] = provider
    merged
  | None => Array.concat(providers, [provider])
  }
}

let selectModel = (state: state, value: option<string>): (state, array<effect>) => (
  {...state, selectedModelValue: value},
  [PersistSelectedModel(value)],
)

let applyCustomProvider = (state: state, provider: Client__State__Types.customProvider): (
  state,
  array<effect>,
) => {
  let state = {
    ...state,
    customProviders: Some(upsertCustomProvider(state.customProviders, provider)),
  }
  switch state.selectedModelValue {
  | Some(value) if value->String.startsWith(`custom:${provider.id}:`) =>
    switch provider.models->Array.some(model => value == `custom:${provider.id}:${model}`) {
    | true => (state, [])
    | false => selectModel(state, None)
    }
  | _ => (state, [])
  }
}

let startCustomProviderMutation = (state: state, request) => {
  let operation = customProviderMutationOperation(request)
  switch state.customProviderMutation {
  | CustomProviderMutationIdle =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        customProviderMutation: CustomProviderMutationPending(operation),
      }->StateReducer.update(~sideEffects=[CustomProviderMutationEffect({apiBaseUrl, request})])
    | None =>
      {
        ...state,
        customProviderMutation: CustomProviderMutationFailed({
          operation,
          error: CustomProviderNetworkError(embeddedAuthRequiredError),
        }),
      }->StateReducer.update
    }
  | _ => state->StateReducer.update
  }
}

let clearPendingQuestions = (state: state) => {
  let updatedTasks = state.tasks->Dict.copy
  updatedTasks->Dict.forEachWithKey((task, taskId) => {
    updatedTasks->Dict.set(
      taskId,
      Task.updateConversation(task, data => {...data, pendingQuestion: None}),
    )
  })
  {...state, tasks: updatedTasks}
}

let clearConnectionState = (state: state) => {
  {
    ...clearPendingQuestions(state),
    wordPressConnectionStatus: WordPressNotChecked,
    wordPressConnectionRequestId: state.wordPressConnectionRequestId + 1,
    billingStatus: Client__Billing.NotLoaded,
    billingFlow: Client__Billing.Idle,
    billingAbortController: None,
    billingStatusAbortController: None,
    settingsModalTab: None,
  }->StateReducer.update(
    ~sideEffects=[
      AbortBillingRequest(state.billingAbortController),
      AbortBillingRequest(state.billingStatusAbortController),
    ],
  )
}

let rec next = (state: state, action) => {
  switch action {
  | WordPressAuthenticationRequired(loginUrl) =>
    switch state.wordPressLoginRecovery {
    | Some(_) => state->StateReducer.update
    | None => {...state, wordPressLoginRecovery: Some({loginUrl: loginUrl})}->StateReducer.update
    }
  | ReloadAfterWordPressLogin => state->StateReducer.update(~sideEffects=[ReloadFrontman])
  | InitializeConnection(config) =>
    next(
      {...state, connection: Some(Connection.initialState(config))},
      ConnectionAction(Initialize),
    )
  | ConnectionEvent({signal, action}) =>
    switch state.connection {
    | Some(connection) if Connection.isCurrentConnection(connection, signal) => next(state, action)
    | _ => state->StateReducer.update
    }
  | SessionEvent({requestId, action}) =>
    switch state.connection {
    | Some(connection) if Connection.isCurrentSessionRequest(connection, requestId) =>
      next(state, action)
    | _ => state->StateReducer.update
    }
  | ConnectionAction(LoadTask({taskId})) if state.connection->Option.isNone =>
    next(state, TaskLoadFinished({taskId, result: Error("No active ACP session")}))
  | ConnectionAction(action) =>
    let state = switch action {
    | ClearSession => clearPendingQuestions(state)
    | _ => state
    }
    let (updated, effects) = switch state.connection {
    | None => (state, [])
    | Some(previous) =>
      let (connection, effects) = Connection.next(previous, action)
      let updated = {...state, connection: Some(connection)}
      let (updated, configEffects) = switch action {
      | SessionResultReceived({result: Ok((_, Some(configOptions)))}) if connection !== previous =>
        next(updated, ConfigOptionsReceived({configOptions: configOptions}))
      | _ => (updated, [])
      }
      (updated, Array.concat(configEffects, effects->Array.map(effect => ConnectionEffect(effect))))
    }
    switch (
      action,
      Selectors.hasActiveACPSession(state) && !Selectors.hasActiveACPSession(updated),
    ) {
    | (Dispose, _) | (_, true) =>
      let (updated, cleanupEffects) = clearConnectionState(updated)
      updated->StateReducer.update(~sideEffects=Array.concat(effects, cleanupEffects))
    | _ => updated->StateReducer.update(~sideEffects=effects)
    }
  | TaskAction({
    action:
      SetAnnotationMode(_)
      | ToggleAnnotationMode
      | ToggleAnnotation(_)
      | AddAnnotation(_)
      | AddAnnotations(_)
      | RemoveAnnotation(_)
      | ClearAnnotations
      | SetActivePopupAnnotationId(_)
      | UpdateAnnotationComment(_),
  })
  | SetSelectedAgentId(_)
  | SetSelectedModelValue(_)
  | ExecutePendingPlan(_) if Selectors.isSubmitting(state) =>
    state->StateReducer.update
  | AcpSessionUpdateReceived({taskId, update, errorDisplayId}) =>
    let task = action => TaskAction({target: ForTask(taskId), action})
    let flush = actions => state->StateReducer.update(~sideEffect=FlushSessionActions(actions))
    switch update {
    | AgentMessageChunk({messageId, content: TextContent({text}), _meta: {agentId}}) =>
      state->StateReducer.update(
        ~sideEffect=BufferAssistantText({taskId, messageId, text, agentId}),
      )
    | UserMessageChunk({messageId, content, _meta: {agentId}}) =>
      state->StateReducer.update(
        ~sideEffect=BufferUserBlock({taskId, messageId, block: content, agentId}),
      )
    | GenericAgentMessageChunk(_) | GenericUserMessageChunk(_) =>
      failwith("Frontman UI requires negotiated agent attribution")
    | AgentMessageChunk(_) | Unknown(_) => state->StateReducer.update
    | MessageUnqueued({messageId}) =>
      flush([task(TaskReducer.MessageUnqueued({messageId: messageId}))])
    | ToolCall({
        toolCallId,
        title,
        status,
        content,
        rawInput,
        rawOutput,
        parentAgentId,
        spawningToolName,
      }) =>
      let toolCall = Client__ACP__MessageCodec.makeToolCall(
        ~id=toolCallId,
        ~title,
        ~status,
        ~content,
        ~rawInput,
        ~rawOutput,
        ~parentAgentId,
        ~spawningToolName,
      )
      flush([task(ToolCallReceived({toolCall: toolCall}))])
    | ToolCallUpdate({toolCallId, status, content, rawInput, rawOutput}) =>
      let input = rawInput->Option.map(input => task(ToolInputReceived({id: toolCallId, input})))
      let result = switch (rawOutput, content, status) {
      | (None, None, None | Some(Pending | InProgress | Failed)) => None
      | _ =>
        Some(
          task(
            ToolResultReceived({
              id: toolCallId,
              rawOutput,
              content,
              complete: status == Some(Completed),
            }),
          ),
        )
      }
      let error = switch status {
      | Some(Failed) =>
        let error =
          content
          ->Option.flatMap(items =>
            items->Array.findMap(item =>
              switch item {
              | Content({content: TextContent({text})}) => Some(text)
              | _ => None
              }
            )
          )
          ->Option.getOr("Unknown error")
        Some(task(ToolErrorReceived({id: toolCallId, error})))
      | Some(Pending | Completed | InProgress) | None => None
      }
      flush([input, result, error]->Array.filterMap(value => value))
    | Plan({entries}) => flush([task(PlanReceived({entries: entries}))])
    | SessionInfoUpdate({_meta}) =>
      let ids = _meta->Option.flatMap(meta => meta->Dict.get("frontman.dev/turnMessageIds"))
      switch ids {
      | Some(ids) =>
        let ids = ids->S.parseOrThrow(~to=S.array(S.string->S.min(1)))
        flush([task(TaskReducer.ExecutionStateRunning(ids))])
      | None => flush([])
      }
    | StateUpdate({state: executionState}) =>
      let action = switch executionState {
      | Running => TaskReducer.ExecutionStateRunning([])
      | Idle => TaskReducer.ExecutionStateIdle
      | RequiresAction => TaskReducer.ExecutionStateRequiresAction
      }
      flush([task(action)])
    | ConfigOptionUpdate({configOptions}) =>
      flush([ConfigOptionsReceived({configOptions: configOptions})])
    | CurrentModeUpdate(_) => flush([])
    | Error({_meta, message, retryAt, attempt, maxAttempts, category}) =>
      let settings = switch category {
      | Some("billing") => [SetSettingsModalTab({tab: Some(Providers)})]
      | Some("frontman_billing") => [SetSettingsModalTab({tab: Some(Billing)})]
      | Some(_) | None => []
      }
      let action = switch retryAt {
      | Some(retryAt) =>
        TaskReducer.RetryingUpdate({
          retryStatus: {
            attempt: attempt->Option.getOr(1),
            maxAttempts: maxAttempts->Option.getOr(5),
            retryAt: Date.fromString(retryAt)->Date.getTime,
            error: message,
          },
        })
      | None =>
        TaskReducer.AgentError({
          id: errorDisplayId->Option.getOrThrow,
          retryErrorId: Client__ACP__MessageCodec.agentErrorId(_meta),
          error: message,
          category: Client__ErrorCategory.fromAcpCategory(category),
        })
      }
      flush([...settings, task(action)])
    }
  | PreviewAction({clientId, navigationKey, action}) =>
    let frame = Selectors.previewFrame(state)
    switch clientId == Selectors.currentTaskClientId(state) &&
      navigationKey == frame.navigationKey {
    | true => state->Lens.delegateToTask(CurrentTask, action)
    | false => StateReducer.update(state)
    }
  | TaskAction({target, action: QuestionReceived({resolveError}) as taskAction}) =>
    let taskId = switch target {
    | ForTask(taskId) => Some(taskId)
    | CurrentTask => Selectors.currentTaskId(state)
    }
    let canRegister = switch (taskId, state.connection) {
    | (Some(taskId), Some(connection)) =>
      Connection.Selectors.sessionTaskId(connection) == Some(taskId) &&
      Connection.Selectors.sessionRequestId(connection)->Option.mapOr(false, requestId =>
        Connection.isCurrentSessionRequest(connection, requestId)
      ) &&
      state.tasks
      ->Dict.get(taskId)
      ->Option.mapOr(false, task => Task.isLoaded(task) || Task.isLoading(task))
    | _ => false
    }
    switch canRegister {
    | true => state->Lens.delegateToTask(target, taskAction)
    | false =>
      state->StateReducer.update(
        ~sideEffect=TaskEffect({
          target,
          effect: RejectQuestionToolEffect({
            resolveError,
            message: "Question session is no longer active",
          }),
        }),
      )
    }
  | TaskAction({target: ForTask(taskId), action: QuestionDetached(_)})
    if !(state.tasks->Dict.has(taskId)) =>
    state->StateReducer.update
  | TaskAction({target, action: taskAction}) => state->Lens.delegateToTask(target, taskAction)

  | PromptFailed({requestId, taskId, id, error}) =>
    let failed = (state, error) =>
      state->Lens.delegateToTask(ForTask(taskId), UserMessageSendFailed({id, error}))
    switch state.connection {
    | Some(connection) if Connection.isCurrentSessionRequest(connection, requestId) =>
      let state = switch Connection.ACP.requestErrorIsBillingInactive(error) {
      | true => {...state, settingsModalTab: Some(Billing)}
      | false => state
      }
      failed(state, Connection.ACP.requestErrorMessage(error))
    | _ => state->StateReducer.update
    }
  | AddUserMessage({onComplete}) if Client__Billing.turnStartBlocked(state.billingStatus) =>
    {...state, settingsModalTab: Some(Billing)}->StateReducer.update(
      ~sideEffect=SubmissionCompleted({
        onComplete,
        result: Error("Start a Frontman trial to continue."),
      }),
    )
  | ExecutePendingPlan(_) if Client__Billing.turnStartBlocked(state.billingStatus) =>
    {...state, settingsModalTab: Some(Billing)}->StateReducer.update
  | AddUserMessage({id, timestamp, content, annotationId, onComplete} as input) =>
    let reject = error =>
      state->StateReducer.update(
        ~sideEffect=SubmissionCompleted({onComplete, result: Error(error)}),
      )
    switch (Selectors.isSubmitting(state), state.selectedAgentId) {
    | (false, Some(agentId)) if !Selectors.hasEnrichingAnnotations(state) =>
      let annotations = Selectors.annotations(state)
      let annotations = switch annotationId {
      | None => annotations
      | Some(id) => [annotations->Array.find(annotation => annotation.id == id)->Option.getOrThrow]
      }
      let submission: Client__State__Types.submission = {
        id,
        timestamp,
        content,
        annotations: annotations->Array.map(Message.MessageAnnotation.fromAnnotation),
        agentId,
        onComplete,
      }
      switch validateSubmission(state, submission) {
      | Error(error) => reject(error)
      | Ok() =>
        let taskId =
          Selectors.currentTaskId(state)->Option.getOr(Selectors.currentTaskClientId(state))
        switch (Selectors.getSession(state), Selectors.currentTaskId(state)) {
        | (Some({sessionId}), _) if sessionId == taskId =>
          addUserMessageToState(state, ~sessionId, submission)
        | (_, None) if Selectors.hasActiveACPSession(state) =>
          state->StateReducer.update(~sideEffect=CreateSession({taskId, input}))
        | (_, Some(taskId)) =>
          let (state, effects) = next(state, SwitchTask({taskId: taskId}))
          state->StateReducer.update(
            ~sideEffects=Array.concat(
              effects,
              [
                SubmissionCompleted({
                  onComplete,
                  result: Error("Loading this conversation. Send again when it is ready."),
                }),
              ],
            ),
          )
        | _ => reject("Cannot send message: no active connection")
        }
      }
    | _ => reject("The composer is not ready to send.")
    }

  | CancelTurn =>
    switch state.currentTask {
    | Task.Selected(taskId) => state->Lens.delegateToTask(ForTask(taskId), TaskReducer.CancelTurn)
    | Task.New(_) => state->StateReducer.update
    }

  | ExecutePendingPlan({id, timestamp}) =>
    switch (state.selectedModelValue, Selectors.pendingPlanHandoff(state)) {
    | (Some(_), Some({taskId, executorAgentId})) =>
      addUserMessageToState(
        {...state, selectedAgentId: Some(executorAgentId)},
        ~sessionId=taskId,
        {
          id,
          timestamp,
          content: [UserContentPart.Text({text: executePlanPrompt})],
          annotations: [],
          agentId: executorAgentId,
          onComplete: _ => (),
        },
      )
    | _ => state->StateReducer.update
    }

  | TaskLoadFinished({taskId, result: Ok(requestId)})
    if !(
      state.connection->Option.mapOr(false, connection =>
        Connection.isCurrentSessionRequest(connection, requestId)
      )
    ) =>
    next(
      state,
      TaskLoadFinished({taskId, result: Error("Conversation changed before loading completed")}),
    )
  | TaskLoadFinished({taskId, result: Error(_)})
    if state.connection->Option.mapOr(false, connection =>
      switch connection.connection {
      | Ok(Some({
        phase: Ready({session: SessionCreating({sessionId: Some(currentId), requestId})}),
      }))
      | Ok(Some({
        phase: Ready({session: SessionActive({session: {sessionId: currentId}, requestId})}),
      })) =>
        currentId == taskId && Connection.isCurrentSessionRequest(connection, requestId)
      | _ => false
      }
    ) =>
    state->StateReducer.update
  | TaskLoadFinished({taskId, result}) =>
    switch state.tasks->Dict.get(taskId) {
    | Some(Loading(_)) =>
      state->Lens.delegateToTask(
        ForTask(taskId),
        switch result {
        | Ok(_) => LoadComplete
        | Error(error) => LoadError({error: error})
        },
      )
    | _ => state->StateReducer.update
    }
  | SwitchTask({taskId})
    if Selectors.currentTaskId(state) == Some(taskId) &&
      state.connection->Option.mapOr(false, connection =>
        Connection.Selectors.sessionTaskId(connection) == Some(taskId) &&
          Connection.Selectors.sessionRequestId(connection)->Option.isSome
      ) =>
    state->StateReducer.update
  | SwitchTask({taskId}) => {
      let (state, connectionEffects) = next(state, ConnectionAction(ClearSession))
      let (updatedState, taskEffects) =
        state->Lens.delegateToTask(
          ForTask(taskId),
          TaskReducer.LoadStarted({previewUrl: getInitialUrl()}),
        )
      let (updatedState, loadEffects) = next(
        {
          ...updatedState,
          currentTask: Task.Selected(taskId),
          highlightedAnnotation: None,
        },
        ConnectionAction(LoadTask({taskId: taskId})),
      )
      updatedState->StateReducer.update(
        ~sideEffects=Array.concat(connectionEffects, loadEffects)->Array.concat(taskEffects),
      )
    }

  | DeleteTask({taskId, replacementClientId}) => {
      let (state, effects) = switch state.connection->Option.flatMap(
        Connection.Selectors.sessionTaskId,
      ) == Some(taskId) {
      | true => next(state, ConnectionAction(ClearSession))
      | false => (state, [])
      }
      let updatedTasks = state.tasks->Dict.copy
      updatedTasks->Dict.delete(taskId)

      let newCurrentTask = switch state.currentTask {
      | Task.Selected(currentId) if currentId == taskId =>
        let mostRecent =
          updatedTasks
          ->Dict.valuesToArray
          ->Array.toSorted((a, b) => {
            let aTime = Selectors.getTaskSortTime(a)
            let bTime = Selectors.getTaskSortTime(b)
            bTime -. aTime
          })
          ->Array.get(0)
        switch mostRecent {
        | Some(task) => Task.Selected(Task.getId(task)->Option.getOrThrow)
        | None => Task.New(Task.makeNew(~previewUrl=getInitialUrl(), ~clientId=replacementClientId))
        }
      | other => other
      }

      let (state, deleteEffects) = next(
        {
          ...state,
          tasks: updatedTasks,
          currentTask: newCurrentTask,
          highlightedAnnotation: None,
        },
        ConnectionAction(DeleteSession({taskId: taskId})),
      )
      state->StateReducer.update(~sideEffects=Array.concat(effects, deleteEffects))
    }

  | ClearCurrentTask({replacementClientId}) =>
    let (state, effects) = next(state, ConnectionAction(ClearSession))
    let previewUrl = Selectors.previewUrl(state)
    {
      ...state,
      currentTask: Task.New(Task.makeNew(~previewUrl, ~clientId=replacementClientId)),
      highlightedAnnotation: None,
    }->StateReducer.update(~sideEffects=effects)

  | UpdateTaskTitle({taskId, title}) =>
    switch state.tasks->Dict.get(taskId) {
    | Some(_) =>
      state
      ->Lens.updateTask(taskId, task => Task.setTitle(task, title))
      ->StateReducer.update
    | None => state->StateReducer.update
    }

  | SetSettingsModalTab({tab}) => {...state, settingsModalTab: tab}->StateReducer.update
  | RequestBilling(request) =>
    switch (Selectors.apiBaseUrl(state), request, state.billingFlow) {
    | (None, _, _) | (_, Checkout(_) | CustomerPortal, Opening | AwaitingCheckout) =>
      state->StateReducer.update
    | (Some(apiBaseUrl), _, _) =>
      let controller = switch state.billingAbortController {
      | Some(controller) => controller
      | None => WebAPI.AbortController.make()
      }
      let statusController = switch request {
      | Status => Some(WebAPI.AbortController.make())
      | _ => state.billingStatusAbortController
      }
      let signal = switch (request, statusController) {
      | (Status, Some(statusController)) =>
        WebAPI.AbortSignal.any([controller.signal, statusController.signal])
      | _ => controller.signal
      }
      let effects = switch request {
      | Status => [
          AbortBillingRequest(state.billingStatusAbortController),
          FetchBillingStatus({apiBaseUrl, signal}),
        ]
      | Checkout(_) | CustomerPortal => [OpenBillingTabAndFetchUrl({request, apiBaseUrl, signal})]
      }
      {
        ...state,
        billingAbortController: Some(controller),
        billingStatusAbortController: statusController,
        billingFlow: switch request {
        | Status => state.billingFlow
        | _ => Opening
        },
      }->StateReducer.update(~sideEffects=effects)
    }
  | BillingCheckoutDismissed =>
    next({...state, billingFlow: Client__Billing.Idle}, RequestBilling(Status))
  | BillingUrlReceived({tab, url, request}) =>
    {
      ...state,
      billingFlow: switch request {
      | Checkout(_) => Client__Billing.AwaitingCheckout
      | Status | CustomerPortal => Client__Billing.Idle
      },
    }->StateReducer.update(~sideEffects=[NavigateBillingTab({tab, url})])
  | BillingLaunchFailed({tab, error}) =>
    {...state, billingFlow: Client__Billing.Failed(error)}->StateReducer.update(
      ~sideEffects=[CloseBillingTab(tab)],
    )
  | BillingRequestCancelled({tab}) =>
    state->StateReducer.update(~sideEffects=[CloseBillingTab(tab)])
  | BillingAuthRequired({tab}) =>
    {...state, billingFlow: Client__Billing.Idle}->StateReducer.update(
      ~sideEffects=switch Selectors.apiBaseUrl(state) {
      | None => [CloseBillingTab(tab)]
      | Some(_) => [CloseBillingTab(tab), RequireBillingAuthentication]
      },
    )
  | BillingStatusReceived(status) =>
    {
      ...state,
      billingStatus: Client__Billing.Loaded(status),
      billingStatusAbortController: None,
      billingFlow: switch (state.billingFlow, Client__Billing.canStartCheckout(status)) {
      | (AwaitingCheckout, false) => Idle
      | _ => state.billingFlow
      },
    }->StateReducer.update(
      ~sideEffects=switch state.billingStatusAbortController {
      | None => []
      | Some(_) => [AbortBillingRequest(state.billingStatusAbortController)]
      },
    )
  | BillingStatusError({error}) =>
    {
      ...state,
      billingStatus: Client__Billing.Error(error),
      billingStatusAbortController: None,
    }->StateReducer.update(
      ~sideEffects=switch state.billingStatusAbortController {
      | None => []
      | Some(_) => [AbortBillingRequest(state.billingStatusAbortController)]
      },
    )

  | FetchUserProfile({apiBaseUrl}) =>
    state->StateReducer.update(~sideEffects=[FetchUserProfileEffect({apiBaseUrl: apiBaseUrl})])

  | UserProfileReceived({userProfile: {id, email, name}}) =>
    let userProfile: Client__State__Types.userProfile = {id, email, name}
    {...state, userProfile: Some(userProfile)}->StateReducer.update
  | FetchApiKeySettings =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state
      ->setAllApiKeySources(Client__State__Types.Loading)
      ->StateReducer.update(~sideEffects=[FetchApiKeySettingsEffect({apiBaseUrl: apiBaseUrl})])
    | None => state->StateReducer.update
    }
  | ConnectWordPress | FetchWordPressConnection | SetWordPressAccess(_) =>
    let operation = switch (action, state.wordPressConnectionStatus) {
    | (ConnectWordPress, WordPressUnlinked) =>
      Some((ApproveConnection, Client__State__Types.WordPressLinking))
    | (FetchWordPressConnection, _) =>
      Some((CheckConnection, Client__State__Types.WordPressChecking))
    | (SetWordPressAccess(enabled), WordPressLinked({enabled: current})) if current != enabled =>
      Some((
        UpdateAccess(enabled),
        Client__State__Types.WordPressUpdatingAccess({enabled: current}),
      ))
    | _ => None
    }
    switch (state.wordPressPendingMutation, Selectors.apiBaseUrl(state), operation) {
    | (None, Some(apiBaseUrl), Some((operation, status))) =>
      let requestId = state.wordPressConnectionRequestId + 1
      {
        ...state,
        wordPressConnectionStatus: status,
        wordPressConnectionRequestId: requestId,
        wordPressPendingMutation: operation == CheckConnection ? None : Some(requestId),
      }->StateReducer.update(
        ~sideEffects=[WordPressConnectionEffect({apiBaseUrl, requestId, operation})],
      )
    | _ => state->StateReducer.update
    }
  | WordPressConnectionCompletion({requestId, result, credentialRisk}) =>
    let current = requestId == state.wordPressConnectionRequestId
    let mutationFinished = state.wordPressPendingMutation == Some(requestId)
    let status: Client__State__Types.wordPressConnectionStatus = switch result {
    | Ok({connected, enabled}) =>
      connected ? WordPressLinked({enabled: enabled}) : WordPressUnlinked
    | Error(WordPressRequestFailed(message)) => WordPressConnectionFailed(message)
    | Error(WordPressAuthRequired) =>
      WordPressConnectionFailed("Your Frontman session expired. Sign in again.")
    }
    let state = {
      ...state,
      wordPressPendingMutation: mutationFinished ? None : state.wordPressPendingMutation,
      wordPressCredentialWarning: state.wordPressCredentialWarning ||
      (credentialRisk && (!current || result->Result.isError)),
    }
    switch (current, mutationFinished) {
    | (true, _) => {...state, wordPressConnectionStatus: status}->StateReducer.update
    | (false, true) =>
      next({...state, wordPressConnectionStatus: WordPressNotChecked}, FetchWordPressConnection)
    | (false, false) => state->StateReducer.update
    }

  | ApiKeySettingsReceived({provider, source}) =>
    state->setApiKeySource(provider, source)->StateReducer.update

  | SaveApiKey({provider, key}) =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        pendingProviderAutoSelect: Some(apiKeyProviderId(provider)),
      }->StateReducer.update(~sideEffects=[SaveApiKeyEffect({apiBaseUrl, provider, key})])
    | None =>
      state->setApiKeySaveStatus(provider, SaveError("No active ACP session"))->StateReducer.update
    }

  | ApiKeySaveStarted({provider}) =>
    state->setApiKeySaveStatus(provider, Saving)->StateReducer.update

  | ApiKeySaved({provider}) => state->markApiKeySaved(provider)->StateReducer.update

  | ApiKeySaveError({provider, error}) =>
    let state = state->setApiKeySaveStatus(provider, SaveError(error))
    {...state, pendingProviderAutoSelect: None}->StateReducer.update

  | ResetApiKeySaveStatus({provider}) =>
    state->setApiKeySaveStatus(provider, Idle)->StateReducer.update

  | ConfigOptionsReceived({configOptions}) =>
    let modelConfigOption =
      ACP.findConfigOptionByCategory(configOptions, ACP.Model)->Option.getOrThrow(
        ~message="ConfigOptionsReceived missing model config option",
      )

    let firstModelValue =
      modelConfigOption->ACP.sessionConfigOptionFirstOption->Option.map(option => option.value)

    let modelValueExists = value =>
      switch modelConfigOption {
      | ACP.SelectConfigOption({options: ACP.Grouped(groups)}) =>
        groups->Array.some(group => group.options->Array.some(option => option.value == value))
      | ACP.SelectConfigOption({options: ACP.Ungrouped(options)}) =>
        options->Array.some(option => option.value == value)
      }

    let currentOrFirstModelValue = switch state.selectedModelValue {
    | Some(value) if modelValueExists(value) => Some(value)
    | _ => firstModelValue
    }

    let selectedModelValue = switch state.pendingProviderAutoSelect {
    | Some(providerId) =>
      let providerModelValue = switch modelConfigOption {
      | ACP.SelectConfigOption({options: ACP.Grouped(groups)}) =>
        groups
        ->Array.find(g => g.group == providerId)
        ->Option.flatMap(g => g.options->Array.get(0))
        ->Option.map(opt => opt.value)
      | ACP.SelectConfigOption({options: ACP.Ungrouped(_)}) => None
      }
      switch providerModelValue {
      | Some(value) => Some(value)
      | None => currentOrFirstModelValue
      }
    | None => currentOrFirstModelValue
    }
    let (state, effects) = switch (state.selectedModelValue, selectedModelValue) {
    | (Some(current), Some(next)) if current == next => (state, [])
    | (None, None) => (state, [])
    | _ => selectModel(state, selectedModelValue)
    }
    {
      ...state,
      configOptions: Some(configOptions),
      selectedModelValue,
      pendingProviderAutoSelect: None,
    }->StateReducer.update(~sideEffects=effects)

  | SetSelectedModelValue({value}) =>
    let (state, effects) = selectModel(state, Some(value))
    state->StateReducer.update(~sideEffects=effects)

  | AgentAttributionConfigured({agentCatalog, defaultAgentId}) =>
    Client__Agent.findOrThrow(Some(agentCatalog), defaultAgentId)->ignore
    let selectedAgentId = switch state.selectedAgentId {
    | Some(agentId) if agentCatalog->Array.some(agent => agent.id == agentId) => Some(agentId)
    | _ => Some(defaultAgentId)
    }
    {...state, agentCatalog: Some(agentCatalog), selectedAgentId}->StateReducer.update

  | SetSelectedAgentId(agentId) =>
    Client__Agent.findOrThrow(state.agentCatalog, agentId)->ignore
    {...state, selectedAgentId: Some(agentId)}->StateReducer.update

  | FetchAnthropicOAuthStatus =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.FetchingStatus,
      }->StateReducer.update(
        ~sideEffects=[FetchAnthropicOAuthStatusEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
    }

  | AnthropicOAuthStatusReceived({connected, expiresAt}) =>
    let status = switch (connected, expiresAt) {
    | (true, Some(expiresAtStr)) =>
      let expiresAtMs = Date.fromString(expiresAtStr)->Date.getTime
      Client__State__Types.Connected({expiresAt: expiresAtMs})
    | (true, None) => failwith("Connected Anthropic OAuth status missing expires_at")
    | (false, _) => Client__State__Types.NotConnected
    }
    {...state, anthropicOAuthStatus: status}->StateReducer.update

  | InitiateAnthropicOAuth =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state->StateReducer.update(
        ~sideEffects=[GetAnthropicOAuthUrlEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
    }

  | AnthropicOAuthUrlReceived({authorizeUrl, verifier}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Authorizing({authorizeUrl, verifier}),
    }->StateReducer.update

  | ExchangeAnthropicOAuthCode({code, verifier}) =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.Exchanging,
        pendingProviderAutoSelect: Some("anthropic"),
      }->StateReducer.update(
        ~sideEffects=[
          ExchangeAnthropicOAuthCodeEffect({
            apiBaseUrl,
            code,
            verifier,
          }),
        ],
      )
    | None => state->StateReducer.update
    }

  | AnthropicOAuthConnected({expiresAt}) =>
    let expiresAtMs = Date.fromString(expiresAt)->Date.getTime
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Connected({expiresAt: expiresAtMs}),
    }->StateReducer.update

  | AnthropicOAuthError({error}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Error(error),
      pendingProviderAutoSelect: None,
    }->StateReducer.update

  | DisconnectAnthropicOAuth =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state->StateReducer.update(
        ~sideEffects=[DisconnectAnthropicOAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
    }

  | AnthropicOAuthDisconnected =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.NotConnected,
    }->StateReducer.update

  | ResetAnthropicOAuthError =>
    switch state.anthropicOAuthStatus {
    | Client__State__Types.Error(_) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.NotConnected,
      }->StateReducer.update
    | _ => state->StateReducer.update
    }

  | CancelAnthropicOAuth =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.NotConnected,
    }->StateReducer.update

  | FetchOpenAIOAuthStatus =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIFetchingStatus,
      }->StateReducer.update(~sideEffects=[FetchOpenAIOAuthStatusEffect({apiBaseUrl: apiBaseUrl})])
    | None => state->StateReducer.update
    }

  | OpenAIOAuthStatusReceived({connected, expiresAt}) =>
    let status = switch (connected, expiresAt) {
    | (true, Some(expiresAtStr)) =>
      let expiresAtMs = Date.fromString(expiresAtStr)->Date.getTime
      Client__State__Types.OpenAIConnected({expiresAt: expiresAtMs})
    | (true, None) => failwith("Connected OpenAI OAuth status missing expires_at")
    | (false, _) => Client__State__Types.OpenAINotConnected
    }
    {...state, openaiOAuthStatus: status}->StateReducer.update

  | InitiateOpenAIOAuth =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIWaitingForCode,
        pendingProviderAutoSelect: Some("openai_codex"),
      }->StateReducer.update(
        ~sideEffects=[InitiateOpenAIDeviceAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
    }

  | OpenAIDeviceCodeReceived({deviceAuthId, userCode, verificationUrl}) =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIShowingCode({
          deviceAuthId,
          userCode,
          verificationUrl,
        }),
      }->StateReducer.update(
        ~sideEffects=[
          PollOpenAIDeviceAuthEffect({
            apiBaseUrl,
            deviceAuthId,
            userCode,
          }),
        ],
      )
    | None =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIShowingCode({
          deviceAuthId,
          userCode,
          verificationUrl,
        }),
      }->StateReducer.update
    }

  | OpenAIOAuthConnected({deviceAuthId, expiresAt}) =>
    switch state.openaiOAuthStatus {
    | Client__State__Types.OpenAIShowingCode({deviceAuthId: currentId})
      if currentId == deviceAuthId =>
      let expiresAtMs = Date.fromString(expiresAt)->Date.getTime
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIConnected({expiresAt: expiresAtMs}),
      }->StateReducer.update
    | _ => state->StateReducer.update
    }

  | OpenAIOAuthError({deviceAuthId, error}) =>
    let isStale = switch deviceAuthId {
    | Some(id) =>
      switch state.openaiOAuthStatus {
      | Client__State__Types.OpenAIShowingCode({deviceAuthId: currentId}) => currentId != id
      | _ => true
      }
    | None => false
    }
    if isStale {
      state->StateReducer.update
    } else {
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIError(error),
        pendingProviderAutoSelect: None,
      }->StateReducer.update
    }

  | DisconnectOpenAIOAuth =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state->StateReducer.update(
        ~sideEffects=[DisconnectOpenAIOAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
    }

  | OpenAIOAuthDisconnected =>
    {
      ...state,
      openaiOAuthStatus: Client__State__Types.OpenAINotConnected,
    }->StateReducer.update

  | ResetOpenAIOAuthError =>
    switch state.openaiOAuthStatus {
    | Client__State__Types.OpenAIError(_) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAINotConnected,
      }->StateReducer.update
    | _ => state->StateReducer.update
    }

  | SessionsLoadStarted =>
    {
      ...state,
      sessionsLoadState: Client__State__Types.SessionsLoading,
    }->StateReducer.update

  | SessionsLoadSuccess({sessions}) =>
    let previewUrl = getInitialUrl()
    let updatedTasks = state.tasks->Dict.copy

    sessions->Array.forEach(session => {
      if !(updatedTasks->Dict.has(session.sessionId)) {
        let createdAt = Date.fromString(session.createdAt)->Date.getTime
        let updatedAt = Date.fromString(session.updatedAt)->Date.getTime

        let task = Task.makeWithId(
          ~id=session.sessionId,
          ~title=session.title,
          ~previewUrl,
          ~createdAt,
          ~updatedAt,
        )
        updatedTasks->Dict.set(session.sessionId, task)
      }
    })

    {
      ...state,
      tasks: updatedTasks,
      sessionsLoadState: Client__State__Types.SessionsLoaded,
    }->StateReducer.update

  | SessionsLoadError({error}) =>
    {
      ...state,
      sessionsLoadState: Client__State__Types.SessionsLoadError(error),
    }->StateReducer.update(~sideEffect=ConnectionEffect(LogError(error)))

  | CheckForUpdate({apiBaseUrl, installedVersion, target}) =>
    switch (target, state.wordpressUpdates) {
    | (WordPressPlugin, Unsupported) => state->StateReducer.update
    | _ =>
      state->StateReducer.update(
        ~sideEffects=[CheckForUpdateEffect({apiBaseUrl, installedVersion, target})],
      )
    }

  | WordPressUpdatesChecked(None) =>
    {...state, wordpressUpdates: Unsupported, updateInfo: None}->StateReducer.update

  | WordPressUpdatesChecked(Some(response)) =>
    {
      ...state,
      wordpressUpdates: Client__WordPressUpdates.Available({
        autoUpdateEnabled: response.autoUpdateEnabled,
      }),
      updateInfo: updateInfoForVersions(
        ~target=WordPressPlugin,
        ~installedVersion=response.installedVersion,
        ~latestVersion=response.latestVersion,
      ),
    }->StateReducer.update

  | UpdateInfoChecked(updateInfo) => {...state, updateInfo}->StateReducer.update

  | DismissUpdateBanner => {...state, updateBannerDismissed: true}->StateReducer.update

  | HighlightAnnotation({annotationId, selector}) =>
    let taskId = Selectors.currentTaskClientId(state)
    let highlighted = switch state.highlightedAnnotation {
    | Some(current) if current.taskId == taskId && current.annotationId == annotationId => None
    | Some(_) | None => Some({Client__State__Types.taskId, annotationId, selector})
    }
    {...state, highlightedAnnotation: highlighted}->StateReducer.update

  | FetchCustomProviders =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state->StateReducer.update(
        ~sideEffects=[FetchCustomProvidersEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
    }

  | CustomProvidersReceived({providers}) =>
    {...state, customProviders: Some(providers)}->StateReducer.update

  | SaveCustomProvider(draft) =>
    startCustomProviderMutation(state, SaveCustomProviderRequest(draft))

  | DeleteCustomProvider(id, lockVersion) =>
    startCustomProviderMutation(state, DeleteCustomProviderRequest({id, lockVersion}))

  | AcknowledgeCustomProviderMutation =>
    switch state.customProviderMutation {
    | CustomProviderMutationFailed({error: CustomProviderConflict(provider), _}) =>
      let (state, effects) = applyCustomProvider(state, provider)
      {
        ...state,
        customProviderMutation: CustomProviderMutationIdle,
      }->StateReducer.update(~sideEffects=effects)
    | CustomProviderMutationSucceeded(_) | CustomProviderMutationFailed(_) =>
      {...state, customProviderMutation: CustomProviderMutationIdle}->StateReducer.update
    | CustomProviderMutationIdle | CustomProviderMutationPending(_) => state->StateReducer.update
    }

  | CustomProviderMutationSucceeded({operation, provider}) =>
    switch state.customProviderMutation {
    | CustomProviderMutationPending(pending) if pending == operation =>
      let (state, effects) = switch operation {
      | SavingCustomProvider(_) =>
        let provider = provider->Option.getOrThrow
        applyCustomProvider(state, provider)
      | DeletingCustomProvider(id) =>
        let state = {
          ...state,
          customProviders: state.customProviders->Option.map(providers =>
            providers->Array.filter(provider => provider.id != id)
          ),
        }
        switch state.selectedModelValue {
        | Some(value) if value->String.startsWith(`custom:${id}:`) => selectModel(state, None)
        | _ => (state, [])
        }
      }
      {
        ...state,
        customProviderMutation: CustomProviderMutationSucceeded(operation),
      }->StateReducer.update(~sideEffects=effects)
    | _ => state->StateReducer.update
    }

  | CustomProviderMutationFailed({operation, error}) =>
    switch state.customProviderMutation {
    | CustomProviderMutationPending(pending) if pending == operation =>
      {
        ...state,
        customProviderMutation: CustomProviderMutationFailed({operation, error}),
      }->StateReducer.update
    | _ => state->StateReducer.update
    }
  }
}
