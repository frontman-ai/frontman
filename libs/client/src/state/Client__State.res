type state = Client__State__Types.state

let useSelector = selection => StateStore.useSelector(Client__State__Store.store, selection)

module Selectors = Client__State__StateReducer.Selectors
module UserContentPart = Client__State__Types.UserContentPart
module AssistantContentPart = Client__State__Types.AssistantContentPart

module Actions = {
  let addUserMessage = (~content, ~annotationId=?) =>
    Promise.make((resolve, _) =>
      Client__State__Store.dispatch(AddUserMessage({content, annotationId, onComplete: resolve}))
    )

  let setCurrentPreviewUrl = (~url) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: SetPreviewUrl({url: url})}),
    )

  let observePreviewUrl = (~url) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: SetPreviewUrl({url: url})}),
    )

  let setPreviewFrame = (~contentDocument, ~contentWindow) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: SetPreviewFrame({contentDocument, contentWindow})}),
    )

  let setDeviceMode = (~deviceMode) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: SetDeviceMode({deviceMode: deviceMode})}),
    )

  let setOrientation = (~orientation) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: SetOrientation({orientation: orientation})}),
    )

  let toggleDeviceMode = () =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: ToggleDeviceMode}))

  let toggleWebPreviewSelection = () =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: ToggleAnnotationMode}))

  let toggleAnnotation = (~element, ~tagName) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: ToggleAnnotation({element, tagName})}),
    )

  let addAnnotation = (~element, ~tagName) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: AddAnnotation({element, tagName})}),
    )

  let addAnnotations = (~elements) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: AddAnnotations({elements: elements})}),
    )

  let removeAnnotation = (~id) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: RemoveAnnotation({id: id})}),
    )

  let clearAnnotations = () =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: ClearAnnotations}))

  let updateAnnotationComment = (~id, ~comment) =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: UpdateAnnotationComment({id, comment})}),
    )

  let highlightAnnotation = (~annotationId, ~selector) =>
    Client__State__Store.dispatch(HighlightAnnotation({annotationId, selector}))

  let closeAnnotationPopup = () =>
    Client__State__Store.dispatch(
      TaskAction({target: CurrentTask, action: SetActivePopupAnnotationId({id: None})}),
    )

  let switchTask = (~taskId) => Client__State__Store.dispatch(SwitchTask({taskId: taskId}))

  let deleteTask = (~taskId) => Client__State__Store.dispatch(DeleteTask({taskId: taskId}))

  let clearCurrentTask = () => Client__State__Store.dispatch(ClearCurrentTask)

  let cancelTurn = () => Client__State__Store.dispatch(CancelTurn)

  let executePendingPlan = () => {
    let id = Client__Message.UserMessageId.make()
    Client__State__Store.dispatch(ExecutePendingPlan({id: id}))
  }

  let connection = action => Client__State__Store.dispatch(ConnectionAction(action))

  let fetchUserProfile = (~apiBaseUrl: string) =>
    Client__State__Store.dispatch(FetchUserProfile({apiBaseUrl: apiBaseUrl}))

  let unqueueMessage = (~taskId: string, ~messageId: string) =>
    Client__State__Store.dispatch(
      TaskAction({target: ForTask(taskId), action: UnqueueMessage({messageId: messageId})}),
    )

  let retryTurn = (~taskId: string, ~retriedErrorId: string) =>
    Client__State__Store.dispatch(
      TaskAction({target: ForTask(taskId), action: RetryTurn({retriedErrorId: retriedErrorId})}),
    )

  let setSettingsModalTab = (tab: option<Client__State__Types.settingsTab>) =>
    Client__State__Store.dispatch(SetSettingsModalTab({tab: tab}))
  let openSettingsModal = () => setSettingsModalTab(Some(Client__State__Types.General))
  let openActivation = () => setSettingsModalTab(Some(Client__State__Types.Activation))
  let openProviderSetup = () => setSettingsModalTab(Some(Client__State__Types.ProviderSetup))
  let continueActivation = () => Client__State__Store.dispatch(ContinueActivation)
  let setComposerDraft = text => Client__State__Store.dispatch(SetComposerDraft(text))
  let dismissBillingCheckout = () => Client__State__Store.dispatch(BillingCheckoutDismissed)
  let requestBilling = request => Client__State__Store.dispatch(RequestBilling(request))
  let closeSettingsModal = () => setSettingsModalTab(None)

  let fetchApiKeySettings = () => Client__State__Store.dispatch(FetchApiKeySettings)

  let saveOpenRouterKey = (~key) =>
    Client__State__Store.dispatch(SaveApiKey({provider: OpenRouter, key}))

  let resetOpenRouterKeySaveStatus = () =>
    Client__State__Store.dispatch(ResetApiKeySaveStatus({provider: OpenRouter}))

  let saveAnthropicKey = (~key) =>
    Client__State__Store.dispatch(SaveApiKey({provider: Anthropic, key}))

  let resetAnthropicKeySaveStatus = () =>
    Client__State__Store.dispatch(ResetApiKeySaveStatus({provider: Anthropic}))

  let saveFireworksKey = (~key) =>
    Client__State__Store.dispatch(SaveApiKey({provider: Fireworks, key}))

  let resetFireworksKeySaveStatus = () =>
    Client__State__Store.dispatch(ResetApiKeySaveStatus({provider: Fireworks}))

  let saveNvidiaKey = (~key) => Client__State__Store.dispatch(SaveApiKey({provider: Nvidia, key}))

  let resetNvidiaKeySaveStatus = () =>
    Client__State__Store.dispatch(ResetApiKeySaveStatus({provider: Nvidia}))

  let setSelectedModelValue = (~value) =>
    Client__State__Store.dispatch(SetSelectedModelValue({value: value}))

  let setSelectedAgentId = (~agentId: string) =>
    Client__State__Store.dispatch(SetSelectedAgentId(agentId))

  let fetchAnthropicOAuthStatus = () => Client__State__Store.dispatch(FetchAnthropicOAuthStatus)

  let initiateAnthropicOAuth = () => Client__State__Store.dispatch(InitiateAnthropicOAuth)

  let exchangeAnthropicOAuthCode = (~code, ~verifier) =>
    Client__State__Store.dispatch(ExchangeAnthropicOAuthCode({code, verifier}))

  let disconnectAnthropicOAuth = () => Client__State__Store.dispatch(DisconnectAnthropicOAuth)

  let resetAnthropicOAuthError = () => Client__State__Store.dispatch(ResetAnthropicOAuthError)

  let cancelAnthropicOAuth = () => Client__State__Store.dispatch(CancelAnthropicOAuth)

  let fetchOpenAIOAuthStatus = () => Client__State__Store.dispatch(FetchOpenAIOAuthStatus)

  let initiateOpenAIOAuth = () => Client__State__Store.dispatch(InitiateOpenAIOAuth)

  let disconnectOpenAIOAuth = () => Client__State__Store.dispatch(DisconnectOpenAIOAuth)

  let resetOpenAIOAuthError = () => Client__State__Store.dispatch(ResetOpenAIOAuthError)

  let checkForUpdate = (~apiBaseUrl, ~installedVersion, ~target) =>
    Client__State__Store.dispatch(CheckForUpdate({apiBaseUrl, installedVersion, target}))

  let dismissUpdateBanner = () => Client__State__Store.dispatch(DismissUpdateBanner)

  let fetchCustomProviders = () => Client__State__Store.dispatch(FetchCustomProviders)

  let saveCustomProvider = (~draft: Client__State__Types.customProviderDraft) =>
    Client__State__Store.dispatch(SaveCustomProvider(draft))

  let deleteCustomProvider = (~id, ~lockVersion) =>
    Client__State__Store.dispatch(DeleteCustomProvider(id, lockVersion))

  let acknowledgeCustomProviderMutation = () =>
    Client__State__Store.dispatch(AcknowledgeCustomProviderMutation)

  let questionReceived = (~taskId, ~questions, ~toolCallId, ~resolveOk, ~resolveError) =>
    Client__State__Store.dispatch(
      TaskAction({
        target: ForTask(taskId),
        action: QuestionReceived({questions, toolCallId, resolveOk, resolveError}),
      }),
    )

  let questionStepChanged = (~taskId, ~step) =>
    Client__State__Store.dispatch(
      TaskAction({target: ForTask(taskId), action: QuestionStepChanged({step: step})}),
    )

  let questionOptionToggled = (~taskId, ~questionIndex, ~label) =>
    Client__State__Store.dispatch(
      TaskAction({target: ForTask(taskId), action: QuestionOptionToggled({questionIndex, label})}),
    )

  let questionCustomTextChanged = (~taskId, ~questionIndex, ~text) =>
    Client__State__Store.dispatch(
      TaskAction({
        target: ForTask(taskId),
        action: QuestionCustomTextChanged({questionIndex, text}),
      }),
    )

  let questionPerQuestionSkipped = (~taskId, ~questionIndex) =>
    Client__State__Store.dispatch(
      TaskAction({
        target: ForTask(taskId),
        action: QuestionPerQuestionSkipped({questionIndex: questionIndex}),
      }),
    )

  let questionSubmitted = (~taskId) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: QuestionSubmitted}))

  let questionAllSkipped = (~taskId) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: QuestionAllSkipped}))

  let questionCancelled = (~taskId) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: QuestionCancelled}))
}
