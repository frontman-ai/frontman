module type Interface = {
  type state
  type action
  type effect
  let name: string
  let next: (state, action) => (state, array<effect>)
}

type effectHandler<'state, 'action, 'effect> = ('effect, 'state, 'action => unit) => unit

@@live
let update: (~sideEffect: 'a=?, ~sideEffects: array<'a>=?, 'b) => ('b, array<'a>)

let useReducer: (
  module(Interface with type action = 'action and type effect = 'effect and type state = 'state),
  ~handleEffect: effectHandler<'state, 'action, 'effect>,
  'state,
) => ('state, 'action => unit)
