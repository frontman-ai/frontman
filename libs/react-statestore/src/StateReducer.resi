module type Interface = {
  type state
  type action
  type effect
  let name: string
  let next: (state, action) => (state, array<effect>)
  let handleEffect: (effect, state, action => unit) => unit
}

@@live
let update: (~sideEffect: 'a=?, ~sideEffects: array<'a>=?, 'b) => ('b, array<'a>)

let useReducer: (
  module(Interface with type action = 'action and type effect = 'effect and type state = 'state),
  'state,
) => ('state, 'action => unit)
