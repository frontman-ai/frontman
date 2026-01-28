// State type definitions - extracted to avoid circular dependencies
S.enableJson()

// Re-export Task domain types for backward compatibility
module UserContentPart = Client__Task__Types.UserContentPart
module AssistantContentPart = Client__Task__Types.AssistantContentPart
module Message = Client__Task__Types.Message
module SelectedElement = Client__Task__Types.SelectedElement
module FigmaNode = Client__Task__Types.FigmaNode
module Todo = Client__Task__Types.Todo
module Task = Client__Task__Types.Task
module ACPTypes = Client__Task__Types.ACPTypes

// Re-export content block builders for backward compatibility
let stripFileUriPrefix = Client__Task__Types.stripFileUriPrefix
let makeSelectedComponentMeta = Client__Task__Types.makeSelectedComponentMeta
let selectedElementToContentBlock = Client__Task__Types.selectedElementToContentBlock
let selectedElementScreenshotToContentBlock = Client__Task__Types.selectedElementScreenshotToContentBlock
let makeFigmaNodeMeta = Client__Task__Types.makeFigmaNodeMeta
let figmaNodeToContentBlock = Client__Task__Types.figmaNodeToContentBlock
let figmaImageToContentBlock = Client__Task__Types.figmaImageToContentBlock
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

// Connection state for the Frontman ACP session
// Note: sessionId is NOT stored here - it's managed by ConnectionReducer (ACP layer)
// Tasks store their own ID which equals the ACP session ID
// apiBaseUrl is co-located with Connected to make illegal state (Connected + no apiBaseUrl) unrepresentable
type connectionState =
  | Disconnected
  | Connected({
      sendPrompt: sendPromptFn,
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

// Sessions load state for persisted sessions
type sessionsLoadState =
  | SessionsNotLoaded
  | SessionsLoading
  | SessionsLoaded
  | SessionsLoadError(string)

type state = {
  tasks: Dict.t<Task.t>,
  currentTask: Task.currentTask,
  connectionState: connectionState,
  sessionInitialized: bool,
  usageInfo: option<usageInfo>,
  openrouterKeySettings: apiKeySettings,
  anthropicOAuthStatus: anthropicOAuthStatus,
  modelsConfig: option<modelsConfig>,
  selectedModel: option<selectedModel>,
  sessionsLoadState: sessionsLoadState,
}
