open Vitest

module Reducer = Client__State__StateReducer
module Types = Client__State__Types
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Helpers = Client__ConnectionTestHelpers

let makeState = (~preference=None, ~pending=None): Types.state => {
  ...Reducer.defaultState,
  connection: Helpers.ready(),
  draftModelPreference: preference,
  pendingProviderAutoSelect: pending,
}
let runtime = (state: Types.state) =>
  (state.connection->Option.getOrThrow).connection->Result.getOrThrow->Option.getOrThrow
let signal = state => runtime(state).Client__ConnectionReducer.lifetimeAbortController.signal
let catalog = (state, groups) =>
  Reducer.next(state, CatalogReceived({signal: signal(state), groups}))->Pair.first

module SampleConfig = {
  let option = (value): ACP.sessionConfigSelectOption => {
    value,
    name: value,
    description: None,
    _meta: None,
  }
  let group = (group, models): ACP.sessionConfigSelectGroup => {
    group,
    name: group,
    options: models->Array.map(option),
    _meta: None,
  }
  let anthropic = "anthropic:claude-sonnet-5"
  let openai = "openai_codex:gpt-5.6-terra"
  let openrouter = "openrouter:openai/gpt-5.6-terra"
  let fireworks = "fireworks_ai:accounts/fireworks/routers/kimi-k2p5-turbo"
  let saved = "openrouter:anthropic/claude-haiku-4.5"
  let routerGroup = group("openrouter", [openrouter, saved])
  let configWithOpenRouterOnly = [routerGroup]
  let configWithAnthropic = [
    routerGroup,
    group("anthropic", [anthropic, "anthropic:claude-fable-5"]),
    group("openai_codex", [openai, "openai_codex:gpt-5.6-sol"]),
    group("fireworks_ai", [fireworks]),
  ]
  let configWithEmptyFirstGroup = [group("anthropic", []), routerGroup]
  let configWithFutureProvider = [group("future_provider", ["future_provider:model"])]
}

describe("Draft catalog and session selection", () => {
  test("legacy sessions expose the catalog without inventing a selection", t => {
    let groups = SampleConfig.configWithOpenRouterOnly
    let state: Types.state = {
      ...makeState(),
      connection: Helpers.ready(~sessionId=Some("legacy")),
      currentTask: Types.Task.Selected("legacy"),
      modelGroups: Some(groups),
    }
    let state = Reducer.next(state, ConnectionAction(SessionConfigReceived([])))->Pair.first
    t->expect(Reducer.Selectors.selectedModelValue(state))->Expect.toEqual(None)
    t->expect(Reducer.Selectors.modelOptions(state))->Expect.toEqual(Some(ACP.Grouped(groups)))
    let selecting =
      Reducer.next(state, SetSelectedModelValue({value: SampleConfig.openrouter}))->Pair.first
    t->expect(Reducer.Selectors.isSubmitting(selecting))->Expect.toBe(true)
  })

  test("provider onboarding sets a draft auto-select intent", t => {
    [
      (Reducer.ExchangeAnthropicOAuthCode({code: "code", verifier: "verifier"}), "anthropic"),
      (InitiateOpenAIOAuth, "openai_codex"),
      (SaveApiKey({provider: OpenRouter, key: "key"}), "openrouter"),
      (SaveApiKey({provider: Anthropic, key: "key"}), "anthropic"),
      (SaveApiKey({provider: Fireworks, key: "key"}), "fireworks_ai"),
      (SaveApiKey({provider: Nvidia, key: "key"}), "nvidia"),
    ]->Array.forEach(
      ((action, expected)) =>
        t
        ->expect(
          Reducer.next(makeState(), action)
          ->Pair.first
          ->(state => state.Types.pendingProviderAutoSelect),
        )
        ->Expect.toEqual(Some(expected)),
    )
  })

  test("catalog reconciles saved draft preferences and provider auto-selection", t => {
    open SampleConfig
    let check = (state: Types.state, expected, pending) => {
      t->expect(state.draftModelPreference)->Expect.toEqual(expected)
      t->expect(state.pendingProviderAutoSelect)->Expect.toEqual(pending)
      t
      ->expect(
        WebAPI.Window.current
        ->WebAPI.Window.localStorage
        ->WebAPI.Storage.getItem("frontman:selectedModelValue")
        ->Null.toOption,
      )
      ->Expect.toEqual(expected)
    }
    [
      (None, configWithEmptyFirstGroup, Some(openrouter)),
      (None, configWithFutureProvider, Some("future_provider:model")),
      (None, configWithAnthropic, Some(openrouter)),
      (Some(saved), configWithOpenRouterOnly, Some(saved)),
      (Some("removed:model"), configWithOpenRouterOnly, Some(openrouter)),
      (Some("custom:provider:model"), [], None),
      (None, [], None),
    ]->Array.forEach(
      ((preference, options, expected)) =>
        check(catalog(makeState(~preference), options), expected, None),
    )
    [
      ("anthropic", anthropic),
      ("openai_codex", openai),
      ("openrouter", openrouter),
      ("fireworks_ai", fireworks),
    ]->Array.forEach(
      ((provider, expected)) =>
        check(
          catalog(
            makeState(~preference=Some("old:model"), ~pending=Some(provider)),
            configWithAnthropic,
          ),
          Some(expected),
          None,
        ),
    )
    check(
      catalog(
        makeState(~preference=Some("old:model"), ~pending=Some("openai_codex")),
        configWithOpenRouterOnly,
      ),
      Some(openrouter),
      Some("openai_codex"),
    )
  })
})
