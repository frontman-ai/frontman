type result<'value> = {
  current: 'value,
}

type renderHookResult<'props, 'value> = {
  result: result<'value>,
}

@module("@testing-library/react")
external renderHook: (unit => 'value) => renderHookResult<unit, 'value> = "renderHook"

@module("@testing-library/react")
external act: (unit => unit) => unit = "act"

@module("@testing-library/react")
external waitFor: (unit => 'value) => promise<'value> = "waitFor"
