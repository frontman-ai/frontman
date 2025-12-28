%%raw(`/* eslint-disable */`)
open StateReducer

module ReactTestingLibrary = Bindings__ReactTestingLibrary
type t<'state, 'action> = {
  getState: unit => 'state,
  dispatch: 'action => promise<'state>,
}

let useReducer:
  type state action effect. (
    module(Interface with type state = state and type action = action and type effect = effect),
    state,
  ) => t<state, action> =
  (module(State), initialValue) => {
    let {result} = ReactTestingLibrary.renderHook(() =>
      StateReducer.useReducer(module(State), initialValue)
    )

    let dispatch = action => {
      let dispatch = Pair.second(result.current)

      ReactTestingLibrary.act(() => {
        setTimeout(() => {
          dispatch(action)
        }, 1)->ignore
      })

      ReactTestingLibrary.waitFor(() => {
        Pair.first(result.current)
      })
    }

    {getState: () => Pair.first(result.current), dispatch}
  }
