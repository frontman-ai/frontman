module UserContentPart = Client__Task__Types.UserContentPart
module AssistantContentPart = Client__Task__Types.AssistantContentPart
module Message = Client__Task__Types.Message
module Task = Client__Task__Types.Task
module ACPTypes = Client__Task__Types.ACPTypes
module ContentBlock = Client__Task__Types.ContentBlock

let taskToPageContextBlocks = Client__Task__Types.taskToPageContextBlocks
let messageAnnotationsToContentBlocks = Client__Task__Types.messageAnnotationsToContentBlocks

type sendPromptFn = (
  string,
  ~additionalBlocks: array<ContentBlock.t>,
  ~onComplete: result<ACPTypes.promptResult, string> => unit,
  ~_meta: option<JSON.t>,
) => unit

type loadTaskFn = (string, ~needsHistory: bool, ~onComplete: result<unit, string> => unit) => unit

type deleteSessionFn = (string, ~onComplete: result<unit, string> => unit) => unit

type sendSessionCommandFn = FrontmanAiFrontmanClient.FrontmanClient__ACP.sessionCommand => unit

type requireAuthenticationFn = unit => unit

type acpSession =
  | NoAcpSession
  | AcpSessionActive({
      sendPrompt: sendPromptFn,
      sendSessionCommand: sendSessionCommandFn,
      loadTask: loadTaskFn,
      deleteSession: deleteSessionFn,
      requireAuthentication: requireAuthenticationFn,
      apiBaseUrl: string,
    })

@schema
type userApiKeysResponse = {
  providers: array<string>,
}

@schema
type userApiKeySaveRequest = {
  @live
  provider: string,
  @live
  key: string,
}

type apiKeySource =
  | Loading
  | None
  | UserOverride

type apiKeySaveStatus =
  | Idle
  | Saving
  | Saved
  | SaveError(string)

type apiKeySettings = {
  source: apiKeySource,
  saveStatus: apiKeySaveStatus,
}

@schema
type oauthStatusResponse = {
  connected: bool,
  @as("expires_at")
  expiresAt: option<string>,
}

@schema
type anthropicOAuthAuthorizeUrlResponse = {
  @as("authorize_url")
  authorizeUrl: string,
  verifier: string,
}

@schema
type anthropicOAuthExchangeResponse = {
  @as("expires_at")
  expiresAt: string,
}

@schema
type anthropicOAuthErrorResponse = {
  error: string,
}

@schema
type openAIDeviceAuthResponse = {
  @as("device_auth_id")
  deviceAuthId: string,
  @as("user_code")
  userCode: string,
  @as("verification_url")
  verificationUrl: string,
}

@schema
type openAIDeviceAuthPollStatus =
  | @as("connected") DeviceAuthConnected
  | @as("pending") DeviceAuthPending

@schema
type openAIDeviceAuthPollResponse = {
  status: openAIDeviceAuthPollStatus,
  @as("expires_at")
  expiresAt: option<string>,
}

@schema
type customProvider = {
  id: string,
  name: string,
  @as("base_url")
  baseUrl: string,
  @as("has_api_key")
  hasApiKey: bool,
  models: array<string>,
  @as("lock_version")
  lockVersion: int,
}

@schema
type customProvidersResponse = {
  @as("data")
  providers: array<customProvider>,
}

@schema
type customProviderResponse = {
  @as("data")
  provider: customProvider,
}

type customProviderApiKeyChange =
  | KeepCustomProviderApiKey
  | ClearCustomProviderApiKey
  | ReplaceCustomProviderApiKey(string)

type customProviderDraft = {
  id: option<string>,
  name: string,
  baseUrl: string,
  apiKeyChange: customProviderApiKeyChange,
  models: array<string>,
  lockVersion: option<int>,
}

type customProviderMutationOperation =
  | SavingCustomProvider(option<string>)
  | DeletingCustomProvider(string)

type customProviderMutationError =
  | CustomProviderValidationError(Dict.t<array<string>>)
  | CustomProviderNotFound
  | CustomProviderConflict(customProvider)
  | CustomProviderNetworkError(string)

type customProviderMutation =
  | CustomProviderMutationIdle
  | CustomProviderMutationPending(customProviderMutationOperation)
  | CustomProviderMutationSucceeded(customProviderMutationOperation)
  | CustomProviderMutationFailed({
      operation: customProviderMutationOperation,
      error: customProviderMutationError,
    })

module ACPConfig = {
  type sessionConfigOption = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigOption
  type sessionConfigValueId = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigValueId
}

type anthropicOAuthStatus =
  | NotConnected
  | FetchingStatus
  | Authorizing({authorizeUrl: string, verifier: string})
  | Exchanging
  | Connected({expiresAt: float})
  | Error(string)

type openaiOAuthStatus =
  | OpenAINotConnected
  | OpenAIFetchingStatus
  | OpenAIWaitingForCode
  | OpenAIShowingCode({deviceAuthId: string, userCode: string, verificationUrl: string})
  | OpenAIConnected({expiresAt: float})
  | OpenAIError(string)

type sessionsLoadState =
  | SessionsNotLoaded
  | SessionsLoading
  | SessionsLoaded
  | SessionsLoadError(string)

@schema
type userProfile = {
  id: string,
  email: string,
  name: option<string>,
}

type updateTarget =
  | NpmPackage(string)
  | WordPressPlugin(string)

type updateInfo = {
  target: updateTarget,
  installedVersion: string,
  latestVersion: string,
}

@schema
type latestVersionsResponse = {versions: Dict.t<option<string>>}

type updateCheckStatus =
  | UpdateNotChecked
  | UpdateChecked

type highlightedAnnotation = {
  taskId: string,
  annotationId: string,
  selector: string,
}

type firstTaskFeedbackDialogState =
  | Waiting
  | AwaitingHistory
  | Visible
  | LinkCopied
  | ShareFailed
  | Dismissed

type state = {
  tasks: Dict.t<Task.t>,
  currentTask: Task.currentTask,
  acpSession: acpSession,
  userProfile: option<userProfile>,
  openrouterKeySettings: apiKeySettings,
  anthropicKeySettings: apiKeySettings,
  fireworksKeySettings: apiKeySettings,
  nvidiaKeySettings: apiKeySettings,
  anthropicOAuthStatus: anthropicOAuthStatus,
  openaiOAuthStatus: openaiOAuthStatus,
  configOptions: option<array<ACPConfig.sessionConfigOption>>,
  selectedModelValue: option<ACPConfig.sessionConfigValueId>,
  agentCatalog: option<array<ACPTypes.agentCatalogEntry>>,
  selectedAgentId: option<string>,
  pendingProviderAutoSelect: option<string>,
  sessionsLoadState: sessionsLoadState,
  customProviders: option<array<customProvider>>,
  customProviderMutation: customProviderMutation,
  updateInfo: option<updateInfo>,
  updateCheckStatus: updateCheckStatus,
  updateBannerDismissed: bool,
  firstTaskFeedbackDialogState: firstTaskFeedbackDialogState,
  highlightedAnnotation: option<highlightedAnnotation>,
}
