open Vitest

module Reducer = Client__State__StateReducer
module Types = Client__State__Types
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

// Dummy callbacks for AcpSessionActive (reducer only checks the variant, not the callbacks)
let _dummySendPrompt: Types.sendPromptFn = (_, ~additionalBlocks as _, ~onComplete as _, ~_meta as _) => ()
let _dummyCancelPrompt: Types.cancelPromptFn = () => ()
let _dummyLoadTask: Types.loadTaskFn = (_, ~needsHistory as _, ~onComplete as _) => ()
let _dummyDeleteSession: Types.deleteSessionFn = (_, ~onComplete as _) => ()

let _apiBaseUrl = "http://localhost:4000"

// Helper: base state with an active ACP session (needed to emit effects)
let _makeState = (~anthropicOAuthStatus=Types.NotConnected, ~chatgptOAuthStatus=Types.ChatGPTNotConnected, ~openrouterKeySettings={Types.source: Types.None, saveStatus: Types.Idle}, ~selectedModelValue=None, ~pendingProviderAutoSelect=None): Types.state => {
  {
    tasks: Dict.make(),
    currentTask: Types.Task.New(Types.Task.makeNew(~previewUrl="http://localhost:3000")),
    acpSession: AcpSessionActive({
      sendPrompt: _dummySendPrompt,
      cancelPrompt: _dummyCancelPrompt,
      loadTask: _dummyLoadTask,
      deleteSession: _dummyDeleteSession,
      apiBaseUrl: _apiBaseUrl,
    }),
    sessionInitialized: true,
    usageInfo: None,
    userProfile: None,
    openrouterKeySettings,
    anthropicKeySettings: {
      source: Types.None,
      saveStatus: Types.Idle,
    },
    anthropicOAuthStatus,
    chatgptOAuthStatus,
    configOptions: None,
    selectedModelValue,
    pendingProviderAutoSelect,
    sessionsLoadState: Types.SessionsNotLoaded,
    updateInfo: None,
    updateCheckStatus: UpdateNotChecked,
    updateBannerDismissed: false,
  }
}

// ============================================================================
// Sample ACP SessionConfigOption data (replaces old providerConfig/modelsConfig)
// ============================================================================

module SampleConfig = {
  // Helper to build a grouped model config option
  let _makeModelConfigOption = (
    ~groups: array<ACP.sessionConfigSelectGroup>,
    ~currentValue: string,
  ): ACP.sessionConfigOption => {
    ACP.SelectConfigOption({
      id: "model",
      name: "Model",
      description: None,
      category: Some(ACP.Model),
      currentValue,
      options: ACP.Grouped(groups),
      _meta: None,
    })
  }

  let _anthropicGroup: ACP.sessionConfigSelectGroup = {
    group: "anthropic",
    name: "Anthropic (Claude Pro/Max)",
    options: [
      {value: "anthropic:claude-sonnet-4-5", name: "Claude Sonnet 4.5", description: None, _meta: None},
      {value: "anthropic:claude-opus-4-5", name: "Claude Opus 4.5", description: None, _meta: None},
    ],
    _meta: None,
  }

  let _openaiGroup: ACP.sessionConfigSelectGroup = {
    group: "openai",
    name: "ChatGPT Pro/Plus",
    options: [
      {value: "openai:gpt-5.1-codex-max", name: "GPT-5.1 Codex Max", description: None, _meta: None},
      {value: "openai:gpt-5.2", name: "GPT-5.2", description: None, _meta: None},
    ],
    _meta: None,
  }

  let _openrouterGroup: ACP.sessionConfigSelectGroup = {
    group: "openrouter",
    name: "OpenRouter",
    options: [
      {value: "openrouter:google/gemini-3-flash-preview", name: "Gemini 3 Flash Preview", description: None, _meta: None},
      {value: "openrouter:anthropic/claude-haiku-4.5", name: "Claude Haiku 4.5", description: None, _meta: None},
    ],
    _meta: None,
  }

  let configWithAnthropic = [
    _makeModelConfigOption(
      ~groups=[_anthropicGroup, _openrouterGroup],
      ~currentValue="anthropic:claude-sonnet-4-5",
    ),
  ]

  let configWithOpenAI = [
    _makeModelConfigOption(
      ~groups=[_openaiGroup, _anthropicGroup, _openrouterGroup],
      ~currentValue="openai:gpt-5.1-codex-max",
    ),
  ]

  let configWithOpenRouterOnly = [
    _makeModelConfigOption(
      ~groups=[_openrouterGroup],
      ~currentValue="openrouter:google/gemini-3-flash-preview",
    ),
  ]
}

describe("Initiating actions set pendingProviderAutoSelect eagerly", () => {
  test("ExchangeAnthropicOAuthCode sets pendingProviderAutoSelect to anthropic", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      ExchangeAnthropicOAuthCode({code: "test-code", verifier: "test-verifier"}),
    )

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("anthropic"))
  })

  test("InitiateChatGPTOAuth sets pendingProviderAutoSelect to openai", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(state, InitiateChatGPTOAuth)

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("openai"))
  })

  test("SaveOpenRouterKey sets pendingProviderAutoSelect to openrouter", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      SaveOpenRouterKey({key: "test-key"}),
    )

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("openrouter"))
  })

  test("SaveAnthropicKey sets pendingProviderAutoSelect to anthropic", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      SaveAnthropicKey({key: "test-key"}),
    )

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("anthropic"))
  })
})

describe("ConfigOptionsReceived auto-selects model from newly connected provider", () => {
  test("auto-selects first Anthropic model when pendingProviderAutoSelect is anthropic", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("anthropic"),
      ~selectedModelValue=Some("openrouter:google/gemini-3-flash-preview"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithAnthropic}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("anthropic:claude-sonnet-4-5"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("auto-selects first OpenAI model when pendingProviderAutoSelect is openai", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openai"),
      ~selectedModelValue=Some("openrouter:google/gemini-3-flash-preview"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenAI}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("openai:gpt-5.1-codex-max"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("auto-selects first OpenRouter model when pendingProviderAutoSelect is openrouter", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openrouter"),
      ~selectedModelValue=Some("openrouter:anthropic/claude-haiku-4.5"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenRouterOnly}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("openrouter:google/gemini-3-flash-preview"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("keeps current selection when no pending provider auto-select", t => {
    let existingModel = "openrouter:google/gemini-3-flash-preview"
    let state = _makeState(~selectedModelValue=Some(existingModel))

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithAnthropic}),
    )

    t->expect(nextState.selectedModelValue)->Expect.toEqual(Some(existingModel))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("falls back to server default when no selection and no pending provider", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithAnthropic}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("anthropic:claude-sonnet-4-5"))
  })

  test("clears pendingProviderAutoSelect even if provider not in config", t => {
    let existingModel = "openrouter:google/gemini-3-flash-preview"
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openai"),
      ~selectedModelValue=Some(existingModel),
    )

    // Config doesn't have OpenAI provider — keep existing selection
    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenRouterOnly}),
    )

    t->expect(nextState.selectedModelValue)->Expect.toEqual(Some(existingModel))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })
})
