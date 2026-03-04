let store = StateStore.make(
  module(Client__State__StateReducer),
  Client__State__StateReducer.defaultState,
)

let dispatch = action => {
  store->StateStore.dispatch(action)
}
