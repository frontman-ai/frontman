// Re-export types
type state = Client__State__Types.state

// Hook for selecting state
let useSelector = selection =>
  FrontmanReactStatestore.StateStore.useSelector(Client__State__Store.store, selection)

// Re-export selectors
module Selectors = Client__State__StateReducer.Selectors

// Re-export content part modules for convenience
module UserContentPart = Client__State__StateReducer.UserContentPart
module AssistantContentPart = Client__State__StateReducer.AssistantContentPart

// Action creators
module Actions = {
  // User message action
  let addUserMessage = (~content) => {
    let id = `user-${Date.now()->Float.toString}`
    Client__State__Store.dispatch(AddUserMessage({id, content}))
  }

  // Convenience for text-only user messages
  let addUserTextMessage = (~id, ~text) =>
    Client__State__Store.dispatch(
      AddUserMessage({
        id,
        content: [UserContentPart.Text({text: text})],
      }),
    )

  let messageCompleted = (~taskId, ~id) =>
    Client__State__Store.dispatch(MessageCompleted({taskId, id}))

  let textDeltaReceived = (~taskId, ~id, ~text) =>
    Client__State__Store.dispatch(TextDeltaReceived({taskId, id, text}))

  let streamingStarted = (~taskId, ~id) =>
    Client__State__Store.dispatch(StreamingStarted({taskId, id}))

  // TOOLS
  let toolCallReceived = (~taskId, ~toolCall) =>
    Client__State__Store.dispatch(ToolCallReceived({taskId, toolCall}))

  let toolInputStartReceived = (~taskId, ~id, ~toolName, ~parentAgentId=?, ~spawningToolName=?) =>
    Client__State__Store.dispatch(ToolInputStartReceived({taskId, id, toolName, parentAgentId, spawningToolName}))

  let toolInputDeltaReceived = (~taskId, ~id, ~delta) =>
    Client__State__Store.dispatch(ToolInputDeltaReceived({taskId, id, delta}))

  let toolInputEndReceived = (~taskId, ~id) =>
    Client__State__Store.dispatch(ToolInputEndReceived({taskId, id}))

  let toolInputReceived = (~taskId, ~id, ~input) =>
    Client__State__Store.dispatch(ToolInputReceived({taskId, id, input}))

  let toolResultReceived = (~taskId, ~id, ~result) =>
    Client__State__Store.dispatch(ToolResultReceived({taskId, id, result}))

  let toolErrorReceived = (~taskId, ~id, ~error) =>
    Client__State__Store.dispatch(ToolErrorReceived({taskId, id, error}))

  let setPreviewUrl = (~url) => Client__State__Store.dispatch(SetPreviewUrl({url: url}))

  let setPreviewFrame = (~contentDocument, ~contentWindow) =>
    Client__State__Store.dispatch(SetPreviewFrame({contentDocument, contentWindow}))

  let toggleWebPreviewSelection = () => Client__State__Store.dispatch(ToggleWebPreviewSelection)

  let setSelectedElement = (~selectedElement) =>
    Client__State__Store.dispatch(SetSelectedElement({selectedElement: selectedElement}))

  // Task management action creators
  let createTask = (~title) => Client__State__Store.dispatch(CreateTask({title: title}))

  let createNewTask = () => {
    let title = "New Chat"
    Client__State__Store.dispatch(CreateTask({title: title}))
  }

  let switchTask = (~taskId) => Client__State__Store.dispatch(SwitchTask({taskId: taskId}))

  let deleteTask = (~taskId) => Client__State__Store.dispatch(DeleteTask({taskId: taskId}))

  let clearCurrentTask = () => Client__State__Store.dispatch(ClearCurrentTask)

  let updateTaskTitle = (~taskId, ~title) =>
    Client__State__Store.dispatch(UpdateTaskTitle({taskId, title}))

  // Figma node action creators
  let setFigmaNode = (~figmaNode) =>
    Client__State__Store.dispatch(SetFigmaNode({figmaNode: figmaNode}))

  let clearFigmaNode = () => Client__State__Store.dispatch(ClearFigmaNode)

  let setFigmaNodeWaiting = () => Client__State__Store.dispatch(SetFigmaNodeWaiting)

  let clearFigmaNodeWaiting = () => Client__State__Store.dispatch(ClearFigmaNodeWaiting)

  // Connection action creators
  let connect = (~sendPrompt) => Client__State__Store.dispatch(Connect({sendPrompt: sendPrompt}))

  let disconnect = () => Client__State__Store.dispatch(Disconnect)

  // Initialization action creators
  let receivedDiscoveredProjectRule = (~taskId: string) =>
    Client__State__Store.dispatch(ReceivedDiscoveredProjectRule({taskId: taskId}))

  // Turn completion action creators
  let turnCompleted = (~taskId: string) =>
    Client__State__Store.dispatch(TurnCompleted({taskId: taskId}))

  // Plan action creators (ACP compliant)
  let planReceived = (~taskId: string, ~entries) =>
    Client__State__Store.dispatch(PlanReceived({taskId, entries}))
}
