// Extension state types
module Chrome = FrontmanBindings.Chrome

type extensionMessage = {
  @as("type") type_: string,
}

type extensionState =
  | NotInstalled
  | Installed(Chrome.port<extensionMessage>)

type state = extensionState
