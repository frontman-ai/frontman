open Bindings__Storybook

open Client__State__Types

let _forceState = (state: state) => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(Client__State__Store.store, state)
}

module Fixtures = {
  let makeTask = (
    ~id,
    ~title,
    ~createdAt,
    ~updatedAt=?,
    ~withMessages=false,
  ): Client__State__StateReducer.Task.t => {
    let updatedAt = updatedAt->Option.getOr(createdAt)
    let messages = switch withMessages {
    | true => [
        Client__State__StateReducer.Message.User({
          id: `msg-${id}`,
          content: [Client__State__StateReducer.UserContentPart.Text({text: "Hello"})],
          annotations: [],
          createdAt,
        }),
      ]
    | false => []
    }
    Client__State__StateReducer.Task.Loaded({
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

  let emptyState: state = {
    ...Client__State__StateReducer.defaultState,
    currentTask: Task.New(Task.makeNew(~previewUrl="http://localhost:3000")),
    selectedModelValue: None,
  }

  let stateWithTasks = (
    ~tasks: array<Client__State__StateReducer.Task.t>,
    ~currentTaskId=?,
  ): state => {
    let tasksDict = Dict.make()
    tasks->Array.forEach(task => {
      let taskId = Task.getId(task)->Option.getOrThrow(~message="[Fixtures] Task must have ID")
      tasksDict->Dict.set(taskId, task)
    })
    let currentTask = switch currentTaskId {
    | Some(id) => Task.Selected(id)
    | None => Task.New(Task.makeNew(~previewUrl="http://localhost:3000"))
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

module StateWrapper = {
  @react.component
  let make = (~state: state, ~children) => {
    let (_initialized, _setInitialized) = React.useState(() => {
      _forceState(state)
      true
    })

    React.useEffect0(() => Some(() => Client__StateSnapshot__Storybook.resetState()))

    children
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
    <StateWrapper state={Fixtures.emptyState}>
      <ContextWrapper>
        <div className="p-2 bg-[#130d20]">
          <Client__TopBar__TaskDropdown onNewTask={() => ()} />
        </div>
      </ContextWrapper>
    </StateWrapper>
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
    let state = Fixtures.stateWithTasks(~tasks=[task], ~currentTaskId="t1")
    <StateWrapper state={state}>
      <ContextWrapper>
        <div className="p-2 bg-[#130d20]">
          <Client__TopBar__TaskDropdown onNewTask={() => ()} />
        </div>
      </ContextWrapper>
    </StateWrapper>
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
    let state = Fixtures.stateWithTasks(~tasks, ~currentTaskId="task-3")
    <StateWrapper state={state}>
      <ContextWrapper>
        <div className="p-2 bg-[#130d20]">
          <Client__TopBar__TaskDropdown onNewTask={() => ()} />
        </div>
      </ContextWrapper>
    </StateWrapper>
  },
}
