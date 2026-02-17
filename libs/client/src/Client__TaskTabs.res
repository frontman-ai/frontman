module Button = Bindings__UI__Button
module Icons = Bindings__RadixUI__Icons
module AlertDialog = Bindings__UI__AlertDialog
module Tooltip = Bindings__UI__Tooltip
module DropdownMenu = Bindings__UI__DropdownMenu
module FrontmanLogo = Client__FrontmanLogo

@react.component
let make = (
  ~onSettingsClick: unit => unit,
  ~showProviderNudge: bool=false,
  ~onProviderNudgeDismiss: unit => unit=() => (),
  ~onProviderNudgeCta: unit => unit=() => (),
) => {
  // Local UI state
  let (deleteDialogOpen, setDeleteDialogOpen) = React.useState(() => false)
  let (taskToDelete, setTaskToDelete) = React.useState(() => None)

  // Get clearSession from FrontmanProvider context
  let {clearSession} = Client__FrontmanProvider.useFrontman()

  // Global state selectors
  let tasks = Client__State.useSelector(Client__State.Selectors.tasks)
  let currentTaskId = Client__State.useSelector(Client__State.Selectors.currentTaskId)
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)
  let isNewTask = Client__State.useSelector(Client__State.Selectors.isNewTask)

  // Current task title
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

  // Event handlers
  let handleTaskSwitch = (taskId: string) => {
    Client__State.Actions.switchTask(~taskId)
  }

  let handleNewTask = (_e: ReactEvent.Mouse.t) => {
    // Don't create a new chat if the current task is already empty (New state)
    if !isNewTask {
      clearSession()
      Client__State.Actions.clearCurrentTask()
    }
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
        // If deleting the current task, tear down the session channel first
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

  let iconSize = {"width": "14px", "height": "14px"}

  // Shared style for every icon button in the header bar.
  // Ghost variant + fixed 28×28 size + muted icon color.
  // Re-use this for any new header action to keep them visually aligned.
  let headerIconBtn = "cursor-pointer h-7 w-7 p-0 text-zinc-400"

  // Main render — compact bar layout
  <div className="h-10 border-b flex items-center">
    // Logo
    <div className="flex items-center justify-center w-9 h-full shrink-0 pl-2">
      <FrontmanLogo size=24 className={isAgentRunning ? "frontman-logo-pulse" : ""} />
    </div>
    // Current task title
    <div className="flex-1 min-w-0 px-2">
      <span className="text-xs font-medium text-zinc-200 truncate block">
        {React.string(currentTaskTitle)}
      </span>
    </div>
    // Action buttons
    <div className="shrink-0 flex items-center gap-0.5 pr-2">
      // New task button
      <Tooltip.Tooltip>
        <Tooltip.TooltipTrigger asChild=true>
          <Button.Button
            variant=#ghost
            size=#sm
            onClick={handleNewTask}
            className=headerIconBtn
          >
            <Icons.PlusIcon style={iconSize} />
          </Button.Button>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent sideOffset=4>
          {React.string("New task")}
        </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
      // History dropdown
      <DropdownMenu.DropdownMenu>
        <Tooltip.Tooltip>
          <Tooltip.TooltipTrigger asChild=true>
            <DropdownMenu.DropdownMenuTrigger asChild=true>
              <Button.Button variant=#ghost size=#sm className=headerIconBtn>
                <Icons.CountdownTimerIcon style={iconSize} />
              </Button.Button>
            </DropdownMenu.DropdownMenuTrigger>
          </Tooltip.TooltipTrigger>
          <Tooltip.TooltipContent sideOffset=4>
            {React.string("Task history")}
          </Tooltip.TooltipContent>
        </Tooltip.Tooltip>
        <DropdownMenu.DropdownMenuContent align="end" sideOffset=4 className="w-72 max-h-80 overflow-y-auto">
          {Array.length(tasks) > 0
            ? tasks
              ->Array.map(task => {
                let taskId =
                  Client__Task__Types.Task.getId(task)->Option.getOrThrow(
                    ~message="[TaskTabs] Task in dict has no ID",
                  )
                let taskTitle =
                  Client__Task__Types.Task.getTitle(task)->Option.getOr("Untitled")
                let isActive = currentTaskId == Some(taskId)

                <DropdownMenu.DropdownMenuItem
                  key={taskId}
                  className="flex items-center gap-2 cursor-pointer group/item"
                  onSelect={_ => handleTaskSwitch(taskId)}
                >
                  <Icons.ChatBubbleIcon
                    style={{"width": "12px", "height": "12px"}}
                    className="shrink-0 text-zinc-500"
                  />
                  <span className="flex-1 truncate text-xs">
                    {React.string(taskTitle)}
                  </span>
                  {isActive
                    ? <span
                        className="text-[10px] text-zinc-400 bg-zinc-800 px-1.5 py-0.5 rounded shrink-0"
                      >
                        {React.string("Current")}
                      </span>
                    : React.null}
                  <span
                    className="p-0.5 rounded-sm opacity-0 group-hover/item:opacity-100 hover:bg-zinc-700 transition-opacity duration-150 cursor-pointer shrink-0"
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
            : <DropdownMenu.DropdownMenuLabel className="text-xs text-zinc-500">
                {React.string("No tasks yet")}
              </DropdownMenu.DropdownMenuLabel>}
        </DropdownMenu.DropdownMenuContent>
      </DropdownMenu.DropdownMenu>
      // Help button (Discord link)
      <Tooltip.Tooltip>
        <Tooltip.TooltipTrigger asChild=true>
          <Button.Button
            variant=#ghost
            size=#sm
            asChild=true
            className={headerIconBtn ++ " hover:text-[#5865F2] hover:bg-[#5865F2]/10"}
          >
            <a
              href="https://discord.gg/J77jBzMM"
              target="_blank"
              rel="noopener noreferrer"
            >
              <Icons.QuestionMarkCircledIcon style={iconSize} />
            </a>
          </Button.Button>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent side="bottom" align="end" sideOffset=4>
          {React.string("Need help? Join our Discord")}
        </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
      // Settings button with optional provider nudge bubble
      <div className="relative">
        <Tooltip.Tooltip>
          <Tooltip.TooltipTrigger asChild=true>
            <Button.Button
              variant=#ghost
              size=#sm
              onClick={_ => onSettingsClick()}
              className=headerIconBtn
            >
              <Icons.GearIcon style={iconSize} />
              // Notification dot when nudge is active
              {switch showProviderNudge {
              | true =>
                <span
                  className="absolute -top-0.5 -right-0.5 size-2 rounded-full bg-violet-500 ring-2 ring-zinc-900"
                />
              | false => React.null
              }}
            </Button.Button>
          </Tooltip.TooltipTrigger>
          <Tooltip.TooltipContent sideOffset=4>
            {React.string("Settings")}
          </Tooltip.TooltipContent>
        </Tooltip.Tooltip>
        // Provider nudge bubble
        {switch showProviderNudge {
        | true =>
          <Client__ProviderNudgeBubble
            onOpenSettings=onProviderNudgeCta onDismiss=onProviderNudgeDismiss
          />
        | false => React.null
        }}
      </div>
    </div>
    // Delete confirmation dialog
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
