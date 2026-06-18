open Vitest

module Reducer = Client__State__StateReducer
module Types = Client__State__Types
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

// Dummy callbacks for AcpSessionActive (reducer only checks the variant, not the callbacks)
let _dummySendPrompt: Types.sendPromptFn = (
  _,
  ~additionalBlocks as _,
  ~onComplete as _,
  ~_meta as _,
) => ()
let _dummyCancelPrompt: Types.cancelPromptFn = () => ()
let _dummyRetryTurn: Types.retryTurnFn = _ => ()
let _dummyLoadTask: Types.loadTaskFn = (_, ~needsHistory as _, ~onComplete as _) => ()
let _dummyDeleteSession: Types.deleteSessionFn = (_, ~onComplete as _) => ()

let _apiBaseUrl = "http://localhost:4000"

// Helper: base state with an active ACP session (needed to emit effects)
let _makeState = (~selectedModelValue=None, ~pendingProviderAutoSelect=None): Types.state => {
  {
    tasks: Dict.make(),
    currentTask: Types.Task.New(Types.Task.makeNew(~previewUrl="http://localhost:3000")),
    acpSession: AcpSessionActive({
      sendPrompt: _dummySendPrompt,
      cancelPrompt: _dummyCancelPrompt,
      retryTurn: _dummyRetryTurn,
      loadTask: _dummyLoadTask,
      deleteSession: _dummyDeleteSession,
      apiBaseUrl: _apiBaseUrl,
    }),
    sessionInitialized: true,
    userProfile: None,
    openrouterKeySettings: {Types.source: Types.None, saveStatus: Types.Idle},
    anthropicKeySettings: {
      source: Types.None,
      saveStatus: Types.Idle,
    },
    fireworksKeySettings: {Types.source: Types.None, saveStatus: Types.Idle},
    nvidiaKeySettings: {Types.source: Types.None, saveStatus: Types.Idle},
    anthropicOAuthStatus: Types.NotConnected,
    openaiOAuthStatus: Types.OpenAINotConnected,
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
  ): ACP.sessionConfigOption => {
    ACP.SelectConfigOption({
      id: "model",
      name: "Model",
      description: None,
      category: Some(ACP.Model),
      options: ACP.Grouped(groups),
      _meta: None,
    })
  }

  let _anthropicGroup: ACP.sessionConfigSelectGroup = {
    group: "anthropic",
    name: "Anthropic (Claude Pro/Max)",
    options: [
      {
        value: "anthropic:claude-sonnet-4-5",
        name: "Claude Sonnet 4.5",
        description: None,
        _meta: None,
      },
      {value: "anthropic:claude-opus-4-5", name: "Claude Opus 4.5", description: None, _meta: None},
    ],
    _meta: None,
  }

  let _openaiGroup: ACP.sessionConfigSelectGroup = {
    group: "openai_codex",
    name: "OpenAI",
    options: [
      {
        value: "openai_codex:gpt-5.1-codex-max",
        name: "GPT-5.1 Codex Max",
        description: None,
        _meta: None,
      },
      {value: "openai_codex:gpt-5.2", name: "GPT-5.2", description: None, _meta: None},
    ],
    _meta: None,
  }

  let _openrouterGroup: ACP.sessionConfigSelectGroup = {
    group: "openrouter",
    name: "OpenRouter",
    options: [
      {
        value: "openrouter:google/gemini-3-flash-preview",
        name: "Gemini 3 Flash Preview",
        description: None,
        _meta: None,
      },
      {
        value: "openrouter:anthropic/claude-haiku-4.5",
        name: "Claude Haiku 4.5",
        description: None,
        _meta: None,
      },
    ],
    _meta: None,
  }

  let _fireworksGroup: ACP.sessionConfigSelectGroup = {
    group: "fireworks",
    name: "Fireworks AI",
    options: [
      {
        value: "fireworks:accounts/fireworks/routers/kimi-k2p5-turbo",
        name: "Kimi K2.5 Turbo",
        description: None,
        _meta: None,
      },
    ],
    _meta: None,
  }

  let configWithAnthropic = [_makeModelConfigOption(~groups=[_anthropicGroup, _openrouterGroup])]

  let configWithOpenAI = [
    _makeModelConfigOption(~groups=[_openaiGroup, _anthropicGroup, _openrouterGroup]),
  ]

  let configWithOpenRouterOnly = [_makeModelConfigOption(~groups=[_openrouterGroup])]

  let configWithFireworksOnly = [_makeModelConfigOption(~groups=[_fireworksGroup])]
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

  test("InitiateOpenAIOAuth sets pendingProviderAutoSelect to openai_codex", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(state, InitiateOpenAIOAuth)

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("openai_codex"))
  })

  test("SaveApiKey sets pendingProviderAutoSelect for each provider", t => {
    let providerCases: array<(Reducer.apiKeyProvider, string)> = [
      (OpenRouter, "openrouter"),
      (Anthropic, "anthropic"),
      (Fireworks, "fireworks"),
    ]

    providerCases->Array.forEach(
      ((provider, expectedProviderId)) => {
        let (nextState, _effects) = Reducer.next(
          _makeState(),
          SaveApiKey({provider, key: "test-key"}),
        )

        t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some(expectedProviderId))
      },
    )
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

  test("auto-selects first OpenAI model when pendingProviderAutoSelect is openai_codex", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openai_codex"),
      ~selectedModelValue=Some("openrouter:google/gemini-3-flash-preview"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenAI}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("openai_codex:gpt-5.1-codex-max"))
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

  test("auto-selects Fireworks model when pendingProviderAutoSelect is fireworks", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("fireworks"),
      ~selectedModelValue=Some("openrouter:anthropic/claude-haiku-4.5"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithFireworksOnly}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("fireworks:accounts/fireworks/routers/kimi-k2p5-turbo"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("keeps the current selection even when refreshed config omits it", t => {
    let existingModel = "openrouter:google/gemini-3-flash-preview"
    let state = _makeState(~selectedModelValue=Some(existingModel))

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithAnthropic}),
    )

    t->expect(nextState.selectedModelValue)->Expect.toEqual(Some(existingModel))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("selects first model when no selection and no pending provider", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithAnthropic}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("anthropic:claude-sonnet-4-5"))
  })

  test("clears pendingProviderAutoSelect even when provider and current model are missing", t => {
    let existingModel = "openai_codex:gpt-5.1-codex-max"
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openai_codex"),
      ~selectedModelValue=Some(existingModel),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenRouterOnly}),
    )

    t->expect(nextState.selectedModelValue)->Expect.toEqual(Some(existingModel))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })
})
