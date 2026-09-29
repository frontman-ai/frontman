module NavigationEvent = FrontmanBindings.Astro.NavigationEvent

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

@get external read: WebAPI.DomTypes.window => option<state> = "__frontman_astro_navigation__"
@set external store: (WebAPI.DomTypes.window, state) => unit = "__frontman_astro_navigation__"
external eventName: phase => string = "%identity"

let install = (host, target: WebAPI.EventTypes.eventTarget) => {
  switch read(host) {
  | Some(_) => ()
  | None =>
    store(host, {lastNavigation: None})
    let previousUrl = ref(WebAPI.Window.location(host).href)
    let swappingSignal: ref<option<WebAPI.EventTypes.abortSignal>> = ref(None)
    let recordHashChange = () => {
      let from = WebAPI.URL.make(~url=previousUrl.contents)
      let to = WebAPI.Window.location(host)
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
    let browserHistory = WebAPI.Window.history(host)
    let observe = original =>
      (data, unused, url) => {
        WebAPI.History.callStateMethod(original, browserHistory, data, unused, url)
        recordHashChange()
      }
    WebAPI.History.setPushState(
      browserHistory,
      observe(WebAPI.History.getPushState(browserHistory)),
    )
    WebAPI.History.setReplaceState(
      browserHistory,
      observe(WebAPI.History.getReplaceState(browserHistory)),
    )
    ["popstate", "hashchange"]->Array.forEach(name => {
      host->WebAPI.Window.addEventListener(Custom(name), _ => recordHashChange())
    })
    [BeforePreparation, AfterPreparation, BeforeSwap, AfterSwap, PageLoad]->Array.forEach(phase => {
      target->WebAPI.EventTarget.addEventListener(Custom(eventName(phase)), event => {
        let {lastNavigation} = read(host)->Option.getOrThrow
        let next = switch (phase, lastNavigation) {
        | (BeforePreparation, _) =>
          Some({
            from: NavigationEvent.fromUrl(event).href,
            to: NavigationEvent.toUrl(event).href,
            phase,
          })
        | (BeforeSwap, _) =>
          swappingSignal := Some(NavigationEvent.signal(event))
          Some({
            from: NavigationEvent.fromUrl(event).href,
            to: NavigationEvent.toUrl(event).href,
            phase,
          })
        | (AfterSwap, Some({phase: BeforeSwap} as navigation)) =>
          previousUrl := WebAPI.Window.location(host).href
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
let start = () =>
  install(WebAPI.DomGlobal.window, WebAPI.DomGlobal.document->WebAPI.Document.asEventTarget)
