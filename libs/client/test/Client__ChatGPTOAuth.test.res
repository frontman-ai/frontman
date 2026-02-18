open Vitest

module Reducer = Client__State__StateReducer
module Types = Client__State__Types

// Helper to build a state with a specific chatgptOAuthStatus
let _makeState = (~chatgptOAuthStatus: Types.chatgptOAuthStatus): Types.state => {
  {
    tasks: Dict.make(),
    currentTask: Types.Task.New(Types.Task.makeNew(~previewUrl="http://localhost:3000")),
    acpSession: NoAcpSession,
    sessionInitialized: false,
    usageInfo: None,
    userProfile: None,
    openrouterKeySettings: {
      source: Types.None,
      saveStatus: Types.Idle,
    },
    anthropicOAuthStatus: Types.NotConnected,
    chatgptOAuthStatus,
    modelsConfig: None,
    selectedModel: None,
    sessionsLoadState: Types.SessionsNotLoaded,
  }
}

let _makeShowingCodeState = (~deviceAuthId: string): Types.state => {
  _makeState(
    ~chatgptOAuthStatus=Types.ChatGPTShowingCode({
      deviceAuthId,
      userCode: "ABCD-1234",
      verificationUrl: "https://auth.openai.com/codex/device",
    }),
  )
}

describe("ChatGPT OAuth - Stale Poll Rejection", () => {
  test("ChatGPTOAuthConnected with matching deviceAuthId transitions to Connected", t => {
    let state = _makeShowingCodeState(~deviceAuthId="device-123")

    let (nextState, _effects) = Reducer.next(
      state,
      ChatGPTOAuthConnected({deviceAuthId: "device-123", expiresAt: "2026-02-11T00:00:00Z"}),
    )

    switch nextState.chatgptOAuthStatus {
    | Types.ChatGPTConnected(_) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("ChatGPTConnected")->Expect.toBe("got different status")
    }
  })

  test("ChatGPTOAuthConnected with mismatched deviceAuthId is ignored", t => {
    let state = _makeShowingCodeState(~deviceAuthId="device-123")

    let (nextState, _effects) = Reducer.next(
      state,
      ChatGPTOAuthConnected({deviceAuthId: "old-device-456", expiresAt: "2026-02-11T00:00:00Z"}),
    )

    // State should remain ShowingCode with the original deviceAuthId
    switch nextState.chatgptOAuthStatus {
    | Types.ChatGPTShowingCode({deviceAuthId}) =>
      t->expect(deviceAuthId)->Expect.toBe("device-123")
    | _ => t->expect("ChatGPTShowingCode")->Expect.toBe("got different status")
    }
  })

  test("ChatGPTOAuthError with matching deviceAuthId transitions to Error", t => {
    let state = _makeShowingCodeState(~deviceAuthId="device-123")

    let (nextState, _effects) = Reducer.next(
      state,
      ChatGPTOAuthError({deviceAuthId: Some("device-123"), error: "Authorization was declined."}),
    )

    switch nextState.chatgptOAuthStatus {
    | Types.ChatGPTError(msg) =>
      t->expect(msg)->Expect.toBe("Authorization was declined.")
    | _ => t->expect("ChatGPTError")->Expect.toBe("got different status")
    }
  })

  test("ChatGPTOAuthError with mismatched deviceAuthId is ignored", t => {
    let state = _makeShowingCodeState(~deviceAuthId="device-123")

    let (nextState, _effects) = Reducer.next(
      state,
      ChatGPTOAuthError({deviceAuthId: Some("old-device-456"), error: "Authorization timed out."}),
    )

    // State should remain ShowingCode — stale error rejected
    switch nextState.chatgptOAuthStatus {
    | Types.ChatGPTShowingCode({deviceAuthId}) =>
      t->expect(deviceAuthId)->Expect.toBe("device-123")
    | _ => t->expect("ChatGPTShowingCode")->Expect.toBe("got different status")
    }
  })

  test("ChatGPTOAuthError with None deviceAuthId applies unconditionally", t => {
    // Errors from status fetch / initiate / disconnect don't carry a deviceAuthId.
    // They should apply regardless of current state.
    let state = _makeState(~chatgptOAuthStatus=Types.ChatGPTWaitingForCode)

    let (nextState, _effects) = Reducer.next(
      state,
      ChatGPTOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}),
    )

    switch nextState.chatgptOAuthStatus {
    | Types.ChatGPTError(msg) =>
      t->expect(msg)->Expect.toBe("Failed to initiate authentication")
    | _ => t->expect("ChatGPTError")->Expect.toBe("got different status")
    }
  })

  test("ChatGPTOAuthError with Some(id) is ignored when state is already Connected", t => {
    // Simulate: user completed auth (Connected), but an old poll loop dispatches an error.
    let state = _makeState(~chatgptOAuthStatus=Types.ChatGPTConnected({expiresAt: 99999.0}))

    let (nextState, _effects) = Reducer.next(
      state,
      ChatGPTOAuthError({deviceAuthId: Some("old-device"), error: "Authorization timed out."}),
    )

    // Should remain Connected — not overwritten by stale poll error
    switch nextState.chatgptOAuthStatus {
    | Types.ChatGPTConnected(_) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("ChatGPTConnected")->Expect.toBe("got different status")
    }
  })

  test("ChatGPTOAuthConnected is ignored when state is not ShowingCode", t => {
    // Simulate: user disconnected while old poll was running, then old poll returns "connected"
    let state = _makeState(~chatgptOAuthStatus=Types.ChatGPTNotConnected)

    let (nextState, _effects) = Reducer.next(
      state,
      ChatGPTOAuthConnected({deviceAuthId: "old-device", expiresAt: "2026-02-11T00:00:00Z"}),
    )

    // Should remain NotConnected
    switch nextState.chatgptOAuthStatus {
    | Types.ChatGPTNotConnected => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("ChatGPTNotConnected")->Expect.toBe("got different status")
    }
  })
})

describe("ChatGPT OAuth - Retry Flow", () => {
  test("full retry scenario: old poll cannot corrupt new flow", t => {
    // 1. Start first auth flow
    let state = _makeShowingCodeState(~deviceAuthId="first-device")

    // 2. Simulate "Try again": user restarts flow, server returns new device code.
    //    We skip InitiateChatGPTOAuth (requires AcpSession) and jump straight to
    //    the new device code arriving — the important part is that the reducer
    //    correctly rejects stale results from the first flow.
    let (state, _) = Reducer.next(
      state,
      ChatGPTDeviceCodeReceived({
        deviceAuthId: "second-device",
        userCode: "WXYZ-5678",
        verificationUrl: "https://auth.openai.com/codex/device",
      }),
    )

    switch state.chatgptOAuthStatus {
    | Types.ChatGPTShowingCode({deviceAuthId}) =>
      t->expect(deviceAuthId)->Expect.toBe("second-device")
    | _ => JsExn.throw("Expected ChatGPTShowingCode with second-device")
    }

    // 4. Old poll loop times out and dispatches error with first device's ID
    let (state, _) = Reducer.next(
      state,
      ChatGPTOAuthError({
        deviceAuthId: Some("first-device"),
        error: "Authorization timed out. Please try again.",
      }),
    )

    // 5. State must STILL be ShowingCode with second-device — NOT Error
    switch state.chatgptOAuthStatus {
    | Types.ChatGPTShowingCode({deviceAuthId, userCode}) => {
        t->expect(deviceAuthId)->Expect.toBe("second-device")
        t->expect(userCode)->Expect.toBe("WXYZ-5678")
      }
    | _ =>
      t
      ->expect("ChatGPTShowingCode(second-device)")
      ->Expect.toBe("stale error from first flow overwrote state")
    }

    // 6. New poll succeeds with correct deviceAuthId
    let (state, _) = Reducer.next(
      state,
      ChatGPTOAuthConnected({deviceAuthId: "second-device", expiresAt: "2026-12-31T00:00:00Z"}),
    )

    switch state.chatgptOAuthStatus {
    | Types.ChatGPTConnected(_) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("ChatGPTConnected")->Expect.toBe("got different status")
    }
  })
})
