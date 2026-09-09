open Vitest

module Navigation = FrontmanAstro__Navigation

type spy = {"mock": {"calls": array<unknown>}}
external toHost: WebAPI.EventTypes.eventTarget => WebAPI.DomTypes.window = "%identity"
@set external setLocation: (WebAPI.DomTypes.window, WebAPI.UrlTypes.url) => unit = "location"
@set external setHistory: (WebAPI.DomTypes.window, WebAPI.HistoryTypes.history) => unit = "history"
@obj
external makeHistory: (
  ~pushState: Navigation.historyMethod,
  ~replaceState: Navigation.historyMethod,
) => WebAPI.HistoryTypes.history = ""
@module("vitest") @scope("vi")
external spyOnListeners: (WebAPI.EventTypes.eventTarget, @as("addEventListener") _) => spy = "spyOn"
@set external setFrom: (WebAPI.EventTypes.event, WebAPI.UrlTypes.url) => unit = "from"
@set external setTo: (WebAPI.EventTypes.event, WebAPI.UrlTypes.url) => unit = "to"
@set external setSignal: (WebAPI.EventTypes.event, WebAPI.EventTypes.abortSignal) => unit = "signal"

let setup = () => {
  let host = WebAPI.EventTarget.make()->toHost
  setLocation(host, WebAPI.URL.make(~url="https://example.com/start?tab=one#intro"))
  let updateHistory = (_data, _unused, url) => {
    url->Option.forEach(url => {
      setLocation(host, WebAPI.URL.make(~url, ~base=WebAPI.Window.location(host).href))
    })
  }
  setHistory(host, makeHistory(~pushState=updateHistory, ~replaceState=updateHistory))
  let target = WebAPI.EventTarget.make()
  let listeners = spyOnListeners(target)
  Navigation.install(host, target)
  (host, target, listeners)
}

let dispatch = (target, phase, ~from=?, ~to=?, ~controller=WebAPI.AbortController.make()) => {
  let event = WebAPI.Event.make(~type_=Navigation.eventName(phase))
  setSignal(event, controller.signal)
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
    setLocation(host, WebAPI.URL.make(~url=redirected))
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

  test("superseded swap and page-load cannot advance a newer preparation", t => {
    let (host, target, _) = setup()
    dispatch(target, BeforePreparation, ~from, ~to)
    dispatch(target, AfterPreparation)
    target->WebAPI.EventTarget.addEventListener(
      Custom("astro:before-swap"),
      _ => {
        dispatch(target, BeforePreparation, ~from, ~to="https://example.com/newer")
      },
    )
    dispatch(target, BeforeSwap, ~from, ~to)
    let record = latest(host)
    dispatch(target, AfterSwap)
    dispatch(target, PageLoad)
    t->expect(latest(host))->Expect.toBe(record)
  })

  test("late preparation events cannot regress a swapped or completed navigation", t => {
    let (host, target, _) = setup()
    dispatch(target, BeforePreparation, ~from, ~to)
    dispatch(target, AfterPreparation)
    dispatch(target, BeforeSwap, ~from, ~to)
    dispatch(target, AfterPreparation)
    t->expect(phase(host))->Expect.toBe(Navigation.BeforeSwap)
    dispatch(target, AfterSwap)
    dispatch(target, AfterPreparation)
    t->expect(phase(host))->Expect.toBe(Navigation.AfterSwap)
    dispatch(target, PageLoad)
    dispatch(target, AfterPreparation)
    dispatch(target, AfterSwap)
    t->expect(phase(host))->Expect.toBe(Navigation.PageLoad)
  })

  test("records the actual destination after later before-swap listeners change it", t => {
    let (host, target, _) = setup()
    let finalUrl = "https://example.com/final"
    target->WebAPI.EventTarget.addEventListener(
      Custom("astro:before-swap"),
      event => {
        setTo(event, WebAPI.URL.make(~url=finalUrl))
        setLocation(host, Navigation.toUrl(event))
      },
    )
    dispatch(target, BeforePreparation, ~from, ~to)
    dispatch(target, BeforeSwap, ~from, ~to)
    dispatch(target, AfterSwap)
    dispatch(target, PageLoad)
    t->expect(latest(host))->Expect.toEqual(Some({from, to: finalUrl, phase: PageLoad}))
  })

  test("captures hash-only push, replace, traversal, and native hash changes once", t => {
    let (host, target, _) = setup()
    let history = WebAPI.Window.history(host)
    let originalPush = Navigation.pushState(history)
    Navigation.install(host, target)
    t->expect(Navigation.pushState(history))->Expect.toBe(originalPush)
    WebAPI.History.pushState(history, ~data=JSON.Encode.null, ~unused="", ~url="#two")
    let second = "https://example.com/start?tab=one#two"
    t->expect(latest(host))->Expect.toEqual(Some({from, to: second, phase: HashChange}))
    WebAPI.History.replaceState(history, ~data=JSON.Encode.null, ~unused="", ~url="#three")
    let third = "https://example.com/start?tab=one#three"
    t->expect(latest(host))->Expect.toEqual(Some({from: second, to: third, phase: HashChange}))
    setLocation(host, WebAPI.URL.make(~url=from))
    host
    ->WebAPI.Window.dispatchEvent(WebAPI.Event.make(~type_="popstate"))
    ->ignore
    let record = latest(host)
    host
    ->WebAPI.Window.dispatchEvent(WebAPI.Event.make(~type_="hashchange"))
    ->ignore
    t->expect(latest(host))->Expect.toBe(record)
    t->expect(latest(host))->Expect.toEqual(Some({from: third, to: from, phase: HashChange}))
    setLocation(host, WebAPI.URL.make(~url=second))
    host
    ->WebAPI.Window.dispatchEvent(WebAPI.Event.make(~type_="hashchange"))
    ->ignore
    t->expect(latest(host))->Expect.toEqual(Some({from, to: second, phase: HashChange}))
    WebAPI.History.replaceState(history, ~data=JSON.Encode.null, ~unused="")
    t->expect(latest(host))->Expect.toEqual(Some({from, to: second, phase: HashChange}))
  })

  test("route history updates refresh the baseline without inventing hash navigations", t => {
    let (host, _, _) = setup()
    let history = WebAPI.Window.history(host)
    WebAPI.History.pushState(history, ~data=JSON.Encode.null, ~unused="", ~url=to)
    t->expect(latest(host))->Expect.toBe(None)
    WebAPI.History.pushState(history, ~data=JSON.Encode.null, ~unused="", ~url="#new")
    t
    ->expect(latest(host))
    ->Expect.toEqual(
      Some({from: to, to: "https://example.com/next?tab=two#new", phase: HashChange}),
    )
  })

  test("same-page swaps retain their Astro lifecycle through history updates", t => {
    let (host, target, _) = setup()
    let destination = "https://example.com/start?tab=one#two"
    dispatch(target, BeforePreparation, ~from, ~to=destination)
    dispatch(target, BeforeSwap, ~from, ~to=destination)
    WebAPI.History.pushState(
      WebAPI.Window.history(host),
      ~data=JSON.Encode.null,
      ~unused="",
      ~url=destination,
    )
    t->expect(phase(host))->Expect.toBe(Navigation.BeforeSwap)
    dispatch(target, AfterSwap)
    dispatch(target, PageLoad)
    t->expect(latest(host))->Expect.toEqual(Some({from, to: destination, phase: PageLoad}))
  })

  test("hash navigation can supersede an aborted swap", t => {
    let (host, target, _) = setup()
    let controller = WebAPI.AbortController.make()
    target->WebAPI.EventTarget.addEventListener(
      Custom("astro:before-swap"),
      _ => {
        WebAPI.AbortController.abort(controller)
        WebAPI.History.pushState(
          WebAPI.Window.history(host),
          ~data=JSON.Encode.null,
          ~unused="",
          ~url="#new",
        )
      },
    )
    dispatch(target, BeforePreparation, ~from, ~to)
    dispatch(target, BeforeSwap, ~from, ~to, ~controller)
    dispatch(target, AfterSwap)
    dispatch(target, PageLoad)
    t
    ->expect(latest(host))
    ->Expect.toEqual(Some({from, to: "https://example.com/start?tab=one#new", phase: HashChange}))
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
