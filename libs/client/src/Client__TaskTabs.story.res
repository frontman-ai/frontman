/**
 * TaskTabs Stories
 *
 * Tests the compact header bar with history dropdown.
 * Verifies the component renders correctly with various task states.
 */

open Bindings__Storybook

type args = unit

module StateReducer = Client__State__StateReducer
module StateTypes = Client__State__Types
module Store = Client__State__Store
module StateStore = FrontmanReactStatestore.StateStore

// Helper to force state for testing
let _forceState = (state: StateTypes.state) => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(Store.store, state)
}

// Helper to create a task with specific properties
module Fixtures = {
  let makeTask = (~id, ~title, ~createdAt, ~updatedAt=?, ~withMessages=false): StateReducer.Task.t => {
    let updatedAt = updatedAt->Option.getOr(createdAt)
    let messages = if withMessages {
      let msg = StateReducer.Message.User({
        id: `msg-${id}`,
        content: [StateReducer.UserContentPart.Text({text: "Hello"})],
        createdAt,
      })
      [msg]
    } else {
      []
    }

    // Use the Loaded variant constructor
    StateReducer.Task.Loaded({
      id,
      clientId: None,
      title,
      createdAt,
      updatedAt,
      messages: Client__MessageStore.fromArray(messages),
      previewFrame: {
        url: "http://localhost:3000",
        contentDocument: None,
        contentWindow: None,
        deviceMode: Client__DeviceMode.defaultDeviceMode,
        orientation: Client__DeviceMode.defaultOrientation,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      isAgentRunning: false,
      planEntries: [],
      turnError: None,
      imageAttachments: Dict.make(),
    })
  }

  let emptyState: StateTypes.state = {
    tasks: Dict.make(),
    currentTask: StateTypes.Task.New(StateTypes.Task.makeNew(~previewUrl="http://localhost:3000")),
    acpSession: NoAcpSession,
    sessionInitialized: false,
    usageInfo: None,
    userProfile: None,
    openrouterKeySettings: {
      source: StateTypes.None,
      saveStatus: StateTypes.Idle,
    },
    anthropicOAuthStatus: StateTypes.NotConnected,
    chatgptOAuthStatus: StateTypes.ChatGPTNotConnected,
    modelsConfig: None,
    selectedModel: None,
    pendingProviderAutoSelect: None,
    sessionsLoadState: StateTypes.SessionsNotLoaded,
  }

  let stateWithTasks = (~tasks: array<StateReducer.Task.t>, ~currentTaskId=?): StateTypes.state => {
    let tasksDict = Dict.make()
    tasks->Array.forEach(task => {
      let taskId = StateTypes.Task.getId(task)->Option.getOrThrow(
        ~message="[Fixtures] Task must have ID",
      )
      tasksDict->Dict.set(taskId, task)
    })
    let currentTask = switch currentTaskId {
    | Some(id) => StateTypes.Task.Selected(id)
    | None => StateTypes.Task.New(StateTypes.Task.makeNew(~previewUrl="http://localhost:3000"))
    }
    {
      ...emptyState,
      tasks: tasksDict,
      currentTask,
    }
  }
}

// Wrapper that provides the FrontmanProvider context
module ContextWrapper = {
  @react.component
  let make = (~children) => {
    <Client__FrontmanProvider.ContextProvider value={Client__FrontmanProvider.defaultContextValue}>
      {children}
    </Client__FrontmanProvider.ContextProvider>
  }
}

let default: Meta.t<args> = {
  title: "Components/TaskTabs",
  component: Obj.magic(Client__TaskTabs.make),
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

/**
 * Empty state - no tasks yet.
 * The "New" button should be visible.
 */
let noTasks: Story.t<args> = {
  name: "No Tasks",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })

    <ContextWrapper>
      <div style={{width: "400px", backgroundColor: "#18181b"}}>
        <Client__TaskTabs onSettingsClick={() => ()} />
      </div>
    </ContextWrapper>
  },
}

/**
 * Single task with no messages - the exact scenario that caused the crash.
 * A freshly created task has no messages, so lastMessageAt was None.
 * This story would have caught the getOrThrow crash immediately.
 */
let singleEmptyTask: Story.t<args> = {
  name: "Single Empty Task (Regression Test)",
  render: _ => {
    let task = Fixtures.makeTask(
      ~id="task-1",
      ~title="New Chat",
      ~createdAt=Date.now(),
      ~withMessages=false,
    )

    React.useEffect0(() => {
      _forceState(Fixtures.stateWithTasks(~tasks=[task], ~currentTaskId="task-1"))
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })

    <ContextWrapper>
      <div style={{width: "400px", backgroundColor: "#18181b"}}>
        <Client__TaskTabs onSettingsClick={() => ()} />
      </div>
    </ContextWrapper>
  },
}

/**
 * Single task with messages - normal state after user has chatted.
 */
let singleTaskWithMessages: Story.t<args> = {
  name: "Single Task With Messages",
  render: _ => {
    let task = Fixtures.makeTask(
      ~id="task-1",
      ~title="Help with login bug",
      ~createdAt=Date.now(),
      ~withMessages=true,
    )

    React.useEffect0(() => {
      _forceState(Fixtures.stateWithTasks(~tasks=[task], ~currentTaskId="task-1"))
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })

    <ContextWrapper>
      <div style={{width: "400px", backgroundColor: "#18181b"}}>
        <Client__TaskTabs onSettingsClick={() => ()} />
      </div>
    </ContextWrapper>
  },
}

/**
 * Multiple tasks - tests sorting by updatedAt.
 * Tasks should appear with most recently updated first.
 */
let multipleTasks: Story.t<args> = {
  name: "Multiple Tasks",
  render: _ => {
    let now = Date.now()
    let tasks = [
      Fixtures.makeTask(
        ~id="task-1",
        ~title="First task",
        ~createdAt=now -. 3600000.0, // 1 hour ago
        ~updatedAt=now -. 1800000.0, // 30 min ago
        ~withMessages=true,
      ),
      Fixtures.makeTask(
        ~id="task-2",
        ~title="Second task",
        ~createdAt=now -. 7200000.0, // 2 hours ago
        ~updatedAt=now, // just now (most recent)
        ~withMessages=true,
      ),
      Fixtures.makeTask(
        ~id="task-3",
        ~title="Third task (empty)",
        ~createdAt=now -. 600000.0, // 10 min ago
        ~withMessages=false, // No messages - tests the fix
      ),
    ]

    React.useEffect0(() => {
      _forceState(Fixtures.stateWithTasks(~tasks, ~currentTaskId="task-2"))
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })

    <ContextWrapper>
      <div style={{width: "500px", backgroundColor: "#18181b"}}>
        <Client__TaskTabs onSettingsClick={() => ()} />
      </div>
    </ContextWrapper>
  },
}

/**
 * Mix of empty and populated tasks - comprehensive test.
 * This is the most realistic scenario: some tasks have messages, some don't.
 */
let mixedTasks: Story.t<args> = {
  name: "Mixed Tasks (Empty and Populated)",
  render: _ => {
    let now = Date.now()
    let tasks = [
      Fixtures.makeTask(
        ~id="task-1",
        ~title="Active conversation",
        ~createdAt=now -. 3600000.0,
        ~updatedAt=now,
        ~withMessages=true,
      ),
      Fixtures.makeTask(
        ~id="task-2",
        ~title="Just created",
        ~createdAt=now -. 60000.0,
        ~withMessages=false, // Empty - user just clicked "New"
      ),
      Fixtures.makeTask(
        ~id="task-3",
        ~title="Old chat",
        ~createdAt=now -. 86400000.0, // 1 day ago
        ~updatedAt=now -. 86400000.0,
        ~withMessages=true,
      ),
      Fixtures.makeTask(
        ~id="task-4",
        ~title="Another empty one",
        ~createdAt=now -. 120000.0,
        ~withMessages=false,
      ),
    ]

    React.useEffect0(() => {
      _forceState(Fixtures.stateWithTasks(~tasks, ~currentTaskId="task-1"))
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })

    <ContextWrapper>
      <div style={{width: "600px", backgroundColor: "#18181b"}}>
        <Client__TaskTabs onSettingsClick={() => ()} />
      </div>
    </ContextWrapper>
  },
}

/**
 * Many tasks — tests the history dropdown with many entries.
 */
let manyTasksOverflow: Story.t<args> = {
  name: "Many Tasks (Overflow)",
  render: _ => {
    let now = Date.now()
    let tasks = Array.fromInitializer(~length=15, i => {
      let idx = Int.toString(i + 1)
      Fixtures.makeTask(
        ~id=`task-${idx}`,
        ~title=`Task ${idx}: ${switch mod(i, 4) {
          | 0 => "Fix login page styling"
          | 1 => "Add dark mode support"
          | 2 => "Refactor API client"
          | _ => "Update dependencies"
          }}`,
        ~createdAt=now -. Int.toFloat((15 - i) * 3600000),
        ~updatedAt=now -. Int.toFloat(i * 600000),
        ~withMessages=true,
      )
    })

    React.useEffect0(() => {
      _forceState(Fixtures.stateWithTasks(~tasks, ~currentTaskId="task-8"))
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })

    <ContextWrapper>
      <div style={{width: "600px", backgroundColor: "#18181b"}}>
        <Client__TaskTabs onSettingsClick={() => ()} />
      </div>
    </ContextWrapper>
  },
}

/**
 * 8 tasks in a narrow 300px container — tests compact layout.
 */
let narrowContainer: Story.t<args> = {
  name: "Narrow Container",
  render: _ => {
    let now = Date.now()
    let tasks = Array.fromInitializer(~length=8, i => {
      let idx = Int.toString(i + 1)
      Fixtures.makeTask(
        ~id=`task-${idx}`,
        ~title=`Task ${idx}: Some descriptive title`,
        ~createdAt=now -. Int.toFloat((8 - i) * 3600000),
        ~updatedAt=now -. Int.toFloat(i * 300000),
        ~withMessages=mod(i, 2) == 0,
      )
    })

    React.useEffect0(() => {
      _forceState(Fixtures.stateWithTasks(~tasks, ~currentTaskId="task-5"))
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })

    <ContextWrapper>
      <div style={{width: "300px", backgroundColor: "#18181b"}}>
        <Client__TaskTabs onSettingsClick={() => ()} />
      </div>
    </ContextWrapper>
  },
}
