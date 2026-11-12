module Task = Client__State__Types.Task
type state = Client__State__Types.state

let defaultState: state = {
  tasks: Dict.make(),
  currentTask: Task.New(Task.makeNew(
    ~previewUrl=Client__BrowserUrl.getInitialUrl(),
    ~clientId=WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.randomUUID,
  )),
  connection: None,
  wordPressLoginRecovery: None,
  wordPressConnectionStatus: WordPressNotChecked,
  wordPressConnectionRequestId: 0,
  wordPressPendingMutation: None,
  wordPressCredentialWarning: false,
  userProfile: None,
  settingsModalTab: None,
  billingStatus: Client__Billing.NotLoaded,
  billingFlow: Client__Billing.Idle,
  billingAbortController: None,
  billingStatusAbortController: None,
  openrouterKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  anthropicKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  fireworksKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  nvidiaKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  anthropicOAuthStatus: Client__State__Types.NotConnected,
  openaiOAuthStatus: Client__State__Types.OpenAINotConnected,
  configOptions: None,
  selectedModelValue: Client__State__ModelPreference.loadSelectedModelValueFromStorage(),
  agentCatalog: None,
  selectedAgentId: None,
  pendingProviderAutoSelect: None,
  sessionsLoadState: Client__State__Types.SessionsNotLoaded,
  customProviders: None,
  customProviderMutation: Client__State__Types.CustomProviderMutationIdle,
  updateInfo: None,
  wordpressUpdates: NotChecked,
  updateBannerDismissed: false,
  highlightedAnnotation: None,
}
