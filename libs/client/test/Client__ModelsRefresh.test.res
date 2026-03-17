open Vitest

module Reducer = Client__State__StateReducer
module Types = Client__State__Types

// Dummy callbacks for AcpSessionActive (reducer only checks the variant, not the callbacks)
let _dummySendPrompt: Types.sendPromptFn = (_, ~additionalBlocks as _, ~onComplete as _, ~metadata as _) => ()
let _dummyCancelPrompt: Types.cancelPromptFn = () => ()
let _dummyLoadTask: Types.loadTaskFn = (_, ~needsHistory as _, ~onComplete as _) => ()
let _dummyDeleteSession: Types.deleteSessionFn = (_, ~onComplete as _) => ()

let _apiBaseUrl = "http://localhost:4000"

// Helper: base state with an active ACP session (needed to emit effects)
let _makeState = (~anthropicOAuthStatus=Types.NotConnected, ~chatgptOAuthStatus=Types.ChatGPTNotConnected, ~openrouterKeySettings={Types.source: Types.None, saveStatus: Types.Idle}, ~selectedModel=None, ~pendingProviderAutoSelect=None): Types.state => {
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
    modelsConfig: None,
    selectedModel,
    pendingProviderAutoSelect,
    sessionsLoadState: Types.SessionsNotLoaded,
    updateInfo: None,
    updateCheckStatus: UpdateNotChecked,
    updateBannerDismissed: false,
  }
}

// Helper: check if effects contain FetchModelsConfigEffect
let _hasFetchModelsEffect = (effects: array<Reducer.effect>): bool => {
  effects->Array.some(effect =>
    switch effect {
    | FetchModelsConfigEffect(_) => true
    | _ => false
    }
  )
}

describe("Models list refresh on provider connect/disconnect", () => {
  // ============================================================================
  // Anthropic OAuth
  // ============================================================================

  test("AnthropicOAuthConnected triggers model refresh", t => {
    let state = _makeState()

    let (_nextState, effects) = Reducer.next(
      state,
      AnthropicOAuthConnected({expiresAt: "2026-12-31T00:00:00Z"}),
    )

    t->expect(_hasFetchModelsEffect(effects))->Expect.toBe(true)
  })

  test("AnthropicOAuthDisconnected triggers model refresh", t => {
    let state = _makeState(~anthropicOAuthStatus=Types.Connected({expiresAt: 99999.0}))

    let (_nextState, effects) = Reducer.next(state, AnthropicOAuthDisconnected)

    t->expect(_hasFetchModelsEffect(effects))->Expect.toBe(true)
  })

  // ============================================================================
  // ChatGPT OAuth
  // ============================================================================

  test("ChatGPTOAuthConnected triggers model refresh", t => {
    let state = _makeState(
      ~chatgptOAuthStatus=Types.ChatGPTShowingCode({
        deviceAuthId: "device-1",
        userCode: "ABCD-1234",
        verificationUrl: "https://auth.openai.com/codex/device",
      }),
    )

    let (_nextState, effects) = Reducer.next(
      state,
      ChatGPTOAuthConnected({deviceAuthId: "device-1", expiresAt: "2026-12-31T00:00:00Z"}),
    )

    t->expect(_hasFetchModelsEffect(effects))->Expect.toBe(true)
  })

  test("ChatGPTOAuthDisconnected triggers model refresh", t => {
    let state = _makeState(~chatgptOAuthStatus=Types.ChatGPTConnected({expiresAt: 99999.0}))

    let (_nextState, effects) = Reducer.next(state, ChatGPTOAuthDisconnected)

    t->expect(_hasFetchModelsEffect(effects))->Expect.toBe(true)
  })

  // ============================================================================
  // OpenRouter key save
  // ============================================================================

  test("OpenRouterKeySaved triggers model refresh", t => {
    let state = _makeState()

    let (_nextState, effects) = Reducer.next(state, OpenRouterKeySaved)

    t->expect(_hasFetchModelsEffect(effects))->Expect.toBe(true)
  })
})

describe("Models list refresh requires active ACP session", () => {
  test("AnthropicOAuthConnected without ACP session emits no effects", t => {
    let state = {
      ..._makeState(),
      acpSession: NoAcpSession,
    }

    let (_nextState, effects) = Reducer.next(
      state,
      AnthropicOAuthConnected({expiresAt: "2026-12-31T00:00:00Z"}),
    )

    t->expect(_hasFetchModelsEffect(effects))->Expect.toBe(false)
  })

  test("OpenRouterKeySaved without ACP session emits no model refresh", t => {
    let state = {
      ..._makeState(),
      acpSession: NoAcpSession,
    }

    let (_nextState, effects) = Reducer.next(state, OpenRouterKeySaved)

    t->expect(_hasFetchModelsEffect(effects))->Expect.toBe(false)
  })
})

// ============================================================================
// Auto-select default model from newly connected provider
// ============================================================================

module SampleConfig = {
  let anthropicProvider: Types.providerConfig = {
    id: "anthropic",
    name: "Anthropic (Claude Pro/Max)",
    models: [
      {displayName: "Claude Sonnet 4.5", value: "claude-sonnet-4-5"},
      {displayName: "Claude Opus 4.5", value: "claude-opus-4-5"},
    ],
  }
  let openaiProvider: Types.providerConfig = {
    id: "openai",
    name: "ChatGPT Pro/Plus",
    models: [
      {displayName: "GPT-5.1 Codex Max", value: "gpt-5.1-codex-max"},
      {displayName: "GPT-5.2", value: "gpt-5.2"},
    ],
  }
  let openrouterProvider: Types.providerConfig = {
    id: "openrouter",
    name: "OpenRouter",
    models: [
      {displayName: "Gemini 3 Flash Preview", value: "google/gemini-3-flash-preview"},
      {displayName: "Claude Haiku 4.5", value: "anthropic/claude-haiku-4.5"},
    ],
  }
  let configWithAnthropic: Types.modelsConfig = {
    providers: [anthropicProvider, openrouterProvider],
    defaultModel: {provider: "anthropic", value: "claude-sonnet-4-5"},
  }
  let configWithOpenAI: Types.modelsConfig = {
    providers: [openaiProvider, anthropicProvider, openrouterProvider],
    defaultModel: {provider: "openai", value: "gpt-5.1-codex-max"},
  }
  let configWithOpenRouterOnly: Types.modelsConfig = {
    providers: [openrouterProvider],
    defaultModel: {provider: "openrouter", value: "google/gemini-3-flash-preview"},
  }
}

describe("Provider connect sets pendingProviderAutoSelect", () => {
  test("AnthropicOAuthConnected sets pendingProviderAutoSelect to anthropic", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      AnthropicOAuthConnected({expiresAt: "2026-12-31T00:00:00Z"}),
    )

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("anthropic"))
  })

  test("ChatGPTOAuthConnected sets pendingProviderAutoSelect to openai", t => {
    let state = _makeState(
      ~chatgptOAuthStatus=Types.ChatGPTShowingCode({
        deviceAuthId: "device-1",
        userCode: "ABCD-1234",
        verificationUrl: "https://auth.openai.com/codex/device",
      }),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ChatGPTOAuthConnected({deviceAuthId: "device-1", expiresAt: "2026-12-31T00:00:00Z"}),
    )

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("openai"))
  })

  test("OpenRouterKeySaved sets pendingProviderAutoSelect to openrouter", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(state, OpenRouterKeySaved)

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("openrouter"))
  })
})

describe("ModelsConfigReceived auto-selects model from newly connected provider", () => {
  test("auto-selects first Anthropic model when pendingProviderAutoSelect is anthropic", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("anthropic"),
      ~selectedModel=Some({provider: "openrouter", value: "google/gemini-3-flash-preview"}),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ModelsConfigReceived({config: SampleConfig.configWithAnthropic}),
    )

    t
    ->expect(nextState.selectedModel)
    ->Expect.toEqual(Some({provider: "anthropic", value: "claude-sonnet-4-5"}))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("auto-selects first OpenAI model when pendingProviderAutoSelect is openai", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openai"),
      ~selectedModel=Some({provider: "openrouter", value: "google/gemini-3-flash-preview"}),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ModelsConfigReceived({config: SampleConfig.configWithOpenAI}),
    )

    t
    ->expect(nextState.selectedModel)
    ->Expect.toEqual(Some({provider: "openai", value: "gpt-5.1-codex-max"}))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("auto-selects first OpenRouter model when pendingProviderAutoSelect is openrouter", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openrouter"),
      ~selectedModel=Some({provider: "openrouter", value: "anthropic/claude-haiku-4.5"}),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ModelsConfigReceived({config: SampleConfig.configWithOpenRouterOnly}),
    )

    t
    ->expect(nextState.selectedModel)
    ->Expect.toEqual(Some({provider: "openrouter", value: "google/gemini-3-flash-preview"}))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("keeps current selection when no pending provider auto-select", t => {
    let existingModel: Types.modelSelection = {
      provider: "openrouter",
      value: "google/gemini-3-flash-preview",
    }
    let state = _makeState(~selectedModel=Some(existingModel))

    let (nextState, _effects) = Reducer.next(
      state,
      ModelsConfigReceived({config: SampleConfig.configWithAnthropic}),
    )

    t->expect(nextState.selectedModel)->Expect.toEqual(Some(existingModel))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("falls back to server default when no selection and no pending provider", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      ModelsConfigReceived({config: SampleConfig.configWithAnthropic}),
    )

    t
    ->expect(nextState.selectedModel)
    ->Expect.toEqual(Some({provider: "anthropic", value: "claude-sonnet-4-5"}))
  })

  test("clears pendingProviderAutoSelect even if provider not in config", t => {
    let existingModel: Types.modelSelection = {
      provider: "openrouter",
      value: "google/gemini-3-flash-preview",
    }
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openai"),
      ~selectedModel=Some(existingModel),
    )

    // Config doesn't have OpenAI provider — keep existing selection
    let (nextState, _effects) = Reducer.next(
      state,
      ModelsConfigReceived({config: SampleConfig.configWithOpenRouterOnly}),
    )

    t->expect(nextState.selectedModel)->Expect.toEqual(Some(existingModel))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })
})
