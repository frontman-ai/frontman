// Extension state types
module Chrome = AskTheLlmBindings.Chrome

type extensionMessage = {
  @as("type") type_: string,
  selectedFigmaNode: option<Client__State__Types.FigmaNode.nodeData>,
}

type extensionState =
  | NotInstalled
  | Installed(Chrome.port<extensionMessage>)

type state = extensionState
