let store = FrontmanReactStatestore.StateStore.make(
  module(Client__State__StateReducer),
  Client__State__StateReducer.defaultState,
)

let dispatch = action => {
  store->FrontmanReactStatestore.StateStore.dispatch(action)
}
