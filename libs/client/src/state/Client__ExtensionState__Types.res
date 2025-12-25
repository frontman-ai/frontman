// Extension state types
module Chrome = AskTheLlmBindings.Chrome

// Raw Figma node data from the extension
type rawFigmaNodeData = {
  nodeId: string,
  nodeData: string, // DSL representation - extension always sends DSL
  image: option<string>,
}

type extensionMessage = {
  @as("type") type_: string,
  selectedFigmaNode: option<rawFigmaNodeData>,
  // GetFigmaNode response fields (use Nullable since they come from JS as null, not undefined)
  requestId: Js.Nullable.t<string>,
  node: Js.Nullable.t<JSON.t>,
  error: Js.Nullable.t<string>,
  image: Js.Nullable.t<string>,
}

type extensionState =
  | NotInstalled
  | Installed(Chrome.port<extensionMessage>)

type state = extensionState
