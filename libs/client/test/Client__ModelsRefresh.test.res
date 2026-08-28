open Vitest

module Reducer = Client__State__StateReducer
module Types = Client__State__Types
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

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

let _makeState = (~selectedModelValue=None, ~pendingProviderAutoSelect=None): Types.state => {
  ...Reducer.defaultState,
  acpSession: AcpSessionActive({
    sendPrompt: _dummySendPrompt,
    cancelPrompt: _dummyCancelPrompt,
    retryTurn: _dummyRetryTurn,
    loadTask: _dummyLoadTask,
    deleteSession: _dummyDeleteSession,
    apiBaseUrl: _apiBaseUrl,
  }),
  selectedModelValue,
  pendingProviderAutoSelect,
}

module SampleConfig = {
  let _makeOption = ((name, value)): ACP.sessionConfigSelectOption => {
    value,
    name,
    description: None,
    _meta: None,
  }

  let _makeGroup = (~group, ~name, ~models): ACP.sessionConfigSelectGroup => {
    group,
    name,
    options: models->Array.map(_makeOption),
    _meta: None,
  }

  let _makeModelConfigOption = (options: ACP.sessionConfigSelectOptions) => {
    ACP.SelectConfigOption({
      id: "model",
      name: "Model",
      description: None,
      category: Some(ACP.Model),
      options,
      _meta: None,
    })
  }

  let _anthropicGroup = _makeGroup(
    ~group="anthropic",
    ~name="Anthropic (Claude Pro/Max)",
    ~models=[
      ("Claude Sonnet 5", "anthropic:claude-sonnet-5"),
      ("Claude Fable 5", "anthropic:claude-fable-5"),
    ],
  )

  let _openaiGroup = _makeGroup(
    ~group="openai_codex",
    ~name="OpenAI",
    ~models=[
      ("GPT-5.6 Terra", "openai_codex:gpt-5.6-terra"),
      ("GPT-5.6 Sol", "openai_codex:gpt-5.6-sol"),
    ],
  )

  let _openrouterGroup = _makeGroup(
    ~group="openrouter",
    ~name="OpenRouter",
    ~models=[
      ("GPT-5.6 Terra", "openrouter:openai/gpt-5.6-terra"),
      ("Claude Haiku 4.5", "openrouter:anthropic/claude-haiku-4.5"),
    ],
  )

  let _fireworksGroup = _makeGroup(
    ~group="fireworks_ai",
    ~name="Fireworks AI",
    ~models=[("Kimi K2.5 Turbo", "fireworks_ai:accounts/fireworks/routers/kimi-k2p5-turbo")],
  )

  let configWithAnthropic = [
    _makeModelConfigOption(ACP.Grouped([_anthropicGroup, _openrouterGroup])),
  ]

  let configWithOpenAI = [
    _makeModelConfigOption(ACP.Grouped([_openaiGroup, _anthropicGroup, _openrouterGroup])),
  ]

  let configWithOpenRouterOnly = [_makeModelConfigOption(ACP.Grouped([_openrouterGroup]))]

  let configWithFireworksOnly = [_makeModelConfigOption(ACP.Grouped([_fireworksGroup]))]

  let configWithNoModels = [_makeModelConfigOption(ACP.Grouped([]))]

  let configWithEmptyFirstGroup = [
    _makeModelConfigOption(ACP.Grouped([{..._anthropicGroup, options: []}, _openrouterGroup])),
  ]

  let configWithUngroupedModels = [
    _makeModelConfigOption(ACP.Ungrouped([_makeOption(("Future Model", "future_provider:model"))])),
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

  test("InitiateOpenAIOAuth sets pendingProviderAutoSelect to openai_codex", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(state, InitiateOpenAIOAuth)

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("openai_codex"))
  })

  test("SaveApiKey sets pendingProviderAutoSelect for each provider", t => {
    let providerCases: array<(Reducer.apiKeyProvider, string)> = [
      (OpenRouter, "openrouter"),
      (Anthropic, "anthropic"),
      (Fireworks, "fireworks_ai"),
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
  test("selects first available grouped or ungrouped model", t => {
    let cases: array<(Reducer.action, string)> = [
      (
        ConfigOptionsReceived({configOptions: SampleConfig.configWithEmptyFirstGroup}),
        "openrouter:openai/gpt-5.6-terra",
      ),
      (
        ConfigOptionsReceived({configOptions: SampleConfig.configWithUngroupedModels}),
        "future_provider:model",
      ),
    ]
    cases->Array.forEach(
      ((action, expected)) => {
        let (nextState, _effects) = Reducer.next(_makeState(), action)
        t->expect(nextState.selectedModelValue)->Expect.toEqual(Some(expected))
      },
    )
  })

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
    ->Expect.toEqual(Some("anthropic:claude-sonnet-5"))
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
    ->Expect.toEqual(Some("openai_codex:gpt-5.6-terra"))
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
    ->Expect.toEqual(Some("openrouter:openai/gpt-5.6-terra"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("auto-selects Fireworks model when pendingProviderAutoSelect is fireworks_ai", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("fireworks_ai"),
      ~selectedModelValue=Some("openrouter:anthropic/claude-haiku-4.5"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithFireworksOnly}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("fireworks_ai:accounts/fireworks/routers/kimi-k2p5-turbo"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("replaces a selected model removed by refreshed config", t => {
    let existingModel = "openrouter:google/gemini-3-flash-preview"
    let state = _makeState(~selectedModelValue=Some(existingModel))
    let storage = WebAPI.Window.current->WebAPI.Window.localStorage
    storage->WebAPI.Storage.setItem(~key="frontman:selectedModelValue", ~value=existingModel)

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenRouterOnly}),
    )

    let replacement = "openrouter:openai/gpt-5.6-terra"
    t->expect(nextState.selectedModelValue)->Expect.toEqual(Some(replacement))
    t
    ->expect(storage->WebAPI.Storage.getItem("frontman:selectedModelValue")->Null.toOption)
    ->Expect.toEqual(Some(replacement))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("clears a selection whose provider was removed", t => {
    let existingModel = "custom:provider-id:model-id"
    let state = _makeState(~selectedModelValue=Some(existingModel))
    let storage = WebAPI.Window.current->WebAPI.Window.localStorage
    storage->WebAPI.Storage.setItem(~key="frontman:selectedModelValue", ~value=existingModel)

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithNoModels}),
    )

    t->expect(nextState.selectedModelValue)->Expect.toEqual(None)
    t
    ->expect(storage->WebAPI.Storage.getItem("frontman:selectedModelValue")->Null.toOption)
    ->Expect.toEqual(None)
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
    ->Expect.toEqual(Some("anthropic:claude-sonnet-5"))
  })

  test("falls back to the first model when pending provider and current model are missing", t => {
    let existingModel = "openai_codex:gpt-5.1-codex-max"
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openai_codex"),
      ~selectedModelValue=Some(existingModel),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenRouterOnly}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("openrouter:openai/gpt-5.6-terra"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("accepts empty model config when no providers are configured", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithNoModels}),
    )

    t->expect(nextState.selectedModelValue)->Expect.toEqual(None)
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })
})
