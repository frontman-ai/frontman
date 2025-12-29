S.enableJson()
/**
 * Client__StateSnapshot__Storybook - Helpers for using state snapshots in Storybook
 *
 * Provides utilities to load captured state snapshots into the app for story testing.
 *
 * Usage in a story file:
 * ```rescript
 * let snapshotJson = `{"tasks": [...], ...}` // Pasted from clipboard
 *
 * let complexScenario: Story.t<args> = {
 *   name: "Complex Tool Calls",
 *   decorators: [Client__StateSnapshot__Storybook.withSnapshot(snapshotJson)],
 *   render: _ => <Client__Chatbox />,
 * }
 * ```
 */
module Snapshot = Client__StateSnapshot
module StateTypes = Client__State__Types

// ============================================================================
// Conversion from Snapshot to Live State Types
// ============================================================================

let convertSourceLocation = (loc: Snapshot.SourceLocation.t): Client__Types.SourceLocation.t => {
  let rec convert = (l: Snapshot.SourceLocation.t): Client__Types.SourceLocation.t => {
    componentName: l.componentName,
    tagName: l.tagName,
    file: l.file,
    line: l.line,
    column: l.column,
    parent: l.parent->Option.map(convert),
  }
  convert(loc)
}

let convertFigmaNode = (node: Snapshot.FigmaNode.t): StateTypes.FigmaNode.t => {
  switch node {
  | NoSelection => NoSelection
  | WaitingForSelection => WaitingForSelection
  | SelectedNode({nodeId, nodeData, image, isDsl}) => SelectedNode({nodeId, nodeData, image, isDsl})
  }
}

let convertUserContentPart = (part: Snapshot.UserContentPart.t): StateTypes.UserContentPart.t => {
  switch part {
  | Text({text}) => Text({text: text})
  | Image({image, mediaType}) => Image({image, mediaType})
  | File({file}) => File({file: file})
  }
}

let convertAssistantContentPart = (
  part: Snapshot.AssistantContentPart.t,
): StateTypes.AssistantContentPart.t => {
  switch part {
  | Text({text}) => Text({text: text})
  | ToolCall({toolCallId, toolName, input}) => ToolCall({toolCallId, toolName, input})
  }
}

let convertToolCallState = (state: Snapshot.ToolCallState.t): StateTypes.Message.toolCallState => {
  switch state {
  | InputStreaming => InputStreaming
  | InputAvailable => InputAvailable
  | OutputAvailable => OutputAvailable
  | OutputError => OutputError
  }
}

let convertToolCall = (tc: Snapshot.ToolCall.t): StateTypes.Message.toolCall => {
  id: tc.id,
  toolName: tc.toolName,
  state: convertToolCallState(tc.state),
  inputBuffer: tc.inputBuffer,
  input: tc.input,
  result: tc.result,
  errorText: tc.errorText,
  createdAt: tc.createdAt,
  parentAgentId: tc.parentAgentId,
  spawningToolName: tc.spawningToolName,
}

let convertAssistantMessage = (
  msg: Snapshot.AssistantMessage.t,
): StateTypes.Message.assistantMessage => {
  switch msg {
  | Streaming({id, textBuffer, createdAt}) => Streaming({id, textBuffer, createdAt})
  | Completed({id, content, createdAt}) =>
    Completed({
      id,
      content: content->Array.map(convertAssistantContentPart),
      createdAt,
    })
  }
}

let convertMessage = (msg: Snapshot.Message.t): StateTypes.Message.t => {
  switch msg {
  | User({id, content, createdAt}) =>
    User({
      id,
      content: content->Array.map(convertUserContentPart),
      createdAt,
    })
  | Assistant(assistantMsg) => Assistant(convertAssistantMessage(assistantMsg))
  | ToolCall(tc) => ToolCall(convertToolCall(tc))
  }
}

let convertPlanEntry = (
  entry: Snapshot.PlanEntry.t,
): AskTheLlmFrontmanClient.FrontmanClient__ACP__Types.planEntry => {
  let priority = switch entry.priority {
  | High => AskTheLlmFrontmanClient.FrontmanClient__ACP__Types.High
  | Medium => AskTheLlmFrontmanClient.FrontmanClient__ACP__Types.Medium
  | Low => AskTheLlmFrontmanClient.FrontmanClient__ACP__Types.Low
  }
  let status = switch entry.status {
  | Pending => AskTheLlmFrontmanClient.FrontmanClient__ACP__Types.Pending
  | InProgress => AskTheLlmFrontmanClient.FrontmanClient__ACP__Types.InProgress
  | Completed => AskTheLlmFrontmanClient.FrontmanClient__ACP__Types.Completed
  }
  {content: entry.content, priority, status}
}

let convertTask = (task: Snapshot.Task.t): StateTypes.Task.t => {
  // Convert messages array to Dict
  let messagesDict = Dict.make()
  task.messages->Array.forEach(msg => {
    let liveMsg = convertMessage(msg)
    messagesDict->Dict.set(Snapshot.Message.getId(msg), liveMsg)
  })

  {
    id: task.id,
    title: task.title,
    messages: messagesDict,
    createdAt: task.createdAt,
    lastMessageAt: task.lastMessageAt,
    previewFrame: {
      url: task.previewUrl,
      contentDocument: None,
      contentWindow: None,
    },
    webPreviewIsSelecting: task.webPreviewIsSelecting,
    selectedElement: None, // Cannot restore DOM element from snapshot
    figmaNode: convertFigmaNode(task.figmaNode),
    planEntries: task.planEntries->Array.map(convertPlanEntry),
    isAgentRunning: false, // Default to not running when restoring from snapshot
    todoBatchEvents: [], // Todo events not stored in snapshots - derived from tool calls
    todoStatusEvents: [],
  }
}

/** Convert a snapshot to live state */
let snapshotToState = (snapshot: Snapshot.t): StateTypes.state => {
  let tasksDict = Dict.make()
  snapshot.tasks->Array.forEach(task => {
    let liveTask = convertTask(task)
    tasksDict->Dict.set(task.id, liveTask)
  })

  {
    tasks: tasksDict,
    currentTaskId: snapshot.currentTaskId,
    connectionState: Disconnected, // Cannot restore connection from snapshot
    sessionInitialized: snapshot.sessionInitialized,
  }
}

// ============================================================================
// Storybook Helpers
// ============================================================================

/** Load a snapshot from JSON string and apply it to the store */
let loadSnapshot = (jsonString: string): result<unit, string> => {
  switch Snapshot.fromJsonString(jsonString) {
  | Ok(snapshot) => {
      let state = snapshotToState(snapshot)
      AskTheLlmReactStatestore.StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
        Client__State__Store.store,
        state,
      )
      Ok()
    }
  | Error(err) => Error(err)
  }
}

/** Load a snapshot object and apply it to the store */
let loadSnapshotFromObject = (snapshot: Snapshot.t): unit => {
  let state = snapshotToState(snapshot)
  AskTheLlmReactStatestore.StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    state,
  )
}

/** Reset the store to default state */
let resetState = (): unit => {
  AskTheLlmReactStatestore.StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    Client__State__StateReducer.defaultState,
  )
}

/**
 * Create a Storybook decorator that loads a snapshot before rendering
 *
 * Usage:
 * ```rescript
 * let myStory: Story.t<args> = {
 *   decorators: [withSnapshot(`{"tasks": [...]}`)],
 *   render: _ => <MyComponent />,
 * }
 * ```
 */
let withSnapshot = (jsonString: string): ((unit => React.element) => React.element) => {
  storyFn => {
    // Load snapshot on first render
    React.useEffect0(() => {
      switch loadSnapshot(jsonString) {
      | Ok() => Console.log("[Storybook] Snapshot loaded successfully")
      | Error(err) => Console.error2("[Storybook] Failed to load snapshot:", err)
      }

      // Cleanup: reset state when story unmounts
      Some(() => resetState())
    })

    storyFn()
  }
}

/**
 * Create a Storybook decorator that loads a snapshot object before rendering
 */
let withSnapshotObject = (snapshot: Snapshot.t): ((unit => React.element) => React.element) => {
  storyFn => {
    React.useEffect0(() => {
      loadSnapshotFromObject(snapshot)
      Console.log("[Storybook] Snapshot loaded successfully")

      Some(() => resetState())
    })

    storyFn()
  }
}

/**
 * MockStateProvider - A React component that wraps children with a loaded snapshot
 *
 * Usage in stories:
 * ```rescript
 * let myStory: Story.t<args> = {
 *   render: _ => {
 *     <MockStateProvider snapshotJson={`{"tasks": [...]}`}>
 *       <Client__Chatbox />
 *     </MockStateProvider>
 *   },
 * }
 * ```
 */
@react.component
let make = (~snapshotJson: string, ~children: React.element) => {
  let (loaded, setLoaded) = React.useState(() => false)
  let (error, setError) = React.useState((): option<string> => None)

  React.useEffect0(() => {
    switch loadSnapshot(snapshotJson) {
    | Ok() => {
        setLoaded(_ => true)
        Console.log("[Storybook] Snapshot loaded successfully")
      }
    | Error(err) => {
        setError(_ => Some(err))
        Console.error2("[Storybook] Failed to load snapshot:", err)
      }
    }

    Some(() => resetState())
  })

  switch error {
  | Some(err) =>
    <div style={{padding: "20px", color: "red", backgroundColor: "#1a1a1a"}}>
      <h3> {React.string("Failed to load snapshot")} </h3>
      <pre> {React.string(err)} </pre>
    </div>
  | None =>
    if loaded {
      children
    } else {
      <div style={{padding: "20px", color: "#888"}}> {React.string("Loading snapshot...")} </div>
    }
  }
}

/**
 * Variant that accepts a snapshot object directly
 */
module FromObject = {
  @react.component
  let make = (~snapshot: Snapshot.t, ~children: React.element) => {
    React.useEffect0(() => {
      loadSnapshotFromObject(snapshot)
      Console.log("[Storybook] Snapshot loaded successfully")

      Some(() => resetState())
    })

    children
  }
}
