open Vitest

module Reducer = Client__State__StateReducer
module Protocol = Client__State__Protocol
module Initialization = Client__State__Initialization
module WordPressEffects = Client__State__WordPressEffects

afterEach(() => Client__EmbeddedAuth.clearToken())

let reduce = (state, action) => Reducer.next(state, action)->Pair.first
let completion = (requestId, result, ~credentialRisk=false) =>
  Protocol.WordPressConnectionCompletion({requestId, result, credentialRisk})
let checked = connected => {
  let connection: Protocol.wordPressConnection = {connected, enabled: true}
  Ok(connection)
}

test("stale completions cannot replace a linking or linked status", t => {
  let state = {...Initialization.defaultState, wordPressConnectionRequestId: 2, wordPressConnectionStatus: WordPressLinking}
  let state = reduce(state, completion(1, checked(false)))
  t->expect(state.wordPressConnectionStatus)->Expect.toEqual(Client__State__Types.WordPressLinking)
  let state = reduce(state, completion(2, checked(true)))
  let state = reduce(state, completion(1, Error(WordPressRequestFailed("Old failure"))))
  t->expect(state.wordPressConnectionStatus)->Expect.toEqual(Client__State__Types.WordPressLinked({enabled: true}))
})

test("completion preserves credential risk and authenticates only the current account", t => {
  [
    (Some("account-b"), Protocol.WordPressRequestFailed("Old failure"), true),
    (None, WordPressRequestFailed("Old failure"), true),
    (Some("account-b"), WordPressRequestFailed("Old failure"), false),
    (Some("account-b"), WordPressAuthRequired, false),
    (Some("account-a"), WordPressAuthRequired, false),
  ]->Array.forEach(((nextToken, error, credentialRisk)) => {
    Client__EmbeddedAuth.saveToken("account-a")
    let token = Client__EmbeddedAuth.loadToken()
    switch nextToken {
    | Some(token) => Client__EmbeddedAuth.saveToken(token)
    | None => Client__EmbeddedAuth.clearToken()
    }
    let current = nextToken == token
    let state = ref({...Initialization.defaultState, wordPressConnectionRequestId: 1, wordPressConnectionStatus: WordPressChecking})
    let required = ref(false)
    WordPressEffects.completeWordPressRequest(
      action => {
        switch action {
        | Protocol.ConnectionAction(RequireAuthentication) => required := true
        | _ => ()
        }
        state := reduce(state.contents, action)
      },
      token, 1, Error(error), ~credentialRisk,
    )
    t->expect(state.contents.wordPressCredentialWarning)->Expect.toBe(credentialRisk)
    t->expect(required.contents)->Expect.toBe(current)
    t->expect(Client__EmbeddedAuth.loadToken())->Expect.toEqual(current ? None : nextToken)
    t->expect(state.contents.wordPressConnectionStatus)->Expect.toEqual(
      Client__State__Types.WordPressConnectionFailed(current
        ? "Your Frontman session expired. Sign in again."
        : "Frontman sign-in changed. Check again."),
    )
  })
})

test("reset retains mutation identity and never publishes its stale snapshot", t => {
  [Client__State__Types.WordPressLinking, WordPressUpdatingAccess({enabled: true})]->Array.forEach(status => {
    let state = {...Initialization.defaultState, wordPressConnectionRequestId: 1, wordPressConnectionStatus: status, wordPressPendingMutation: Some(1)}
    let state = reduce(state, ConnectionAction(Dispose))
    t->expect(state.wordPressConnectionRequestId)->Expect.toBe(2)
    t->expect(state.wordPressPendingMutation)->Expect.toEqual(Some(1))
    let state = reduce(state, completion(2, Error(WordPressRequestFailed("unrelated"))))
    t->expect(state.wordPressPendingMutation)->Expect.toEqual(Some(1))
    let (state, effects) = Reducer.next(state, completion(1, checked(true), ~credentialRisk=true))
    t->expect(effects)->Expect.toEqual([])
    t->expect(state.wordPressPendingMutation)->Expect.toEqual(None)
    t->expect(state.wordPressCredentialWarning)->Expect.toBe(true)
    t->expect(state.wordPressConnectionStatus)->Expect.toEqual(Client__State__Types.WordPressNotChecked)
  })
})

test("only definitive approval rejections clear credential risk", t => {
  [
    (Some("frontman_invalid_nonce"), None, false),
    (Some("frontman_password_creation_failed"), None, false),
    (None, None, true),
    (Some("unknown_failure"), None, true),
    (Some("frontman_invalid_nonce"), Some(true), true),
    (None, Some(false), false),
  ]->Array.forEach(((code, credential_created, risk)) =>
    t->expect(Client__State__Types.wordPressCredentialRisk({error: "Rejected", code, credential_created}))->Expect.toBe(risk)
  )
})
