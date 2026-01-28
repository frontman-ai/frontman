module UI = Bindings__UI__Tabs
module Button = Bindings__UI__Button
module Icons = Bindings__RadixUI__Icons
module AlertDialog = Bindings__UI__AlertDialog
module Input = Bindings__UI__Input

@react.component
let make = () => {
  // Local UI state
  let (editingTaskId, setEditingTaskId) = React.useState(() => None)
  let (deleteDialogOpen, setDeleteDialogOpen) = React.useState(() => false)
  let (taskToDelete, setTaskToDelete) = React.useState(() => None)

  // Get clearSession from FrontmanProvider context
  let {clearSession} = Client__FrontmanProvider.useFrontman()

  // Global state selectors
  let tasks = Client__State.useSelector(Client__State.Selectors.tasks)
  let currentTaskId = Client__State.useSelector(Client__State.Selectors.currentTaskId)

  // Event handlers
  let handleTabChange = (taskId: string) => {
    Client__State.Actions.switchTask(~taskId)
  }

  let handleNewTask = (_e: ReactEvent.Mouse.t) => {
    // Clear both the ACP session and the current task selection
    // The new task will be created when user sends their first message (lazy session creation)
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
      // Tasks in the dict always have IDs (not New tasks)
      let taskId =
        Client__Task__Types.Task.getId(task)->Option.getOrThrow(
          ~message="[TaskTabs] Task in dict has no ID",
        )
      let taskTitle = Client__Task__Types.Task.getTitle(task)->Option.getOr("Untitled")

      let handleDoubleClick = (_e: ReactEvent.Mouse.t) => {
        setEditingTaskId(_ => Some(taskId))
      }

      <UI.TabsTrigger
        key={taskId}
        value={taskId}
        className="min-w-[80px] max-w-[120px] px-2 flex items-center gap-2 relative group cursor-pointer bg-transparent data-[state=active]:bg-transparent"
      >
        {isEditing
          ? <Input.Input
              autoFocus={true}
              defaultValue={taskTitle}
              className="max-w-[90px] text-xs"
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
                className="truncate max-w-[90px] text-xs cursor-pointer"
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
    },
    (setEditingTaskId, handleDeleteClick),
  )

  // Main render
  <div className="h-12 border-b">
    <UI.Tabs
      value={currentTaskId->Option.getOr("")} onValueChange={handleTabChange} className="h-full"
    >
      <UI.TabsList
        className="h-full w-full rounded-none justify-start overflow-x-auto bg-transparent p-0"
      >
        {tasks
        ->Array.map(task =>
          renderTab(task, editingTaskId == Client__Task__Types.Task.getId(task))
        )
        ->React.array}
        <Button.Button
          variant=#ghost size=#sm onClick={handleNewTask} className="cursor-pointer gap-1"
        >
          <Icons.PlusIcon style={{"width": "14px", "height": "14px"}} />
          <span className="text-xs"> {React.string("New")} </span>
        </Button.Button>
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
