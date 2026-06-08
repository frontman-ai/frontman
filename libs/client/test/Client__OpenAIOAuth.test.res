open Vitest

module Reducer = Client__State__StateReducer
module Types = Client__State__Types

// Helper to build a state with a specific openaiOAuthStatus
let _makeState = (~openaiOAuthStatus: Types.openaiOAuthStatus): Types.state => {
  {
    tasks: Dict.make(),
    currentTask: Types.Task.New(Types.Task.makeNew(~previewUrl="http://localhost:3000")),
    acpSession: NoAcpSession,
    sessionInitialized: false,
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
    pendingProviderAutoSelect: None,
    sessionsLoadState: Types.SessionsNotLoaded,
    updateInfo: None,
    updateCheckStatus: UpdateNotChecked,
    updateBannerDismissed: false,
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
    // Errors from status fetch / initiate / disconnect don't carry a deviceAuthId.
    // They should apply regardless of current state.
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
    // Simulate: user completed auth (Connected), but an old poll loop dispatches an error.
    let state = _makeState(~openaiOAuthStatus=Types.OpenAIConnected({expiresAt: 99999.0}))

    let (nextState, _effects) = Reducer.next(
      state,
      OpenAIOAuthError({deviceAuthId: Some("old-device"), error: "Authorization timed out."}),
    )

    t->expect(nextState)->Expect.toEqual(state)
    t->expect(_effects->Array.length)->Expect.toBe(0)
  })

  test("OpenAIOAuthConnected is ignored when state is not ShowingCode", t => {
    // Simulate: user disconnected while old poll was running, then old poll returns "connected"
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
    // 1. Start first auth flow
    let state = _makeShowingCodeState(~deviceAuthId="first-device")

    // 2. Simulate "Try again": user restarts flow, server returns new device code.
    //    We skip InitiateOpenAIOAuth (requires AcpSession) and jump straight to
    //    the new device code arriving — the important part is that the reducer
    //    correctly rejects stale results from the first flow.
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

    // 4. Old poll loop times out and dispatches error with first device's ID
    let (state, _) = Reducer.next(
      state,
      OpenAIOAuthError({
        deviceAuthId: Some("first-device"),
        error: "Authorization timed out. Please try again.",
      }),
    )

    // 5. State must STILL be ShowingCode with second-device — NOT Error
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

    // 6. New poll succeeds with correct deviceAuthId
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
