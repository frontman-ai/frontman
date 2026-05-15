module Icons = Client__UI__Icons
module AlertDialog = Client__UI__AlertDialog
module Badge = Client__UI__Badge
module DropdownMenu = Client__UI__DropdownMenu
module Tooltip = Client__UI__Tooltip

@react.component
let make = (~onNewTask: unit => unit) => {
  let (menuOpen, setMenuOpen) = React.useState(() => false)
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
    setMenuOpen(_ => false)
  }

  let handleDeleteClick = (e: ReactEvent.Mouse.t, taskId: string) => {
    ReactEvent.Mouse.stopPropagation(e)
    ReactEvent.Mouse.preventDefault(e)
    setTaskToDelete(_ => Some(taskId))
    setDeleteDialogOpen(_ => true)
    setMenuOpen(_ => false)
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
      <DropdownMenu open_={menuOpen} onOpenChange={(open_, _) => setMenuOpen(_ => open_)}>
        <DropdownMenu.Trigger
          render={<button
            type_="button"
            className="flex items-center gap-1.5 px-2 h-6 rounded-md text-xs font-medium text-zinc-200 hover:bg-white/5 cursor-pointer max-w-48"
          />}
        >
          <span className="truncate"> {React.string(currentTaskTitle)} </span>
          <Icons.ChevronDownIcon
            style={{width: "10px", height: "10px"}} className="text-zinc-500 shrink-0"
          />
        </DropdownMenu.Trigger>
        <DropdownMenu.Content align=BaseUi.Types.Align.Start sideOffset=4. className="w-72 p-0">
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

                  <DropdownMenu.Item
                    key={taskId}
                    className="flex items-center gap-2 cursor-pointer group/item mx-1 rounded"
                    onClick={_ => handleTaskSwitch(taskId)}
                  >
                    <Icons.ChatBubbleIcon
                      style={{width: "12px", height: "12px"}} className="shrink-0 text-zinc-500"
                    />
                    <span className="flex-1 truncate text-xs"> {React.string(taskTitle)} </span>
                    {isActive
                      ? <Badge variant=Badge.Variant.Zinc> {React.string("Current")} </Badge>
                      : React.null}
                    <span
                      className="p-0.5 rounded-sm opacity-40 hover:opacity-100 hover:bg-zinc-700 transition-opacity duration-150 cursor-pointer shrink-0"
                      onClick={e => handleDeleteClick(e, taskId)}
                    >
                      <Icons.TrashIcon
                        style={{width: "12px", height: "12px"}}
                        className="text-zinc-400 hover:text-red-400"
                      />
                    </span>
                  </DropdownMenu.Item>
                })
                ->React.array
              : <DropdownMenu.Label className="text-xs text-zinc-500 py-3 text-center">
                  {React.string(String.trim(search) != "" ? "No matching tasks" : "No tasks yet")}
                </DropdownMenu.Label>}
          </div>
        </DropdownMenu.Content>
      </DropdownMenu>

      // "+ New" button
      <Tooltip>
        <Tooltip.Trigger
          render={<button
            type_="button"
            onClick={_ => onNewTask()}
            className="flex items-center justify-center w-6 h-6 rounded text-zinc-500 hover:text-zinc-200 hover:bg-white/5 cursor-pointer"
          />}
        >
          <Icons.PlusIcon style={{width: "12px", height: "12px"}} />
        </Tooltip.Trigger>
        <Tooltip.Content sideOffset=4.> {React.string("New task")} </Tooltip.Content>
      </Tooltip>
    </div>

    // Delete confirmation dialog (outside the dropdown to avoid stacking context issues)
    <AlertDialog
      open_={deleteDialogOpen} onOpenChange={(open_, _) => setDeleteDialogOpen(_ => open_)}
    >
      <AlertDialog.Content>
        <AlertDialog.Header>
          <AlertDialog.Title> {React.string("Delete task?")} </AlertDialog.Title>
          <AlertDialog.Description>
            {React.string(
              "This will permanently delete this conversation. This action cannot be undone.",
            )}
          </AlertDialog.Description>
        </AlertDialog.Header>
        <AlertDialog.Footer>
          <AlertDialog.Cancel onClick={handleDeleteCancel}>
            {React.string("Cancel")}
          </AlertDialog.Cancel>
          <AlertDialog.Action onClick={handleDeleteConfirm} variant=AlertDialog.Variant.Destructive>
            {React.string("Delete")}
          </AlertDialog.Action>
        </AlertDialog.Footer>
      </AlertDialog.Content>
    </AlertDialog>
  </>
}
