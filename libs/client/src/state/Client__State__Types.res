// State type definitions - extracted to avoid circular dependencies
S.enableJson()

// Re-export Task domain types for backward compatibility
module UserContentPart = Client__Task__Types.UserContentPart
module AssistantContentPart = Client__Task__Types.AssistantContentPart
module Message = Client__Task__Types.Message
module SelectedElement = Client__Task__Types.SelectedElement
module Todo = Client__Task__Types.Todo
module Task = Client__Task__Types.Task
module ACPTypes = Client__Task__Types.ACPTypes

// Re-export content block builders for backward compatibility
let stripFileUriPrefix = Client__Task__Types.stripFileUriPrefix
let makeSelectedComponentMeta = Client__Task__Types.makeSelectedComponentMeta
let selectedElementToContentBlock = Client__Task__Types.selectedElementToContentBlock
let selectedElementScreenshotToContentBlock = Client__Task__Types.selectedElementScreenshotToContentBlock
let taskToContentBlocks = Client__Task__Types.taskToContentBlocks

type sendPromptFn = (
  string,
  ~additionalBlocks: array<ACPTypes.contentBlock>,
  ~onComplete: result<ACPTypes.promptResult, string> => unit,
  ~metadata: option<JSON.t>,
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

// ACP session state - stores callbacks for API operations when session is active
// Note: sessionId is NOT stored here - it's managed by ConnectionReducer (ACP layer)
// Tasks store their own ID which equals the ACP session ID
// apiBaseUrl is co-located with AcpSessionActive to make illegal state (active + no apiBaseUrl) unrepresentable
type acpSession =
  | NoAcpSession
  | AcpSessionActive({
      sendPrompt: sendPromptFn,
      cancelPrompt: cancelPromptFn,
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

// Model configuration types
@schema
type modelConfig = {
  displayName: string,
  value: string,
}

@schema
type providerConfig = {
  id: string,
  name: string,
  models: array<modelConfig>,
}

@schema
type modelsConfigDefaultModel = {
  provider: string,
  value: string,
}

@schema
type modelsConfig = {
  providers: array<providerConfig>,
  defaultModel: modelsConfigDefaultModel,
}

// Selected model - what gets sent to the server
@schema
type selectedModel = {
  provider: string,
  value: string,
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

type state = {
  tasks: Dict.t<Task.t>,
  currentTask: Task.currentTask,
  acpSession: acpSession,
  sessionInitialized: bool,
  usageInfo: option<usageInfo>,
  openrouterKeySettings: apiKeySettings,
  anthropicOAuthStatus: anthropicOAuthStatus,
  chatgptOAuthStatus: chatgptOAuthStatus,
  modelsConfig: option<modelsConfig>,
  selectedModel: option<selectedModel>,
  sessionsLoadState: sessionsLoadState,
}
