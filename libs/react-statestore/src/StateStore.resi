type t<'state, 'action, 'effect>
let make: (
  module(StateReducer.Interface with
    type state = 'state
    and type action = 'action
    and type effect = 'effect
  ),
  'state,
) => t<'state, 'action, 'effect>
let getState: t<'state, 'action, 'effect> => 'state
let dispatch: (t<'state, 'action, 'effect>, 'action) => unit
@@live
let subscribe: (t<'state, 'action, 'effect>, unit => unit, unit) => unit

@@live
let useSelector: (
  ~compare: option<('selection, 'selection) => bool>=?,
  t<'state, 'action, 'effect>,
  'state => 'selection,
) => 'selection

@@live
let forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll: (
  t<'state, 'action, 'effect>,
  'state,
) => unit
