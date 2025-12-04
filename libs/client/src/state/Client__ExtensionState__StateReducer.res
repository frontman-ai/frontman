// Extension state reducer for managing Chrome extension connection
module Chrome = AskTheLlmBindings.Chrome
module Types = Client__ExtensionState__Types

type extensionMessage = Types.extensionMessage
type extensionState = Types.extensionState
type state = Types.state

type action =
  | SetExtensionInstalled(Chrome.port<extensionMessage>)
  | SetExtensionNotInstalled

type effect = None_

let defaultState: state = Types.NotInstalled

let next = (_state, action) => {
  switch action {
  | SetExtensionInstalled(port) =>
    Types.Installed(port)->AskTheLlmReactStatestore.StateReducer.update
  | SetExtensionNotInstalled => Types.NotInstalled->AskTheLlmReactStatestore.StateReducer.update
  }
}

let handleEffect = (_effect, _state: state, _dispatch) => ()

let name = "Client::ExtensionState"
