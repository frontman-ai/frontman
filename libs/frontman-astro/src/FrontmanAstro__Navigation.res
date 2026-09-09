type phase =
  | @as("astro:before-preparation") BeforePreparation
  | @as("astro:after-preparation") AfterPreparation
  | @as("astro:before-swap") BeforeSwap
  | @as("astro:after-swap") AfterSwap
  | @as("astro:page-load") PageLoad

@@live
type navigation = {from: string, to: string, phase: phase}
type state = {lastNavigation: option<navigation>}
type host

@val external window: host = "window"
@get external read: host => option<state> = "__frontman_astro_navigation__"
@set external store: (host, state) => unit = "__frontman_astro_navigation__"
@get external fromUrl: WebAPI.EventTypes.event => WebAPI.UrlTypes.url = "from"
@get external toUrl: WebAPI.EventTypes.event => WebAPI.UrlTypes.url = "to"
external eventName: phase => string = "%identity"

let install = (host, target: WebAPI.EventTypes.eventTarget) => {
  switch read(host) {
  | Some(_) => ()
  | None =>
    store(host, {lastNavigation: None})
    [BeforePreparation, AfterPreparation, BeforeSwap, AfterSwap, PageLoad]->Array.forEach(phase => {
      target->WebAPI.EventTarget.addEventListener(Custom(eventName(phase)), event => {
        let {lastNavigation} = read(host)->Option.getOrThrow
        let next = switch (phase, lastNavigation) {
        | (BeforePreparation | BeforeSwap, _) =>
          Some({from: fromUrl(event).href, to: toUrl(event).href, phase})
        | (PageLoad, Some({phase: AfterSwap} as navigation))
        | (AfterPreparation | AfterSwap, Some(navigation)) =>
          Some({...navigation, phase})
        | (PageLoad, Some(_))
        | (AfterPreparation | AfterSwap | PageLoad, None) => lastNavigation
        }
        store(host, {lastNavigation: next})
      })
    })
  }
}

@@live
let start = () => install(window, WebAPI.DomGlobal.document->WebAPI.Document.asEventTarget)
