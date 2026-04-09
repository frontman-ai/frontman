module Icons = Bindings__RadixUI__Icons
module AlertDialog = Bindings__UI__AlertDialog
module DropdownMenu = Bindings__UI__DropdownMenu
module Tooltip = Bindings__UI__Tooltip

@react.component
let make = (~onNewTask: unit => unit) => {
  let (deleteDialogOpen, setDeleteDialogOpen) = React.useState(() => false)
  let (taskToDelete, setTaskToDelete) = React.useState(() => None)
  let (search, setSearch) = React.useState(() => "")

  let {clearSession} = Client__FrontmanProvider.useFrontman()

  let tasks = Client__State.useSelector(Client__State.Selectors.tasks)
  let currentTaskId = Client__State.useSelector(Client__State.Selectors.currentTaskId)

  let currentTaskTitle = React.useMemo2(() => {
    switch currentTaskId {
    | Some(id) =>
      tasks
      ->Array.find(t => Client__Task__Types.Task.getId(t) == Some(id))
      ->Option.flatMap(t => Client__Task__Types.Task.getTitle(t))
      ->Option.getOr("New Task")
    | None => "New Task"
    }
  }, (currentTaskId, tasks))

  let filteredTasks = React.useMemo2(() => {
    let q = search->String.toLowerCase->String.trim
    if q == "" {
      tasks
    } else {
      tasks->Array.filter(t =>
        Client__Task__Types.Task.getTitle(t)
        ->Option.getOr("")
        ->String.toLowerCase
        ->String.includes(q)
      )
    }
  }, (tasks, search))

  let handleTaskSwitch = (taskId: string) => {
    Client__State.Actions.switchTask(~taskId)
    setSearch(_ => "")
  }

  let handleDeleteClick = (e: ReactEvent.Mouse.t, taskId: string) => {
    ReactEvent.Mouse.stopPropagation(e)
    ReactEvent.Mouse.preventDefault(e)
    setTaskToDelete(_ => Some(taskId))
    setDeleteDialogOpen(_ => true)
  }

  let handleDeleteConfirm = (_e: ReactEvent.Mouse.t) => {
    switch taskToDelete {
    | Some(taskId) => {
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

  <>
    <div className="flex items-center gap-0.5">
      <DropdownMenu.DropdownMenu>
        <DropdownMenu.DropdownMenuTrigger asChild=true>
          <button
            type_="button"
            className="flex items-center gap-1.5 px-2 h-6 rounded-md text-xs font-medium text-zinc-200 hover:bg-white/5 cursor-pointer max-w-48"
          >
            <span className="truncate"> {React.string(currentTaskTitle)} </span>
            <Icons.ChevronDownIcon
              style={{"width": "10px", "height": "10px"}} className="text-zinc-500 shrink-0"
            />
          </button>
        </DropdownMenu.DropdownMenuTrigger>
        <DropdownMenu.DropdownMenuContent align="start" sideOffset=4 className="w-72 p-0">
          // Search bar — only shown when there are tasks to search
          {switch Array.length(tasks) > 0 {
          | false => React.null
          | true =>
            <div className="px-3 py-2 border-b border-zinc-700">
              <input
                type_="text"
                placeholder="Search tasks..."
                value={search}
                onChange={e => setSearch(_ => (e->ReactEvent.Form.target)["value"])}
                className="w-full bg-transparent text-xs text-zinc-200 placeholder-zinc-500 outline-none"
                onClick={e => ReactEvent.Mouse.stopPropagation(e)}
              />
            </div>
          }}
          // Task list
          <div className="max-h-72 overflow-y-auto py-1">
            {Array.length(filteredTasks) > 0
              ? filteredTasks
                ->Array.map(task => {
                  let taskId =
                    Client__Task__Types.Task.getId(task)->Option.getOrThrow(
                      ~message="[TaskDropdown] Task has no ID",
                    )
                  let taskTitle = Client__Task__Types.Task.getTitle(task)->Option.getOr("Untitled")
                  let isActive = currentTaskId == Some(taskId)

                  <DropdownMenu.DropdownMenuItem
                    key={taskId}
                    className="flex items-center gap-2 cursor-pointer group/item mx-1 rounded"
                    onSelect={_ => handleTaskSwitch(taskId)}
                  >
                    <Icons.ChatBubbleIcon
                      style={{"width": "12px", "height": "12px"}} className="shrink-0 text-zinc-500"
                    />
                    <span className="flex-1 truncate text-xs"> {React.string(taskTitle)} </span>
                    {isActive
                      ? <span
                          className="text-[10px] text-zinc-400 bg-zinc-800 px-1.5 py-0.5 rounded shrink-0"
                        >
                          {React.string("Current")}
                        </span>
                      : React.null}
                    <span
                      className="p-0.5 rounded-sm opacity-40 hover:opacity-100 hover:bg-zinc-700 transition-opacity duration-150 cursor-pointer shrink-0"
                      onClick={e => handleDeleteClick(e, taskId)}
                    >
                      <Icons.TrashIcon
                        style={{"width": "12px", "height": "12px"}}
                        className="text-zinc-400 hover:text-red-400"
                      />
                    </span>
                  </DropdownMenu.DropdownMenuItem>
                })
                ->React.array
              : <DropdownMenu.DropdownMenuLabel className="text-xs text-zinc-500 py-3 text-center">
                  {React.string(String.trim(search) != "" ? "No matching tasks" : "No tasks yet")}
                </DropdownMenu.DropdownMenuLabel>}
          </div>
        </DropdownMenu.DropdownMenuContent>
      </DropdownMenu.DropdownMenu>

      // "+ New" button
      <Tooltip.Tooltip>
        <Tooltip.TooltipTrigger asChild=true>
          <button
            type_="button"
            onClick={_ => onNewTask()}
            className="flex items-center justify-center w-6 h-6 rounded text-zinc-500 hover:text-zinc-200 hover:bg-white/5 cursor-pointer"
          >
            <Icons.PlusIcon style={{"width": "12px", "height": "12px"}} />
          </button>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent sideOffset=4> {React.string("New task")} </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
    </div>

    // Delete confirmation dialog (outside the dropdown to avoid stacking context issues)
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
  </>
}
