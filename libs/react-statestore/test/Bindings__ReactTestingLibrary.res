type result<'value> = {
  all: array<'value>,
  current: 'value,
  error: JsExn.t,
}

type renderHookResult<'props, 'value> = {
  result: result<'value>,
  rerender: 'props => unit,
  unmount: unit => unit,
}

@module("@testing-library/react")
external renderHook: (unit => 'value) => renderHookResult<unit, 'value> = "renderHook"

@module("@testing-library/react")
external act: (unit => unit) => unit = "act"

@module("@testing-library/react")
external waitFor: (unit => 'value) => promise<'value> = "waitFor"
