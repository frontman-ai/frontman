type phase =
  | @as("astro:before-preparation") BeforePreparation
  | @as("astro:after-preparation") AfterPreparation
  | @as("astro:before-swap") BeforeSwap
  | @as("astro:after-swap") AfterSwap
  | @as("astro:page-load") PageLoad
  | @as("hash-change") HashChange

@@live
type navigation = {from: string, to: string, phase: phase}
type state = {lastNavigation: option<navigation>}
type host
type signal = {mutable aborted: bool}
@get external signal: WebAPI.EventTypes.event => signal = "signal"

@val external window: host = "window"
@get external read: host => option<state> = "__frontman_astro_navigation__"
@set external store: (host, state) => unit = "__frontman_astro_navigation__"
@get external fromUrl: WebAPI.EventTypes.event => WebAPI.UrlTypes.url = "from"
@get external toUrl: WebAPI.EventTypes.event => WebAPI.UrlTypes.url = "to"
external eventName: phase => string = "%identity"
@get external location: host => WebAPI.UrlTypes.url = "location"
@get external history: host => WebAPI.HistoryTypes.history = "history"
external asTarget: host => WebAPI.EventTypes.eventTarget = "%identity"
type historyMethod = (JSON.t, string, option<string>) => unit
@get external pushState: WebAPI.HistoryTypes.history => historyMethod = "pushState"
@get external replaceState: WebAPI.HistoryTypes.history => historyMethod = "replaceState"
@set external setPushState: (WebAPI.HistoryTypes.history, historyMethod) => unit = "pushState"
@set external setReplaceState: (WebAPI.HistoryTypes.history, historyMethod) => unit = "replaceState"
@send
external callHistory: (
  historyMethod,
  WebAPI.HistoryTypes.history,
  JSON.t,
  string,
  option<string>,
) => unit = "call"

let install = (host, target: WebAPI.EventTypes.eventTarget) => {
  switch read(host) {
  | Some(_) => ()
  | None =>
    store(host, {lastNavigation: None})
    let previousUrl = ref(location(host).href)
    let swappingSignal = ref(None)
    let recordHashChange = () => {
      let from = WebAPI.URL.make(~url=previousUrl.contents)
      let to = location(host)
      previousUrl := to.href
      let swapping = switch (
        (read(host)->Option.getOrThrow).lastNavigation,
        swappingSignal.contents,
      ) {
      | (Some({phase: BeforeSwap}), Some({aborted: false})) => true
      | _ => false
      }
      switch !swapping &&
      from.origin == to.origin &&
      from.pathname == to.pathname &&
      from.search == to.search &&
      from.hash != to.hash {
      | true =>
        store(host, {lastNavigation: Some({from: from.href, to: to.href, phase: HashChange})})
      | false => ()
      }
    }
    let browserHistory = history(host)
    let observe = original =>
      (data, unused, url) => {
        callHistory(original, browserHistory, data, unused, url)
        recordHashChange()
      }
    setPushState(browserHistory, observe(pushState(browserHistory)))
    setReplaceState(browserHistory, observe(replaceState(browserHistory)))
    ["popstate", "hashchange"]->Array.forEach(name => {
      asTarget(host)->WebAPI.EventTarget.addEventListener(Custom(name), _ => recordHashChange())
    })
    [BeforePreparation, AfterPreparation, BeforeSwap, AfterSwap, PageLoad]->Array.forEach(phase => {
      target->WebAPI.EventTarget.addEventListener(Custom(eventName(phase)), event => {
        let {lastNavigation} = read(host)->Option.getOrThrow
        let next = switch (phase, lastNavigation) {
        | (BeforePreparation, _) => Some({from: fromUrl(event).href, to: toUrl(event).href, phase})
        | (BeforeSwap, _) =>
          swappingSignal := Some(signal(event))
          Some({from: fromUrl(event).href, to: toUrl(event).href, phase})
        | (AfterSwap, Some({phase: BeforeSwap} as navigation)) =>
          previousUrl := location(host).href
          Some({...navigation, to: previousUrl.contents, phase})
        | (PageLoad, Some({phase: AfterSwap} as navigation))
        | (AfterPreparation, Some({phase: BeforePreparation} as navigation)) =>
          Some({...navigation, phase})
        | (AfterPreparation | AfterSwap | PageLoad | HashChange, _) => lastNavigation
        }
        store(host, {lastNavigation: next})
      })
    })
  }
}

@@live
let start = () => install(window, WebAPI.DomGlobal.document->WebAPI.Document.asEventTarget)
