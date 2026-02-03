module UI = Bindings__UI__Tabs
module Button = Bindings__UI__Button
module Icons = Bindings__RadixUI__Icons
module AlertDialog = Bindings__UI__AlertDialog
module Input = Bindings__UI__Input
module Tooltip = Bindings__UI__Tooltip
module DropdownMenu = Bindings__UI__DropdownMenu

// DOM bindings for overflow measurement
@get external clientWidth: Dom.element => int = "clientWidth"

type resizeObserver
@new external makeResizeObserver: (unit => unit) => resizeObserver = "ResizeObserver"
@send external observeEl: (resizeObserver, Dom.element) => unit = "observe"
@send external disconnectObs: resizeObserver => unit = "disconnect"

// Width constants for overflow calculation
let tabWidth = 150
let newButtonWidth = 80
let overflowButtonWidth = 50
let settingsButtonWidth = 44

@react.component
let make = (~onSettingsClick: unit => unit) => {
  // Local UI state
  let (editingTaskId, setEditingTaskId) = React.useState(() => None)
  let (deleteDialogOpen, setDeleteDialogOpen) = React.useState(() => false)
  let (taskToDelete, setTaskToDelete) = React.useState(() => None)

  // Overflow state
  let containerRef = React.useRef(Nullable.null)
  let (visibleCount, setVisibleCount) = React.useState(() => 1000)

  // Get clearSession from FrontmanProvider context
  let {clearSession} = Client__FrontmanProvider.useFrontman()

  // Global state selectors
  let tasks = Client__State.useSelector(Client__State.Selectors.tasks)
  let currentTaskId = Client__State.useSelector(Client__State.Selectors.currentTaskId)
  let tasksLen = Array.length(tasks)

  // ResizeObserver effect — recalculate how many tabs fit
  React.useEffect2(() => {
    switch containerRef.current->Nullable.toOption {
    | Some(el) => {
        let recalc = () => {
          let containerW = clientWidth(el)
          let available = containerW - newButtonWidth - settingsButtonWidth
          let allFit = available >= tasksLen * tabWidth
          if allFit {
            setVisibleCount(_ => tasksLen)
          } else {
            let withOverflow = available - overflowButtonWidth
            let fits = Math.Int.max(1, withOverflow / tabWidth)
            setVisibleCount(_ => fits)
          }
        }
        recalc()
        let observer = makeResizeObserver(() => recalc())
        observer->observeEl(el)
        Some(() => disconnectObs(observer))
      }
    | None => None
    }
  }, (tasksLen, currentTaskId))

  // Compute visible / overflow split with active-task guarantee
  let (visibleTasks, overflowTasks) = React.useMemo3(() => {
    if visibleCount >= tasksLen {
      (tasks, [])
    } else {
      let visible = tasks->Array.slice(~start=0, ~end=visibleCount)
      let overflow = tasks->Array.slice(~start=visibleCount, ~end=tasksLen)

      // If the active task ended up in overflow, swap it into the last visible slot
      let activeInOverflow =
        currentTaskId->Option.flatMap(activeId =>
          overflow->Array.findIndex(t =>
            Client__Task__Types.Task.getId(t) == Some(activeId)
          )->Some
        )->Option.flatMap(idx => idx >= 0 ? Some(idx) : None)

      switch activeInOverflow {
      | Some(overflowIdx) => {
          let activeTask = overflow->Array.getUnsafe(overflowIdx)
          let lastVisibleIdx = Array.length(visible) - 1
          let displacedTask = visible->Array.getUnsafe(lastVisibleIdx)

          let newVisible = visible->Array.mapWithIndex((t, i) =>
            i == lastVisibleIdx ? activeTask : t
          )
          let newOverflow =
            overflow
            ->Array.filterWithIndex((_, i) => i != overflowIdx)
            ->Array.concat([displacedTask])
          (newVisible, newOverflow)
        }
      | None => (visible, overflow)
      }
    }
  }, (tasks, visibleCount, currentTaskId))

  // Event handlers
  let handleTabChange = (taskId: string) => {
    Client__State.Actions.switchTask(~taskId)
  }

  let handleNewTask = (_e: ReactEvent.Mouse.t) => {
    clearSession()
    Client__State.Actions.clearCurrentTask()
  }

  let handleDeleteClick = (e: ReactEvent.Mouse.t, taskId: string) => {
    ReactEvent.Mouse.stopPropagation(e)
    setTaskToDelete(_ => Some(taskId))
    setDeleteDialogOpen(_ => true)
  }

  let handleDeleteConfirm = (_e: ReactEvent.Mouse.t) => {
    switch taskToDelete {
    | Some(taskId) => {
        // If deleting the current task, tear down the session channel first
        // to prevent stale server messages from dispatching into a deleted task
        if currentTaskId == Some(taskId) {
          clearSession()
        }
        Client__State.Actions.deleteTask(~taskId)
        setDeleteDialogOpen(_ => false)
        setTaskToDelete(_ => None)
      }
    | None => ()
    }
  }

  let handleDeleteCancel = (_e: ReactEvent.Mouse.t) => {
    setDeleteDialogOpen(_ => false)
    setTaskToDelete(_ => None)
  }

  // Tab rendering function - memoized to avoid recreating on every render
  let renderTab = React.useCallback2(
    (task: Client__State__StateReducer.Task.t, isEditing: bool) => {
      let taskId =
        Client__Task__Types.Task.getId(task)->Option.getOrThrow(
          ~message="[TaskTabs] Task in dict has no ID",
        )
      let taskTitle = Client__Task__Types.Task.getTitle(task)->Option.getOr("Untitled")

      let handleDoubleClick = (_e: ReactEvent.Mouse.t) => {
        setEditingTaskId(_ => Some(taskId))
      }

      <Tooltip.Tooltip key={taskId}>
        <Tooltip.TooltipTrigger asChild=true>
          <UI.TabsTrigger
            value={taskId}
            className="w-[150px] shrink-0 px-2 flex items-center gap-2 relative group cursor-pointer bg-transparent data-[state=active]:bg-transparent"
          >
            {isEditing
              ? <Input.Input
                  autoFocus={true}
                  defaultValue={taskTitle}
                  className="w-full text-xs"
                  onKeyDown={e => {
                    let key = e->ReactEvent.Keyboard.key
                    if key == "Enter" {
                      let target = ReactEvent.Keyboard.target(e)
                      let newTitle = target["value"]->String.trim
                      if String.length(newTitle) > 0 {
                        Client__State.Actions.updateTaskTitle(~taskId, ~title=newTitle)
                      }
                      setEditingTaskId(_ => None)
                      ReactEvent.Keyboard.preventDefault(e)
                    } else if key == "Escape" {
                      setEditingTaskId(_ => None)
                      ReactEvent.Keyboard.preventDefault(e)
                    }
                  }}
                  onBlur={e => {
                    let target = ReactEvent.Focus.target(e)
                    let newTitle = target["value"]->String.trim
                    if String.length(newTitle) > 0 {
                      Client__State.Actions.updateTaskTitle(~taskId, ~title=newTitle)
                    }
                    setEditingTaskId(_ => None)
                  }}
                />
              : <>
                  <span
                    className="truncate text-xs cursor-pointer"
                    onDoubleClick={handleDoubleClick}
                  >
                    {React.string(taskTitle)}
                  </span>
                  <span
                    className="ml-auto p-0.5 rounded-sm opacity-0 group-hover:opacity-100 data-[state=active]:opacity-100 hover:bg-accent transition-opacity duration-150 cursor-pointer"
                    onClick={e => handleDeleteClick(e, taskId)}
                  >
                    <Icons.Cross2Icon style={{"width": "14px", "height": "14px"}} />
                  </span>
                </>}
          </UI.TabsTrigger>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent sideOffset=4>
          {React.string(taskTitle)}
        </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
    },
    (setEditingTaskId, handleDeleteClick),
  )

  let overflowCount = Array.length(overflowTasks)

  // Main render
  <div className="h-12 border-b" ref={ReactDOM.Ref.domRef(containerRef)}>
    <UI.Tabs
      value={currentTaskId->Option.getOr("")} onValueChange={handleTabChange} className="h-full"
    >
      <UI.TabsList
        className="h-full w-full rounded-none justify-start overflow-hidden bg-transparent p-0"
      >
        {visibleTasks
        ->Array.map(task =>
          renderTab(task, editingTaskId == Client__Task__Types.Task.getId(task))
        )
        ->React.array}
        {overflowCount > 0
          ? <DropdownMenu.DropdownMenu>
              <DropdownMenu.DropdownMenuTrigger asChild=true>
                <Button.Button
                  variant=#ghost
                  size=#sm
                  className="cursor-pointer gap-1 shrink-0 px-2"
                >
                  <span className="text-xs font-medium">
                    {React.string(`+${Int.toString(overflowCount)}`)}
                  </span>
                  <Icons.ChevronDownIcon style={{"width": "12px", "height": "12px"}} />
                </Button.Button>
              </DropdownMenu.DropdownMenuTrigger>
              <DropdownMenu.DropdownMenuContent align="start" sideOffset=4>
                <DropdownMenu.DropdownMenuLabel>
                  {React.string("More tasks")}
                </DropdownMenu.DropdownMenuLabel>
                <DropdownMenu.DropdownMenuSeparator />
                {overflowTasks
                ->Array.map(task => {
                  let taskId =
                    Client__Task__Types.Task.getId(task)->Option.getOrThrow(
                      ~message="[TaskTabs] Overflow task has no ID",
                    )
                  let taskTitle =
                    Client__Task__Types.Task.getTitle(task)->Option.getOr("Untitled")
                  let isActive = currentTaskId == Some(taskId)
                  <DropdownMenu.DropdownMenuItem
                    key={taskId}
                    className={isActive ? "font-semibold" : ""}
                    onSelect={_ => handleTabChange(taskId)}
                  >
                    {React.string(taskTitle)}
                  </DropdownMenu.DropdownMenuItem>
                })
                ->React.array}
              </DropdownMenu.DropdownMenuContent>
            </DropdownMenu.DropdownMenu>
          : React.null}
        <Button.Button
          variant=#ghost size=#sm onClick={handleNewTask} className="cursor-pointer gap-1 shrink-0"
        >
          <Icons.PlusIcon style={{"width": "14px", "height": "14px"}} />
          <span className="text-xs"> {React.string("New")} </span>
        </Button.Button>
        <div className="ml-auto shrink-0">
          <button
            type_="button"
            className="h-9 w-9 rounded-lg border border-zinc-800/70 bg-zinc-900/70 text-zinc-200 shadow-sm backdrop-blur transition-all duration-200 flex items-center justify-center hover:border-zinc-700 hover:bg-zinc-800/90 hover:shadow-md cursor-pointer"
            onClick={_ => onSettingsClick()}
            title="Settings"
          >
            <Icons.GearIcon style={{"width": "16px", "height": "16px"}} />
          </button>
        </div>
      </UI.TabsList>
    </UI.Tabs>
    <AlertDialog.AlertDialog
      open_={deleteDialogOpen} onOpenChange={open_ => setDeleteDialogOpen(_ => open_)}
    >
      <AlertDialog.AlertDialogContent>
        <AlertDialog.AlertDialogHeader>
          <AlertDialog.AlertDialogTitle>
            {React.string("Delete task?")}
          </AlertDialog.AlertDialogTitle>
          <AlertDialog.AlertDialogDescription>
            {React.string(
              "This will permanently delete this conversation. This action cannot be undone.",
            )}
          </AlertDialog.AlertDialogDescription>
        </AlertDialog.AlertDialogHeader>
        <AlertDialog.AlertDialogFooter>
          <AlertDialog.AlertDialogCancel onClick={handleDeleteCancel}>
            {React.string("Cancel")}
          </AlertDialog.AlertDialogCancel>
          <AlertDialog.AlertDialogAction
            onClick={handleDeleteConfirm}
            className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
          >
            {React.string("Delete")}
          </AlertDialog.AlertDialogAction>
        </AlertDialog.AlertDialogFooter>
      </AlertDialog.AlertDialogContent>
    </AlertDialog.AlertDialog>
  </div>
}
