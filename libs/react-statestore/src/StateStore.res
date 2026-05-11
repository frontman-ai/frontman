type t<'state, 'action, 'effect> = {
  subscriptions: ref<array<unit => unit>>,
  next: ('state, 'action) => ('state, array<'effect>),
  handleEffect: ('effect, 'state, 'action => unit) => unit,
  effects: ref<array<'effect>>,
  state: ref<'state>,
}

@@live
let rec dispatch = (t, action) => {
  let (newState, newEffects) = t.next(t.state.contents, action)
  t.effects.contents = Array.concat(t.effects.contents, newEffects)
  t.state.contents = newState
  t.subscriptions.contents->Array.forEach(s => s())
  runEffects(t)
}
and runEffects = t => {
  let effects = t.effects.contents
  t.effects.contents = []
  Array.forEach(effects, e => t.handleEffect(e, t.state.contents, action => dispatch(t, action)))
}

let forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll = (t, newState) => {
  t.state.contents = newState
  t.subscriptions.contents->Array.forEach(s => s())
}

@@live
let make:
  type state action effect. (
    module(StateReducer.Interface with
      type state = state
      and type action = action
      and type effect = effect
    ),
    state,
  ) => t<state, action, effect> =
  (module(Reducer), initialState) => {
    let storeCreator = (next, initialState) => {
      subscriptions: ref([]),
      state: ref(initialState),
      next,
      effects: ref([]),
      handleEffect: Reducer.handleEffect,
    }
    storeCreator(Reducer.next, initialState)
  }

@@live
let getState = store => store.state.contents
let addSubscription = (store, sub) => Array.push(store.subscriptions.contents, sub)->ignore

let removeSubscription = (t, sub) => {
  let subIdx = Array.indexOf(t.subscriptions.contents, sub)
  if subIdx >= 0 {
    let _ = Array.splice(t.subscriptions.contents, ~start=subIdx, ~remove=1, ~insert=[])
  }
}
let subscribe = (t, sub) => {
  addSubscription(t, sub)
  () => removeSubscription(t, sub)
}

type subscribe = (unit => unit) => unit => unit
@module("use-sync-external-store/with-selector")
external useSyncExternalStoreWithSelector: (
  subscribe,
  unit => 'snapshot,
  option<unit => 'snapshot>,
  'snapshot => 'selection,
  option<('selection, 'selection) => bool>,
) => 'selection = "useSyncExternalStoreWithSelector"

// this is a copy of the caml_equal function from the ReScript runtime
// the part that is removed is the deep equal comparison of object values
// which is expensive. We can assume that in reducers objects are immutable
// so the references are the same if they are equal.
//
// it also doesn't throw an exception when comparing functions, which the
// rescript function does. This was a big downside of using `==` here.
//
// we kept the the comparison for arrays, so you can select and compare arrays
let isEqual: ('a, 'a) => bool = %raw(`
  function equal(a, b) {
    if (a === b) {
      return true;
    }
    var a_type = typeof a;
    if (a_type === "string" || a_type === "number" || a_type === "bigint" || a_type === "boolean" || a_type === "undefined" || a === null) {
      return false;
    }
    var b_type = typeof b;
    if (a_type === "function" || b_type === "function") {
      // different functions
      return false;
    }
    if (b_type === "number" || b_type === "bigint" || b_type === "undefined" || b === null) {
      return false;
    }
    var tag_a = a.TAG;
    var tag_b = b.TAG;
    if (tag_a === 248) {
      return a[1] === b[1];
    }
    if (tag_a === 251) {
      throw {
            RE_EXN_ID: "Invalid_argument",
            _1: "equal: abstract value",
            Error: new Error()
          };
    }
    if (tag_a !== tag_b) {
      return false;
    }
    var len_a = a.length | 0;
    var len_b = b.length | 0;
    if (len_a === len_b) {
      if (Array.isArray(a)) {
        var _i = 0;
        while(true) {
          var i = _i;
          if (i === len_a) {
            return true;
          }
          if (!equal(a[i], b[i])) {
            return false;
          }
          _i = i + 1 | 0;
        };
      } else if ((a instanceof Date && b instanceof Date)) {
        return !(a > b || a < b);
      } else {
        // assume objects are immutable
        return false
      }
    } else {
      return false;
    }
  }
`)

let compareFn = Some(isEqual)

// the selector above is performant and works perfectly when the React renderer is
// running synchronously. However this all falls apart in concurrent mode. With
// concurrent mode we can have a high priority event that runs WHILE React is rendering
// (with double buffering). The renderer will yield time using the scheduler to handle
// the event. If this event triggers a state change, the app will continue rendering with
// different state than the state it started with. This is called "tearing", and will have
// all sorts of bad effects including inconsistent components, but also exceptions can be
// thrown.
//
// In React 18 they added a new hook to deal with this when you have state outside of
// React, called `useSyncExternalStore`, including a version that implements efficient
// selectors published as a separate package by the React team. This makes sure tearing
// cannot happen anymore, and has the same performance characteristics as the implementation
// above.
//
// The cool thing is that this reduces our selector implementation to almost a one-liner
// all the heavy lifting is done inside of React. The same approach is being taken
// in the latest version of Redux. And the implemenation of React-Redux is now similarly
// small. This allows us to have at least the same performance as redux with a very
// minimal implementation (and maintenance) overhead, and have a rescript friendly
// interface.
@@live
let useSelector:
  type selection. (
    ~compare: option<(selection, selection) => bool>=?,
    t<'state, 'action, 'effect>,
    'state => selection,
  ) => selection =
  (~compare=compareFn, store: t<'state, 'action, 'effect>, selector: 'state => selection) => {
    let subscribeAdapter = React.useMemo(() => callback => subscribe(store, callback), [store])
    useSyncExternalStoreWithSelector(
      subscribeAdapter,
      () => getState(store),
      None,
      selector,
      compare,
    )
  }
