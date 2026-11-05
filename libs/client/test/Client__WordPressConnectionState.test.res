open Vitest

module Reducer = Client__State__StateReducer

afterEach(() => Client__EmbeddedAuth.clearToken())

let checked = (requestId, connected) => Reducer.WordPressConnectionResult({
  requestId,
  action: WordPressConnectionChecked({connected, enabled: true}),
})

test("stale checks and failures cannot reopen approval during or after linking", t => {
  let state = {...Reducer.defaultState, wordPressConnectionRequestId: 2, wordPressConnectionStatus: WordPressLinking}
  let (unchanged, effects) = Reducer.next(state, checked(1, false))
  t->expect(unchanged.wordPressConnectionStatus)->Expect.toEqual(state.wordPressConnectionStatus)
  t->expect(effects->Array.length)->Expect.toBe(0)
  let (linked, _) = Reducer.next(state, checked(2, true))
  let (unchanged, _) = Reducer.next(linked, checked(1, false))
  t->expect(unchanged.wordPressConnectionStatus)->Expect.toEqual(linked.wordPressConnectionStatus)
  let (unchanged, _) = Reducer.next(linked, WordPressConnectionResult({requestId: 1, action: WordPressConnectionFinished("Old failure")}))
  t->expect(unchanged.wordPressConnectionStatus)->Expect.toEqual(linked.wordPressConnectionStatus)
})

test("clearing connection state invalidates pending results", t => {
  let state = {...Reducer.defaultState, wordPressConnectionRequestId: 2}
  let (cleared, _) = Reducer.clearConnectionState(state)
  let (unchanged, _) = Reducer.next(cleared, checked(2, true))
  t->expect(unchanged.wordPressConnectionStatus)->Expect.toEqual(cleared.wordPressConnectionStatus)
  t->expect(cleared.wordPressConnectionRequestId)->Expect.toBe(3)
})

test("access changes block duplicate writes and stale lookups", t => {
  let state = {...Reducer.defaultState, wordPressConnectionRequestId: 2, wordPressConnectionStatus: WordPressLinked({enabled: true})}
  let (saving, effects) = Reducer.next(state, SetWordPressAccess(false))
  t->expect(saving.wordPressConnectionRequestId)->Expect.toBe(3)
  t->expect(switch effects { | [SetWordPressAccessEffect({enabled: false, requestId: 3})] => true | _ => false })->Expect.toBe(true)
  let (_, duplicate) = Reducer.next(saving, SetWordPressAccess(false))
  t->expect(duplicate->Array.length)->Expect.toBe(0)
  let (_, checks) = Reducer.next(saving, FetchWordPressConnection)
  t->expect(checks->Array.length)->Expect.toBe(0)
  let (unchanged, _) = Reducer.next(saving, checked(2, true))
  t->expect(unchanged.wordPressConnectionStatus)->Expect.toEqual(saving.wordPressConnectionStatus)
})

test("completion replaces old account data with a neutral failure", t => {
  Client__EmbeddedAuth.saveToken("account-a")
  let token = Client__EmbeddedAuth.loadToken()
  let state = ref({...Reducer.defaultState, wordPressConnectionRequestId: 1, wordPressConnectionStatus: WordPressChecking})
  let dispatch = action => {
    let (next, _) = Reducer.next(state.contents, action)
    state := next
  }
  Client__EmbeddedAuth.saveToken("account-b")
  Reducer.dispatchWordPressConnectionResult(dispatch, token, 1, WordPressConnectionFinished("Old failure"))
  t->expect(state.contents.wordPressConnectionStatus)->Expect.toEqual(
    Client__State__Types.WordPressConnectionFailed("Your Frontman sign-in changed. Check the connection again."),
  )
})

test("token replacement or removal after approval preserves the cleanup warning", t => {
  [true, false]->Array.forEach(replace => {
    Client__EmbeddedAuth.saveToken("account-a")
    let token = Client__EmbeddedAuth.loadToken()
    let state = ref({...Reducer.defaultState, wordPressConnectionRequestId: 1, wordPressConnectionStatus: WordPressLinking})
    let dispatch = action => {
      let (next, _) = Reducer.next(state.contents, action)
      state := next
    }
    if replace { Client__EmbeddedAuth.saveToken("account-b") } else { Client__EmbeddedAuth.clearToken() }
    Reducer.dispatchWordPressConnectionResult(
      dispatch, token, 1, WordPressConnectionFinished("account-specific failure"), ~credentialRisk=true,
    )
    t->expect(state.contents.wordPressCredentialWarning)->Expect.toBe(true)
    t->expect(state.contents.wordPressConnectionStatus)->Expect.toEqual(
      Client__State__Types.WordPressConnectionFailed("Your Frontman sign-in changed. Check the connection again."),
    )
  })
})

test("connection reset blocks overlapping approval until the old completion settles", t => {
  Client__EmbeddedAuth.saveToken("account-a")
  let token = Client__EmbeddedAuth.loadToken()
  let state = ref({...Reducer.defaultState, wordPressConnectionRequestId: 1, wordPressConnectionStatus: WordPressLinking, wordPressPendingApproval: Some(1)})
  let (cleared, _) = Reducer.clearConnectionState(state.contents)
  t->expect(cleared.wordPressPendingApproval)->Expect.toBe(Some(1))
  state := {...cleared, wordPressConnectionStatus: WordPressUnlinked}
  let (blocked, effects) = Reducer.next(state.contents, ConnectWordPress)
  t->expect(effects->Array.length)->Expect.toBe(0)
  t->expect(blocked.wordPressConnectionStatus)->Expect.toEqual(Client__State__Types.WordPressUnlinked)
  Client__EmbeddedAuth.clearToken()
  let dispatch = action => {
    let (next, _) = Reducer.next(state.contents, action)
    state := next
  }
  Reducer.dispatchWordPressConnectionResult(
    dispatch, token, 1, WordPressConnectionChecked({connected: true, enabled: true}), ~credentialRisk=true,
  )
  t->expect(state.contents.wordPressCredentialWarning)->Expect.toBe(true)
  t->expect(state.contents.wordPressPendingApproval)->Expect.toBe(None)
  t->expect(state.contents.wordPressConnectionStatus)->Expect.toEqual(
    Client__State__Types.WordPressConnectionFailed("A previous connection attempt finished. Check the connection again."),
  )
  let (afterOldCheck, _) = Reducer.next(state.contents, checked(2, false))
  t->expect(afterOldCheck.wordPressConnectionStatus)->Expect.toEqual(state.contents.wordPressConnectionStatus)
})

test("an unrelated completion cannot release a pending approval", t => {
  let state = {...Reducer.defaultState, wordPressConnectionRequestId: 4, wordPressPendingApproval: Some(4), wordPressConnectionStatus: WordPressLinking}
  let (next, _) = Reducer.next(state, WordPressConnectionCompletion({
    requestId: 3,
    action: WordPressConnectionFinished("stale"),
    credentialRisk: false,
  }))
  t->expect(next.wordPressPendingApproval)->Expect.toBe(Some(4))
  t->expect(next.wordPressConnectionStatus)->Expect.toEqual(state.wordPressConnectionStatus)
})
