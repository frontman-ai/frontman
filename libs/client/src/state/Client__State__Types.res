// State type definitions - extracted to avoid circular dependencies
S.enableJson()

// Re-export Task domain types for backward compatibility
module UserContentPart = Client__Task__Types.UserContentPart
module AssistantContentPart = Client__Task__Types.AssistantContentPart
module Message = Client__Task__Types.Message
module Task = Client__Task__Types.Task
module ACPTypes = Client__Task__Types.ACPTypes

// Re-export content block builders
let annotationToContentBlocks = Client__Task__Types.annotationToContentBlocks
let taskToPageContextBlocks = Client__Task__Types.taskToPageContextBlocks
let messageAnnotationsToContentBlocks = Client__Task__Types.messageAnnotationsToContentBlocks

type sendPromptFn = (
  string,
  ~additionalBlocks: array<ACPTypes.contentBlock>,
  ~onComplete: result<ACPTypes.promptResult, string> => unit,
  ~_meta: option<JSON.t>,
) => unit

// Callback for loading a persisted task's messages
// taskId: the task to load (maps to sessionId at protocol level)
// needsHistory: true = load full history (task not loaded), false = just activate channel (task already loaded)
// onComplete: called when loading finishes (success or error)
// Note: onUpdate is baked in when the callback is created (uses handleSessionUpdate)
type loadTaskFn = (string, ~needsHistory: bool, ~onComplete: result<unit, string> => unit) => unit

// Callback for deleting a persisted session
// taskId: the task/session to delete
// onComplete: called when deletion finishes (success or error)
type deleteSessionFn = (string, ~onComplete: result<unit, string> => unit) => unit

// Callback for cancelling the current prompt turn
// Fire-and-forget: sends ACP session/cancel notification
type cancelPromptFn = unit => unit

// Callback for retrying a failed turn
// Fire-and-forget: sends ACP retry_turn notification with the error ID that triggered the retry
type retryTurnFn = string => unit

// ACP session state - stores callbacks for API operations when session is active
// Note: sessionId is NOT stored here - it's managed by ConnectionReducer (ACP layer)
// Tasks store their own ID which equals the ACP session ID
// apiBaseUrl is co-located with AcpSessionActive to make illegal state (active + no apiBaseUrl) unrepresentable
type acpSession =
  | NoAcpSession
  | AcpSessionActive({
      sendPrompt: sendPromptFn,
      cancelPrompt: cancelPromptFn,
      retryTurn: retryTurnFn,
      loadTask: loadTaskFn,
      deleteSession: deleteSessionFn,
      apiBaseUrl: string,
    })

// Usage info from API
@schema
type usageInfo = {
  limit: option<int>,
  remaining: option<int>,
  hasUserKey: option<bool>,
  hasServerKey: option<bool>,
}

@schema
type userApiKeySaveRequest = {
  @live
  provider: string,
  @live
  key: string,
}

// API key source status for settings display
type apiKeySource =
  | None // No key configured
  | FromEnv // Key loaded from environment variable
  | UserOverride // User has saved their own key (stored in DB)

// API key save operation status
type apiKeySaveStatus =
  | Idle
  | Saving
  | Saved
  | SaveError(string)

// API key settings for a provider
type apiKeySettings = {
  source: apiKeySource,
  saveStatus: apiKeySaveStatus,
}

// Re-export ACP session config types used by the client state layer.
module ACPConfig = {
  type sessionConfigOption = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigOption
  type sessionConfigValueId = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigValueId
}

// Anthropic OAuth connection status
type anthropicOAuthStatus =
  | NotConnected
  | FetchingStatus
  | Authorizing({authorizeUrl: string, verifier: string})
  | Exchanging
  | Connected({expiresAt: float})
  | Error(string)

// ChatGPT OAuth connection status (device auth flow)
type chatgptOAuthStatus =
  | ChatGPTNotConnected
  | ChatGPTFetchingStatus
  | ChatGPTWaitingForCode // Requesting device code from OpenAI
  | ChatGPTShowingCode({deviceAuthId: string, userCode: string, verificationUrl: string}) // User needs to enter code
  | ChatGPTConnected({expiresAt: float})
  | ChatGPTError(string)

// Sessions load state for persisted sessions
type sessionsLoadState =
  | SessionsNotLoaded
  | SessionsLoading
  | SessionsLoaded
  | SessionsLoadError(string)

// User profile from /api/user/me
@schema
type userProfile = {
  id: string,
  email: string,
  name: option<string>,
}

// Integration package update info
type updateInfo = {
  npmPackage: string,
  installedVersion: string,
  latestVersion: string,
}

// API response from /api/integrations/latest-versions
@schema
type latestVersionsResponse = {versions: Dict.t<option<string>>}

// Update check lifecycle — prevents duplicate fetches
type updateCheckStatus =
  | UpdateNotChecked
  | UpdateChecked

type state = {
  tasks: Dict.t<Task.t>,
  currentTask: Task.currentTask,
  acpSession: acpSession,
  sessionInitialized: bool,
  usageInfo: option<usageInfo>,
  userProfile: option<userProfile>,
  openrouterKeySettings: apiKeySettings,
  anthropicKeySettings: apiKeySettings,
  fireworksKeySettings: apiKeySettings,
  anthropicOAuthStatus: anthropicOAuthStatus,
  chatgptOAuthStatus: chatgptOAuthStatus,
  // ACP session config options (replaces bespoke modelsConfig/selectedModel).
  // Populated from session/new and session/load responses.
  // Model selection is a SessionConfigOption with category=Model.
  configOptions: option<array<ACPConfig.sessionConfigOption>>,
  // Currently selected model value (ACP sessionConfigValueId, e.g. "anthropic:claude-sonnet-4-5").
  // Persisted to localStorage. Derives from configOptions where category=Model.
  selectedModelValue: option<ACPConfig.sessionConfigValueId>,
  // When a provider is freshly connected, this holds its id (e.g. "anthropic")
  // so the next config options refresh auto-selects a default model from it.
  pendingProviderAutoSelect: option<string>,
  sessionsLoadState: sessionsLoadState,
  // Update banner: set when a newer integration package version is available
  updateInfo: option<updateInfo>,
  updateCheckStatus: updateCheckStatus,
  updateBannerDismissed: bool,
}
