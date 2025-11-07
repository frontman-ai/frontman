// Re-export types
type state = Client__State__StateReducer.state
// type action = Client__State__StateReducer.action

// Hook for selecting state
let useSelector = selection =>
  AskTheLlmReactStatestore.StateStore.useSelector(Client__State__Store.store, selection)

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

  let messageCompleted = (~id) => Client__State__Store.dispatch(MessageCompleted({id: id}))

  let textDeltaReceived = (~id, ~text) =>
    Client__State__Store.dispatch(TextDeltaReceived({id, text}))

  let streamingStarted = (~id) => Client__State__Store.dispatch(StreamingStarted({id: id}))

  // TOOLS
  let toolCallReceived = (~toolCall) =>
    Client__State__Store.dispatch(ToolCallReceived({toolCall: toolCall}))

  let toolInputStartReceived = (~id, ~toolName) =>
    Client__State__Store.dispatch(ToolInputStartReceived({id, toolName}))

  let toolInputDeltaReceived = (~id, ~delta) =>
    Client__State__Store.dispatch(ToolInputDeltaReceived({id, delta}))

  let toolInputEndReceived = (~id) => Client__State__Store.dispatch(ToolInputEndReceived({id: id}))

  let toolResultReceived = (~id, ~result) =>
    Client__State__Store.dispatch(ToolResultReceived({id, result}))

  let toolErrorReceived = (~id, ~error) =>
    Client__State__Store.dispatch(ToolErrorReceived({id, error}))

  let setPreviewUrl = (~url) => Client__State__Store.dispatch(SetPreviewUrl({url: url}))

  let setPreviewFrame = (~contentDocument, ~contentWindow) =>
    Client__State__Store.dispatch(SetPreviewFrame({contentDocument, contentWindow}))

  let toggleWebPreviewSelection = () => Client__State__Store.dispatch(ToggleWebPreviewSelection)

  let setSelectedElement = (~selectedElement) =>
    Client__State__Store.dispatch(SetSelectedElement({selectedElement: selectedElement}))

  // Task management action creators
  let createTask = (~id, ~title, ~timestamp) =>
    Client__State__Store.dispatch(CreateTask({id, title, timestamp}))

  let switchTask = (~taskId) => Client__State__Store.dispatch(SwitchTask({taskId: taskId}))

  let deleteTask = (~taskId) => Client__State__Store.dispatch(DeleteTask({taskId: taskId}))

  let clearCurrentTask = () => Client__State__Store.dispatch(ClearCurrentTask)

  let updateTaskTitle = (~taskId, ~title) =>
    Client__State__Store.dispatch(UpdateTaskTitle({taskId, title}))
}
