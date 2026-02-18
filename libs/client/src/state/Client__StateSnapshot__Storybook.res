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
    componentProps: l.componentProps,
  }
  convert(loc)
}

let convertUserContentPart = (part: Snapshot.UserContentPart.t): StateTypes.UserContentPart.t => {
  switch part {
  | Text({text}) => Text({text: text})
  | Image({image, mediaType, name}) => Image({image, mediaType, name})
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

let convertTask = (task: Snapshot.Task.t): StateTypes.Task.t => {
  // Convert messages array and wrap in MessageStore
  let messages = task.messages->Array.map(convertMessage)
  let messageStore = Client__MessageStore.fromArray(messages)

  // Create a Loaded task using the variant constructor
  StateTypes.Task.Loaded({
    id: task.id,
    clientId: None,
    title: task.title,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    messages: messageStore,
    previewFrame: {
      url: task.previewUrl,
      contentDocument: None,
      contentWindow: None,
      deviceMode: Client__DeviceMode.defaultDeviceMode,
      orientation: Client__DeviceMode.defaultOrientation,
    },
    webPreviewIsSelecting: task.webPreviewIsSelecting,
    selectedElement: None, // Cannot restore DOM element from snapshot
    isAgentRunning: false, // Default to not running when restoring from snapshot
    planEntries: [], // Plan entries not stored in snapshots yet
    turnError: None, // No error when restoring from snapshot
  })
}

/** Convert a snapshot to live state */
let snapshotToState = (snapshot: Snapshot.t): StateTypes.state => {
  let tasksDict = Dict.make()
  snapshot.tasks->Array.forEach(task => {
    let liveTask = convertTask(task)
    tasksDict->Dict.set(task.id, liveTask)
  })

  // Convert currentTaskId to currentTask type
  let currentTask = switch snapshot.currentTaskId {
  | Some(id) => StateTypes.Task.Selected(id)
  | None =>
    // No current task in snapshot - create a new ephemeral task
    StateTypes.Task.New(StateTypes.Task.makeNew(~previewUrl="http://localhost:3000"))
  }

  {
    tasks: tasksDict,
    currentTask,
    acpSession: NoAcpSession, // Cannot restore ACP session from snapshot
    sessionInitialized: snapshot.sessionInitialized,
    usageInfo: None,
    userProfile: None,
    openrouterKeySettings: {
      source: Client__State__Types.None,
      saveStatus: Client__State__Types.Idle,
    },
    anthropicOAuthStatus: Client__State__Types.NotConnected,
    chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
    modelsConfig: None,
    selectedModel: None,
    sessionsLoadState: Client__State__Types.SessionsNotLoaded, // Cannot restore load state from snapshot
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
      FrontmanReactStatestore.StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
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
  FrontmanReactStatestore.StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    state,
  )
}

/** Reset the store to default state */
let resetState = (): unit => {
  FrontmanReactStatestore.StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
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
