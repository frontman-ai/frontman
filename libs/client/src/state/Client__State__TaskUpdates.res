include Client__State__Protocol

module Task = Client__State__Types.Task
module Selectors = Client__State__Selectors

module Lens = {
  let updateTask = (state: state, taskId: string, fn: Task.t => Task.t): state => {
    let task = state.tasks->Dict.get(taskId)->Option.getOrThrow
    let updated = fn(task)
    let tasks = state.tasks->Dict.copy
    tasks->Dict.set(taskId, updated)
    {...state, tasks}
  }

  let delegateToNewTask = (state: state, task: Task.t, taskAction: TaskReducer.action) => {
    let (updated, taskEffects) = TaskReducer.next(task, taskAction)
    let wrappedEffects =
      taskEffects->Array.map(eff => TaskEffect({target: CurrentTask, effect: eff}))
    {...state, currentTask: Task.New(updated)}->StateReducer.update(~sideEffects=wrappedEffects)
  }

  let delegateToTaskId = (state: state, taskId: string, taskAction: TaskReducer.action) => {
    let task = state.tasks->Dict.get(taskId)->Option.getOrThrow
    let (updated, taskEffects) = TaskReducer.next(task, taskAction)
    let wrappedEffects =
      taskEffects->Array.map(eff => TaskEffect({target: ForTask(taskId), effect: eff}))
    let tasks = state.tasks->Dict.copy
    tasks->Dict.set(taskId, updated)
    {...state, tasks}->StateReducer.update(~sideEffects=wrappedEffects)
  }

  let delegateToTask = (state: state, target: taskTarget, taskAction: TaskReducer.action) => {
    switch (target, state.currentTask) {
    | (CurrentTask, Task.New(task)) => delegateToNewTask(state, task, taskAction)
    | (CurrentTask, Task.Selected(taskId)) | (ForTask(taskId), _) =>
      delegateToTaskId(state, taskId, taskAction)
    }
  }
}

let addUserMessageToState = (
  state: state,
  ~sessionId,
  submission: Client__State__Types.submission,
) => {
  let {id, timestamp, content, annotations, agentId} = submission
  let handoff = Selectors.pendingPlanHandoff(state)->Option.isSome
  let (state, taskId) = switch state.currentTask {
  | Task.New(Task.New(draft)) =>
    let tasks = state.tasks->Dict.copy
    tasks->Dict.set(
      sessionId,
      Task.Loaded(
        Task.promoteDraft(
          draft,
          ~id=sessionId,
          ~title=TaskReducer.extractTextFromUserContent(content),
          ~timestamp,
        ),
      ),
    )
    ({...state, tasks, currentTask: Task.Selected(sessionId)}, sessionId)
  | Task.New(Task.Unloaded(_) | Task.Loading(_) | Task.Loaded(_)) =>
    failwith("[addUserMessageToState] New task selection must contain a draft")
  | Task.Selected(taskId) => (state, taskId)
  }
  let (state, effects) =
    state->Lens.delegateToTask(
      ForTask(taskId),
      TaskReducer.AddUserMessage({id, timestamp, content, annotations, agentId}),
    )
  let (state, runningEffects) = switch handoff {
  | true => state->Lens.delegateToTask(ForTask(taskId), TaskReducer.ExecutionStateRunning([]))
  | false => (state, [])
  }
  state->StateReducer.update(
    ~sideEffects=Array.concat(effects, runningEffects)->Array.concat([
      SendMessage({taskId, submission}),
    ]),
  )
}
