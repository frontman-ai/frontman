open Bindings__Storybook

module StateReducer = Client__State__StateReducer
module StateTypes = Client__State__Types
module Store = Client__State__Store

let _forceState = (state: StateTypes.state) => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(Store.store, state)
}

module Fixtures = {
  let makeTask = (
    ~id,
    ~title,
    ~createdAt,
    ~updatedAt=?,
    ~withMessages=false,
  ): StateReducer.Task.t => {
    let updatedAt = updatedAt->Option.getOr(createdAt)
    let messages = if withMessages {
      let msg = StateReducer.Message.User({
        id: `msg-${id}`,
        content: [StateReducer.UserContentPart.Text({text: "Hello"})],
        annotations: [],
        createdAt,
      })
      [msg]
    } else {
      []
    }
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
      annotationMode: Client__Annotation__Types.Off,
      annotations: [],
      activePopupAnnotationId: None,
      isAnimationFrozen: false,
      isAgentRunning: false,
      planEntries: [],
      turnError: None,
      retryStatus: None,
      imageAttachments: Dict.make(),
      pendingQuestion: None,
    })
  }

  let emptyState: StateTypes.state = {
    tasks: Dict.make(),
    currentTask: StateTypes.Task.New(StateTypes.Task.makeNew(~previewUrl="http://localhost:3000")),
    acpSession: NoAcpSession,
    sessionInitialized: false,
    usageInfo: None,
    userProfile: None,
    openrouterKeySettings: {source: StateTypes.None, saveStatus: StateTypes.Idle},
    anthropicKeySettings: {source: StateTypes.None, saveStatus: StateTypes.Idle},
    anthropicOAuthStatus: StateTypes.NotConnected,
    chatgptOAuthStatus: StateTypes.ChatGPTNotConnected,
    configOptions: None,
    selectedModelValue: None,
    pendingProviderAutoSelect: None,
    sessionsLoadState: StateTypes.SessionsNotLoaded,
    updateInfo: None,
    updateCheckStatus: StateTypes.UpdateNotChecked,
    updateBannerDismissed: false,
  }

  let stateWithTasks = (~tasks: array<StateReducer.Task.t>, ~currentTaskId=?): StateTypes.state => {
    let tasksDict = Dict.make()
    tasks->Array.forEach(task => {
      let taskId =
        StateTypes.Task.getId(task)->Option.getOrThrow(~message="[Fixtures] Task must have ID")
      tasksDict->Dict.set(taskId, task)
    })
    let currentTask = switch currentTaskId {
    | Some(id) => StateTypes.Task.Selected(id)
    | None => StateTypes.Task.New(StateTypes.Task.makeNew(~previewUrl="http://localhost:3000"))
    }
    {...emptyState, tasks: tasksDict, currentTask}
  }
}

module ContextWrapper = {
  @react.component
  let make = (~children) => {
    <Client__FrontmanProvider.ContextProvider value={Client__FrontmanProvider.defaultContextValue}>
      {children}
    </Client__FrontmanProvider.ContextProvider>
  }
}

type args = unit

let default: Meta.t<args> = {
  title: "Components/TopBar/TaskDropdown",
  component: Obj.magic(Client__TopBar__TaskDropdown.make),
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

let noTasks: Story.t<args> = {
  name: "No Tasks",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div className="p-2 bg-[#130d20]">
        <Client__TopBar__TaskDropdown onNewTask={() => ()} />
      </div>
    </ContextWrapper>
  },
}

let singleTask: Story.t<args> = {
  name: "Single Task (active)",
  render: _ => {
    let task = Fixtures.makeTask(
      ~id="t1",
      ~title="Fix login page",
      ~createdAt=Date.now(),
      ~withMessages=true,
    )
    React.useEffect0(() => {
      _forceState(Fixtures.stateWithTasks(~tasks=[task], ~currentTaskId="t1"))
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div className="p-2 bg-[#130d20]">
        <Client__TopBar__TaskDropdown onNewTask={() => ()} />
      </div>
    </ContextWrapper>
  },
}

let manyTasks: Story.t<args> = {
  name: "Many Tasks",
  render: _ => {
    let now = Date.now()
    let tasks = Array.fromInitializer(~length=10, i => {
      let idx = Int.toString(i + 1)
      Fixtures.makeTask(
        ~id=`task-${idx}`,
        ~title=`Task ${idx}: ${switch mod(i, 3) {
          | 0 => "Fix authentication bug"
          | 1 => "Add dark mode support"
          | _ => "Refactor API client"
          }}`,
        ~createdAt=now -. Int.toFloat((10 - i) * 3600000),
        ~updatedAt=now -. Int.toFloat(i * 600000),
        ~withMessages=true,
      )
    })
    React.useEffect0(() => {
      _forceState(Fixtures.stateWithTasks(~tasks, ~currentTaskId="task-3"))
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div className="p-2 bg-[#130d20]">
        <Client__TopBar__TaskDropdown onNewTask={() => ()} />
      </div>
    </ContextWrapper>
  },
}
