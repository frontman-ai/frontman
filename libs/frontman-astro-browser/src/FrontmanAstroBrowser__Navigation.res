@schema
type phase =
  | @as("astro:before-preparation") BeforePreparation
  | @as("astro:after-preparation") AfterPreparation
  | @as("astro:before-swap") BeforeSwap
  | @as("astro:after-swap") AfterSwap
  | @as("astro:page-load") PageLoad
  | @as("hash-change") HashChange

@schema
type navigation = {from: string, to: string, phase: phase}

@schema
type state = {lastNavigation: option<navigation>}

@schema @tag("status")
type t =
  | @as("unavailable") Unavailable
  | @as("not_observed") NotObserved
  | @as("observed") Observed({from: string, to: string, phase: phase})

@get external readState: WebAPI.DomTypes.window => option<JSON.t> = "__frontman_astro_navigation__"

let read = (window: WebAPI.DomTypes.window): t =>
  switch readState(window) {
  | None => Unavailable
  | Some(value) =>
    switch S.parseOrThrow(value, ~to=stateSchema).lastNavigation {
    | None => NotObserved
    | Some({from, to, phase}) => Observed({from, to, phase})
    }
  }
