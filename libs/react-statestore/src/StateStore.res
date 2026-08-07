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
        return false
      }
    } else {
      return false;
    }
  }
`)

let compareFn = Some(isEqual)

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
