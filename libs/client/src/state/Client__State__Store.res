let store = StateStore.make(
  module(Client__State__StateReducer),
  ~handleEffect=Client__State__Effects.handleEffect,
  Client__State__Initialization.defaultState,
)

let dispatch = action => {
  store->StateStore.dispatch(action)
}
