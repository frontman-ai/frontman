open Vitest

module Reducer = Client__State__StateReducer

afterEach(() => Client__EmbeddedAuth.clearToken())

// These cases supply completions to test ordering after a request is already
// pending. The browser runtime test covers actual HTTP and credential creation.
let store = state => StateStore.make(module(Reducer), state)
let complete = (store, requestId, action, ~credentialRisk=false) =>
  store->StateStore.dispatch(Reducer.WordPressConnectionCompletion({requestId, action, credentialRisk}))
let checked = connected => Reducer.WordPressConnectionChecked({connected, enabled: true})

test("stale completions cannot replace a linking or linked status", t => {
  let store = store({...Reducer.defaultState, wordPressConnectionRequestId: 2, wordPressConnectionStatus: WordPressLinking})
  complete(store, 1, checked(false))
  t->expect((store->StateStore.getState).wordPressConnectionStatus)->Expect.toEqual(Client__State__Types.WordPressLinking)
  complete(store, 2, checked(true))
  complete(store, 1, Reducer.WordPressConnectionFinished("Old failure"))
  t->expect((store->StateStore.getState).wordPressConnectionStatus)->Expect.toEqual(Client__State__Types.WordPressLinked({enabled: true}))
})

test("updates reject overlapping writes, checks and stale completions", t => {
  let status = Client__State__Types.WordPressUpdatingAccess({enabled: true})
  let store = store({...Reducer.defaultState, wordPressConnectionRequestId: 3, wordPressConnectionStatus: status})
  store->StateStore.dispatch(Reducer.SetWordPressAccess(false))
  store->StateStore.dispatch(Reducer.FetchWordPressConnection)
  complete(store, 2, checked(true))
  t->expect((store->StateStore.getState).wordPressConnectionStatus)->Expect.toEqual(status)
  t->expect((store->StateStore.getState).wordPressConnectionRequestId)->Expect.toBe(3)
})

test("account changes replace old results and preserve supplied credential risk", t => {
  [true, false]->Array.forEach(replace => {
    Client__EmbeddedAuth.saveToken("account-a")
    let token = Client__EmbeddedAuth.loadToken()
    let store = store({...Reducer.defaultState, wordPressConnectionRequestId: 1, wordPressConnectionStatus: WordPressLinking})
    if replace { Client__EmbeddedAuth.saveToken("account-b") } else { Client__EmbeddedAuth.clearToken() }
    Reducer.dispatchWordPressConnectionResult(
      action => store->StateStore.dispatch(action), token, 1,
      WordPressConnectionFinished("account-specific failure"), ~credentialRisk=true,
    )
    t->expect((store->StateStore.getState).wordPressCredentialWarning)->Expect.toBe(true)
    t->expect((store->StateStore.getState).wordPressConnectionStatus)->Expect.toEqual(
      Client__State__Types.WordPressConnectionFailed("Your Frontman sign-in changed. Check the connection again."),
    )
  })
})

test("account changes also neutralize ordinary check failures", t => {
  Client__EmbeddedAuth.saveToken("account-a")
  let token = Client__EmbeddedAuth.loadToken()
  let store = store({...Reducer.defaultState, wordPressConnectionRequestId: 1, wordPressConnectionStatus: WordPressChecking})
  Client__EmbeddedAuth.saveToken("account-b")
  Reducer.dispatchWordPressConnectionResult(
    action => store->StateStore.dispatch(action), token, 1, WordPressConnectionFinished("Old failure"),
  )
  t->expect((store->StateStore.getState).wordPressCredentialWarning)->Expect.toBe(false)
  t->expect((store->StateStore.getState).wordPressConnectionStatus)->Expect.toEqual(
    Client__State__Types.WordPressConnectionFailed("Your Frontman sign-in changed. Check the connection again."),
  )
})

test("a pending approval blocks a second approval", t => {
  let store = store({...Reducer.defaultState, wordPressPendingApproval: Some(1), wordPressConnectionStatus: WordPressUnlinked})
  store->StateStore.dispatch(Reducer.ConnectWordPress)
  t->expect((store->StateStore.getState).wordPressConnectionStatus)->Expect.toEqual(Client__State__Types.WordPressUnlinked)
  t->expect((store->StateStore.getState).wordPressPendingApproval)->Expect.toBe(Some(1))
})

test("dispose invalidates checks but keeps a pending approval until its completion", t => {
  let store = store({...Reducer.defaultState, wordPressConnectionRequestId: 1, wordPressConnectionStatus: WordPressLinking, wordPressPendingApproval: Some(1)})
  store->StateStore.dispatch(Reducer.ConnectionAction(Dispose))
  t->expect((store->StateStore.getState).wordPressConnectionRequestId)->Expect.toBe(2)
  t->expect((store->StateStore.getState).wordPressPendingApproval)->Expect.toBe(Some(1))
  complete(store, 2, Reducer.WordPressConnectionFinished("unrelated"))
  t->expect((store->StateStore.getState).wordPressPendingApproval)->Expect.toBe(Some(1))
  complete(store, 1, checked(true), ~credentialRisk=true)
  t->expect((store->StateStore.getState).wordPressPendingApproval)->Expect.toBe(None)
  t->expect((store->StateStore.getState).wordPressCredentialWarning)->Expect.toBe(true)
  t->expect((store->StateStore.getState).wordPressConnectionStatus)->Expect.toEqual(
    Client__State__Types.WordPressConnectionFailed("A previous connection attempt finished. Check the connection again."),
  )
  complete(store, 2, checked(false))
  t->expect((store->StateStore.getState).wordPressConnectionStatus)->Expect.toEqual(
    Client__State__Types.WordPressConnectionFailed("A previous connection attempt finished. Check the connection again."),
  )
})
