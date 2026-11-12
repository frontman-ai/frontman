module UserContentPart = Client__State__Types.UserContentPart
module Message = Client__State__Types.Message
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module TaskReducer = Client__Task__Reducer
module Connection = Client__ConnectionReducer
type state = Client__State__Types.state

let executePlanPrompt = "Execute the plan above."

type taskTarget = CurrentTask | ForTask(string)

type apiKeyProvider = OpenRouter | Anthropic | Fireworks | Nvidia

type pendingPlanHandoff = {taskId: string, executorAgentId: string}

type wordPressOperation = CheckConnection | ApproveConnection | UpdateAccess(bool)
type wordPressConnection = {connected: bool, enabled: bool}
type wordPressError = WordPressRequestFailed(string) | WordPressAuthRequired

type promptInput = {
  id: Message.UserMessageId.t,
  timestamp: float,
  content: array<UserContentPart.t>,
  annotationId: option<string>,
  onComplete: result<unit, string> => unit,
}

type rec action =
  | InitializeConnection(Connection.config)
  | WordPressAuthenticationRequired(option<string>)
  | ReloadAfterWordPressLogin
  | ConnectWordPress
  | FetchWordPressConnection
  | SetWordPressAccess(bool)
  | WordPressConnectionCompletion({
      requestId: int,
      result: result<wordPressConnection, wordPressError>,
      credentialRisk: bool,
    })
  | ConnectionAction(Connection.action)
  | ConnectionEvent({signal: WebAPI.EventTypes.abortSignal, action: action})
  | SessionEvent({requestId: Connection.sessionRequestId, action: action})
  | AddUserMessage(promptInput)
  | PromptFailed({
      requestId: Connection.sessionRequestId,
      taskId: string,
      id: Message.UserMessageId.t,
      error: Connection.ACP.requestError,
    })
  | AcpSessionUpdateReceived({taskId: string, update: ACP.sessionUpdate, errorDisplayId: option<string>})
  | TaskAction({target: taskTarget, action: TaskReducer.action})
  | PreviewAction({clientId: string, navigationKey: int, action: TaskReducer.action})
  | CancelTurn
  | ExecutePendingPlan({id: Message.UserMessageId.t, timestamp: float})
  | TaskLoadFinished({taskId: string, result: result<Connection.sessionRequestId, string>})
  | SwitchTask({taskId: string})
  | DeleteTask({taskId: string, replacementClientId: string})
  | ClearCurrentTask({replacementClientId: string})
  | UpdateTaskTitle({taskId: string, title: string})
  | SetSettingsModalTab({tab: option<Client__State__Types.settingsTab>})
  | BillingStatusReceived(Client__Billing.status)
  | BillingStatusError({error: string})
  | RequestBilling(Client__Billing.request)
  | BillingUrlReceived({tab: WebAPI.Window.t, url: string, request: Client__Billing.request})
  | BillingCheckoutDismissed
  | BillingLaunchFailed({tab: option<WebAPI.Window.t>, error: string})
  | BillingAuthRequired({tab: option<WebAPI.Window.t>})
  | BillingRequestCancelled({tab: option<WebAPI.Window.t>})
  | FetchUserProfile({apiBaseUrl: string})
  | FetchApiKeySettings
  | ApiKeySettingsReceived({provider: apiKeyProvider, source: Client__State__Types.apiKeySource})
  | SaveApiKey({provider: apiKeyProvider, key: string})
  | ApiKeySaveStarted({provider: apiKeyProvider})
  | ApiKeySaved({provider: apiKeyProvider})
  | ApiKeySaveError({provider: apiKeyProvider, error: string})
  | ResetApiKeySaveStatus({provider: apiKeyProvider})
  | ConfigOptionsReceived({
      configOptions: array<Client__State__Types.ACPConfig.sessionConfigOption>,
    })
  | SetSelectedModelValue({value: Client__State__Types.ACPConfig.sessionConfigValueId})
  | AgentAttributionConfigured({agentCatalog: array<ACP.agentCatalogEntry>, defaultAgentId: string})
  | SetSelectedAgentId(string)
  | FetchAnthropicOAuthStatus
  | AnthropicOAuthStatusReceived({connected: bool, expiresAt: option<string>})
  | InitiateAnthropicOAuth
  | AnthropicOAuthUrlReceived({authorizeUrl: string, verifier: string})
  | ExchangeAnthropicOAuthCode({code: string, verifier: string})
  | AnthropicOAuthConnected({expiresAt: string})
  | AnthropicOAuthError({error: string})
  | DisconnectAnthropicOAuth
  | AnthropicOAuthDisconnected
  | ResetAnthropicOAuthError
  | CancelAnthropicOAuth
  | FetchOpenAIOAuthStatus
  | OpenAIOAuthStatusReceived({connected: bool, expiresAt: option<string>})
  | InitiateOpenAIOAuth
  | OpenAIDeviceCodeReceived({deviceAuthId: string, userCode: string, verificationUrl: string})
  | OpenAIOAuthConnected({deviceAuthId: string, expiresAt: string})
  | OpenAIOAuthError({deviceAuthId: option<string>, error: string})
  | DisconnectOpenAIOAuth
  | OpenAIOAuthDisconnected
  | ResetOpenAIOAuthError
  | UserProfileReceived({userProfile: Client__State__Types.userProfile})
  | SessionsLoadStarted
  | SessionsLoadSuccess({
      sessions: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionSummary>,
    })
  | SessionsLoadError({error: string})
  | CheckForUpdate({
      apiBaseUrl: string,
      installedVersion: string,
      target: Client__State__Types.updateTarget,
    })
  | UpdateInfoChecked(option<Client__State__Types.updateInfo>)
  | WordPressUpdatesChecked(option<Client__WordPressUpdates.response>)
  | DismissUpdateBanner
  | HighlightAnnotation({annotationId: string, selector: string})
  | FetchCustomProviders
  | CustomProvidersReceived({providers: array<Client__State__Types.customProvider>})
  | SaveCustomProvider(Client__State__Types.customProviderDraft)
  | DeleteCustomProvider(string, int)
  | AcknowledgeCustomProviderMutation
  | CustomProviderMutationSucceeded({
      operation: Client__State__Types.customProviderMutationOperation,
      provider: option<Client__State__Types.customProvider>,
    })
  | CustomProviderMutationFailed({
      operation: Client__State__Types.customProviderMutationOperation,
      error: Client__State__Types.customProviderMutationError,
    })

type customProviderMutationRequest =
  | SaveCustomProviderRequest(Client__State__Types.customProviderDraft)
  | DeleteCustomProviderRequest({id: string, lockVersion: int})

type effect =
  | ReloadFrontman
  | PersistSelectedModel(option<string>)
  | ConnectionEffect(Connection.effect)
  | CreateSession({taskId: string, input: promptInput})
  | SendMessage({taskId: string, submission: Client__State__Types.submission})
  | SubmissionCompleted({onComplete: result<unit, string> => unit, result: result<unit, string>})
  | AbortBillingRequest(option<WebAPI.EventTypes.abortController>)
  | FetchBillingStatus({signal: WebAPI.EventTypes.abortSignal, apiBaseUrl: string})
  | OpenBillingTabAndFetchUrl({
      signal: WebAPI.EventTypes.abortSignal,
      request: Client__Billing.request,
      apiBaseUrl: string,
    })
  | NavigateBillingTab({tab: WebAPI.Window.t, url: string})
  | CloseBillingTab(option<WebAPI.Window.t>)
  | RequireBillingAuthentication
  | BufferAssistantText({taskId: string, messageId: string, text: string, agentId: string})
  | BufferUserBlock({
      taskId: string,
      messageId: string,
      block: FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.t,
      agentId: string,
    })
  | FlushSessionActions(array<action>)
  | TaskEffect({target: taskTarget, effect: TaskReducer.effect})
  | FetchApiKeySettingsEffect({apiBaseUrl: string})
  | WordPressConnectionEffect({apiBaseUrl: string, requestId: int, operation: wordPressOperation})
  | SaveApiKeyEffect({apiBaseUrl: string, provider: apiKeyProvider, key: string})
  | FetchAnthropicOAuthStatusEffect({apiBaseUrl: string})
  | GetAnthropicOAuthUrlEffect({apiBaseUrl: string})
  | ExchangeAnthropicOAuthCodeEffect({apiBaseUrl: string, code: string, verifier: string})
  | DisconnectAnthropicOAuthEffect({apiBaseUrl: string})
  | FetchOpenAIOAuthStatusEffect({apiBaseUrl: string})
  | InitiateOpenAIDeviceAuthEffect({apiBaseUrl: string})
  | DisconnectOpenAIOAuthEffect({apiBaseUrl: string})
  | PollOpenAIDeviceAuthEffect({apiBaseUrl: string, deviceAuthId: string, userCode: string})
  | FetchUserProfileEffect({apiBaseUrl: string})
  | CheckForUpdateEffect({
      apiBaseUrl: string,
      installedVersion: string,
      target: Client__State__Types.updateTarget,
    })
  | FetchCustomProvidersEffect({apiBaseUrl: string})
  | CustomProviderMutationEffect({apiBaseUrl: string, request: customProviderMutationRequest})

let apiKeyProviderId = provider =>
  switch provider {
  | OpenRouter => "openrouter"
  | Anthropic => "anthropic"
  | Fireworks => "fireworks_ai"
  | Nvidia => "nvidia"
  }

let apiKeyProviders: array<apiKeyProvider> = [OpenRouter, Anthropic, Fireworks, Nvidia]

let embeddedAuthRequiredError = "Frontman authorization is required"

let customProviderMutationOperation = request =>
  switch request {
  | SaveCustomProviderRequest(draft) => Client__State__Types.SavingCustomProvider(draft.id)
  | DeleteCustomProviderRequest({id}) => Client__State__Types.DeletingCustomProvider(id)
  }
