// Re-export types
module Types = Client__ExtensionState__Types
type state = Types.state
type extensionState = Types.extensionState

// State store instance - Create a separate store module
module Store = {
  let store = FrontmanReactStatestore.StateStore.make(
    module(Client__ExtensionState__StateReducer),
    Client__ExtensionState__StateReducer.defaultState,
  )

  let dispatch = action => {
    store->FrontmanReactStatestore.StateStore.dispatch(action)
  }
}

// Hook to use selector
let useSelector = selection =>
  FrontmanReactStatestore.StateStore.useSelector(Store.store, selection)

// Actions module
module Actions = {
  let setExtensionInstalled = (~port) => {
    Store.dispatch(Client__ExtensionState__StateReducer.SetExtensionInstalled(port))
  }

  let setExtensionNotInstalled = () => {
    Store.dispatch(Client__ExtensionState__StateReducer.SetExtensionNotInstalled)
  }
}

// Selectors
module Selectors = {
  let isInstalled = (state: state) => {
    switch state {
    | NotInstalled => false
    | Installed(_) => true
    }
  }

  let getPort = (state: state): option<
    FrontmanBindings.Chrome.port<Client__ExtensionState__StateReducer.extensionMessage>,
  > => {
    switch state {
    | NotInstalled => None
    | Installed(port) => Some(port)
    }
  }
}
