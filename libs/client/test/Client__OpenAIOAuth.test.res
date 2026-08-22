open Vitest

module Reducer = Client__State__StateReducer
module Types = Client__State__Types

let _makeState = (~openaiOAuthStatus: Types.openaiOAuthStatus): Types.state => {
  {
    tasks: Dict.make(),
    currentTask: Types.Task.New(Types.Task.makeNew(~previewUrl="http://localhost:3000")),
    acpSession: NoAcpSession,
    userProfile: None,
    openrouterKeySettings: {
      source: Types.None,
      saveStatus: Types.Idle,
    },
    anthropicKeySettings: {
      source: Types.None,
      saveStatus: Types.Idle,
    },
    fireworksKeySettings: {
      source: Types.None,
      saveStatus: Types.Idle,
    },
    nvidiaKeySettings: {
      source: Types.None,
      saveStatus: Types.Idle,
    },
    anthropicOAuthStatus: Types.NotConnected,
    openaiOAuthStatus,
    configOptions: None,
    selectedModelValue: None,
    agentCatalog: None,
    selectedAgentId: None,
    pendingProviderAutoSelect: None,
    sessionsLoadState: Types.SessionsNotLoaded,
    updateInfo: None,
    updateCheckStatus: UpdateNotChecked,
    updateBannerDismissed: false,
    customEndpoints: None,
  }
}

let _makeShowingCodeState = (~deviceAuthId: string): Types.state => {
  _makeState(
    ~openaiOAuthStatus=Types.OpenAIShowingCode({
      deviceAuthId,
      userCode: "ABCD-1234",
      verificationUrl: "https://auth.openai.com/codex/device",
    }),
  )
}

describe("OpenAI OAuth - Stale Poll Rejection", () => {
  test("OpenAIOAuthConnected with matching deviceAuthId transitions to Connected", t => {
    let state = _makeShowingCodeState(~deviceAuthId="device-123")

    let (nextState, _effects) = Reducer.next(
      state,
      OpenAIOAuthConnected({deviceAuthId: "device-123", expiresAt: "2026-02-11T00:00:00Z"}),
    )

    switch nextState.openaiOAuthStatus {
    | Types.OpenAIConnected({expiresAt}) => {
        t->expect(expiresAt)->Expect.toBe(Date.fromString("2026-02-11T00:00:00Z")->Date.getTime)
        t->expect(_effects->Array.length)->Expect.toBe(0)
      }
    | _ => t->expect("OpenAIConnected")->Expect.toBe("got different status")
    }
  })

  test("OpenAIOAuthConnected with mismatched deviceAuthId is ignored", t => {
    let state = _makeShowingCodeState(~deviceAuthId="device-123")

    let (nextState, _effects) = Reducer.next(
      state,
      OpenAIOAuthConnected({deviceAuthId: "old-device-456", expiresAt: "2026-02-11T00:00:00Z"}),
    )

    t->expect(nextState)->Expect.toEqual(state)
    t->expect(_effects->Array.length)->Expect.toBe(0)
  })

  test("OpenAIOAuthError with matching deviceAuthId transitions to Error", t => {
    let state = _makeShowingCodeState(~deviceAuthId="device-123")

    let (nextState, _effects) = Reducer.next(
      state,
      OpenAIOAuthError({deviceAuthId: Some("device-123"), error: "Authorization was declined."}),
    )

    switch nextState.openaiOAuthStatus {
    | Types.OpenAIError(msg) => t->expect(msg)->Expect.toBe("Authorization was declined.")
    | _ => t->expect("OpenAIError")->Expect.toBe("got different status")
    }
  })

  test("OpenAIOAuthError with mismatched deviceAuthId is ignored", t => {
    let state = _makeShowingCodeState(~deviceAuthId="device-123")

    let (nextState, _effects) = Reducer.next(
      state,
      OpenAIOAuthError({deviceAuthId: Some("old-device-456"), error: "Authorization timed out."}),
    )

    t->expect(nextState)->Expect.toEqual(state)
    t->expect(_effects->Array.length)->Expect.toBe(0)
  })

  test("OpenAIOAuthError with None deviceAuthId applies unconditionally", t => {
    let state = _makeState(~openaiOAuthStatus=Types.OpenAIWaitingForCode)

    let (nextState, _effects) = Reducer.next(
      state,
      OpenAIOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}),
    )

    switch nextState.openaiOAuthStatus {
    | Types.OpenAIError(msg) => t->expect(msg)->Expect.toBe("Failed to initiate authentication")
    | _ => t->expect("OpenAIError")->Expect.toBe("got different status")
    }
  })

  test("OpenAIOAuthError with Some(id) is ignored when state is already Connected", t => {
    let state = _makeState(~openaiOAuthStatus=Types.OpenAIConnected({expiresAt: 99999.0}))

    let (nextState, _effects) = Reducer.next(
      state,
      OpenAIOAuthError({deviceAuthId: Some("old-device"), error: "Authorization timed out."}),
    )

    t->expect(nextState)->Expect.toEqual(state)
    t->expect(_effects->Array.length)->Expect.toBe(0)
  })

  test("OpenAIOAuthConnected is ignored when state is not ShowingCode", t => {
    let state = _makeState(~openaiOAuthStatus=Types.OpenAINotConnected)

    let (nextState, _effects) = Reducer.next(
      state,
      OpenAIOAuthConnected({deviceAuthId: "old-device", expiresAt: "2026-02-11T00:00:00Z"}),
    )

    t->expect(nextState)->Expect.toEqual(state)
    t->expect(_effects->Array.length)->Expect.toBe(0)
  })
})

describe("OpenAI OAuth - Retry Flow", () => {
  test("full retry scenario: old poll cannot corrupt new flow", t => {
    let state = _makeShowingCodeState(~deviceAuthId="first-device")

    let (state, _) = Reducer.next(
      state,
      OpenAIDeviceCodeReceived({
        deviceAuthId: "second-device",
        userCode: "WXYZ-5678",
        verificationUrl: "https://auth.openai.com/codex/device",
      }),
    )

    switch state.openaiOAuthStatus {
    | Types.OpenAIShowingCode({deviceAuthId}) =>
      t->expect(deviceAuthId)->Expect.toBe("second-device")
    | _ => JsExn.throw("Expected OpenAIShowingCode with second-device")
    }

    let (state, _) = Reducer.next(
      state,
      OpenAIOAuthError({
        deviceAuthId: Some("first-device"),
        error: "Authorization timed out. Please try again.",
      }),
    )

    switch state.openaiOAuthStatus {
    | Types.OpenAIShowingCode({deviceAuthId, userCode}) => {
        t->expect(deviceAuthId)->Expect.toBe("second-device")
        t->expect(userCode)->Expect.toBe("WXYZ-5678")
      }
    | _ =>
      t
      ->expect("OpenAIShowingCode(second-device)")
      ->Expect.toBe("stale error from first flow overwrote state")
    }

    let (state, _) = Reducer.next(
      state,
      OpenAIOAuthConnected({deviceAuthId: "second-device", expiresAt: "2026-12-31T00:00:00Z"}),
    )

    switch state.openaiOAuthStatus {
    | Types.OpenAIConnected({expiresAt}) =>
      t->expect(expiresAt)->Expect.toBe(Date.fromString("2026-12-31T00:00:00Z")->Date.getTime)
    | _ => t->expect("OpenAIConnected")->Expect.toBe("got different status")
    }
  })
})
