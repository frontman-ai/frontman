open StateReducer

type t<'state, 'action> = {
  getState: unit => 'state,
  dispatch: 'action => promise<'state>,
}

let useReducer: (
  module(Interface with type action = 'action and type effect = 'effect and type state = 'state),
  'state,
) => t<'state, 'action>
