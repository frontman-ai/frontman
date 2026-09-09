open Vitest

module Navigation = FrontmanAstro__Navigation

type spy = {"mock": {"calls": array<unknown>}}
@obj external makeHost: unit => Navigation.host = ""
@module("vitest") @scope("vi")
external spyOnListeners: (WebAPI.EventTypes.eventTarget, @as("addEventListener") _) => spy = "spyOn"
@set external setFrom: (WebAPI.EventTypes.event, WebAPI.UrlTypes.url) => unit = "from"
@set external setTo: (WebAPI.EventTypes.event, WebAPI.UrlTypes.url) => unit = "to"

let setup = () => {
  let host = makeHost()
  let target = WebAPI.EventTarget.make()
  let listeners = spyOnListeners(target)
  Navigation.install(host, target)
  (host, target, listeners)
}

let dispatch = (target, phase, ~from=?, ~to=?) => {
  let event = WebAPI.Event.make(~type_=Navigation.eventName(phase))
  from->Option.forEach(url => setFrom(event, WebAPI.URL.make(~url)))
  to->Option.forEach(url => setTo(event, WebAPI.URL.make(~url)))
  target->WebAPI.EventTarget.dispatchEvent(event)->ignore
}

let latest = host => (Navigation.read(host)->Option.getOrThrow).lastNavigation
let phase = host => (latest(host)->Option.getOrThrow).phase
let from = "https://example.com/start?tab=one#intro"
let to = "https://example.com/next?tab=two#details"

describe("Astro navigation capture", () => {
  test("initial page load and unrelated completion events do not invent a navigation", t => {
    let (host, target, _) = setup()
    [Navigation.PageLoad, AfterPreparation, AfterSwap, PageLoad]->Array.forEach(
      phase => dispatch(target, phase),
    )
    t->expect(latest(host))->Expect.toBe(None)
  })

  test("records every phase, refreshed destination, and only the latest navigation", t => {
    let (host, target, _) = setup()
    dispatch(target, PageLoad)
    dispatch(target, BeforePreparation, ~from, ~to)
    t->expect(latest(host))->Expect.toEqual(Some({from, to, phase: BeforePreparation}))
    dispatch(target, AfterPreparation)
    t->expect(latest(host))->Expect.toEqual(Some({from, to, phase: AfterPreparation}))

    let redirected = "https://example.com/redirected"
    dispatch(target, BeforeSwap, ~from, ~to=redirected)
    t->expect(latest(host))->Expect.toEqual(Some({from, to: redirected, phase: BeforeSwap}))
    dispatch(target, AfterSwap)
    t->expect(latest(host))->Expect.toEqual(Some({from, to: redirected, phase: AfterSwap}))
    dispatch(target, PageLoad)
    t->expect(latest(host))->Expect.toEqual(Some({from, to: redirected, phase: PageLoad}))

    dispatch(target, BeforePreparation, ~from=redirected, ~to=from)
    t
    ->expect(latest(host))
    ->Expect.toEqual(Some({from: redirected, to: from, phase: BeforePreparation}))
  })

  test("page-load cannot complete a navigation that has not swapped", t => {
    let (host, target, _) = setup()
    dispatch(target, BeforePreparation, ~from, ~to)
    dispatch(target, PageLoad)
    t->expect(phase(host))->Expect.toBe(Navigation.BeforePreparation)
    dispatch(target, BeforeSwap, ~from, ~to)
    dispatch(target, AfterSwap)
    dispatch(target, PageLoad)
    t->expect(phase(host))->Expect.toBe(Navigation.PageLoad)
  })

  test("repeated setup preserves state and installs no duplicate listeners", t => {
    let (host, target, listeners) = setup()
    dispatch(target, BeforePreparation, ~from, ~to)
    let record = latest(host)
    Navigation.install(host, target)
    t->expect(latest(host))->Expect.toBe(record)
    t->expect(listeners["mock"]["calls"]->Array.length)->Expect.toBe(5)

    dispatch(target, BeforeSwap, ~from, ~to)
    dispatch(target, AfterSwap)
    dispatch(target, PageLoad)
    Navigation.install(host, target)
    t->expect(phase(host))->Expect.toBe(Navigation.PageLoad)
    t->expect(listeners["mock"]["calls"]->Array.length)->Expect.toBe(5)
  })
})
