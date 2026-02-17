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
let _makeState = (~anthropicOAuthStatus=Types.NotConnected, ~chatgptOAuthStatus=Types.ChatGPTNotConnected, ~openrouterKeySettings={Types.source: Types.None, saveStatus: Types.Idle}): Types.state => {
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
    openrouterKeySettings,
    anthropicOAuthStatus,
    chatgptOAuthStatus,
    modelsConfig: None,
    selectedModel: None,
    sessionsLoadState: Types.SessionsNotLoaded,
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
