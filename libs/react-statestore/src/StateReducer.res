let useUnsafeCleanupEffects = (effects, handleEffect, dispatch, state: 'state) => {
  let stateRef = React.useRef(state)

  React.useEffect(() => {
    stateRef.current = state
    None
  }, [state])

  React.useEffect(_ => {
    let state = stateRef.current
    effects.contents->Array.forEach(e => handleEffect(e, state, dispatch))
    effects := []
    None
  }, (effects, handleEffect, dispatch))
}

module type Interface = {
  type state
  type action
  type effect
  let name: string
  let next: (state, action) => (state, array<effect>)
  let handleEffect: (effect, state, action => unit) => unit
}

module type InterfaceWithLogging = {
  include Interface
  let actionToString: action => string
}

let update = (~sideEffect=?, ~sideEffects=?, state) =>
  switch (sideEffect, sideEffects) {
  | (Some(sideEffect), Some(xs)) => (state, [...xs, sideEffect])
  | (Some(sideEffect), None) => (state, [sideEffect])
  | (None, Some(xs)) => (state, xs)
  | (None, None) => (state, [])
  }

let useReducer:
  type state action effect. (
    module(Interface with type state = state and type action = action and type effect = effect),
    state,
  ) => (state, action => unit) =
  (module(Reducer), initialState) => {
    let reducer = ((state, effects), action) => {
      let (newState, newEffects) = Reducer.next(state, action)
      let effects = ref(Array.concat(effects.contents, newEffects))
      (newState, effects)
    }

    let ((state, effects), dispatch) = React.useReducer(reducer, (initialState, ref([])))
    useUnsafeCleanupEffects(effects, Reducer.handleEffect, dispatch, state)
    (state, dispatch)
  }

type reducer<'state, 'action, 'effect> = ('state, 'action) => ('state, array<'effect>)

%%raw("/* eslint-disable no-console*/")
let loggingReducer = (reducer, actionToString) => {
  (state, action) => {
    Js.Console.log2("State", state)
    Js.Console.log2("Action:", actionToString(action))
    let (newState, newEffects) = reducer(state, action)
    Js.Console.log2("New State:", newState)
    (newState, newEffects)
  }
}

%%raw("/* eslint-disable no-console*/")
let useLoggingReducer:
  type state action effect. (
    module(InterfaceWithLogging with
      type state = state
      and type action = action
      and type effect = effect
    ),
    state,
  ) => (state, action => unit) =
  (module(Reducer), initialState) => {
    let reducer = ((state, effects), action) => {
      Js.Console.log2("Action:", action)
      let (newState, newEffects) = Reducer.next(state, action)
      let effects = ref(Array.concat(effects.contents, newEffects))
      Js.Console.log2("New State:", newState)
      (newState, effects)
    }

    let ((state, effects), dispatch) = React.useReducer(reducer, (initialState, ref([])))
    useUnsafeCleanupEffects(effects, Reducer.handleEffect, dispatch, state)
    (state, dispatch)
  }
