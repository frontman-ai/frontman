# Unified Top Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two separate panel headers with a single 32px unified top bar spanning the full viewport width, preserving all existing functionality.

**Architecture:** Props-drilling for `chatboxWidth` from `Client__App` → `Client__TopBar`. New components read state directly via `useSelector` — no new actions, reducers, or effects. Old header components (`Client__TaskTabs`, `Client__WebPreview__Nav`, `Client__WebPreview__AnnotationControls`) are deleted.

**Tech Stack:** ReScript 12, React, daisyUI/Tailwind, Radix UI dropdowns, existing state reducers.

---

## File Map

**Created:**
- `libs/client/src/Client__TopBar__LogoMenu.res` — logo dropdown (settings, help, open-in-new-window)
- `libs/client/src/Client__TopBar__WorkspaceDropdown.res` — workspace pill + task list with search
- `libs/client/src/Client__TopBar.res` — 32px bar with left + right zones, URL editing state
- `libs/client/src/Client__TopBar.story.res` — Storybook stories
- `libs/client/src/Client__TopBar__WorkspaceDropdown.story.res` — Storybook stories

**Modified:**
- `libs/client/src/webpreview/Client__WebPreview.res` — remove nav bar, annotation controls, URL state
- `libs/client/src/Client__Chatbox.res` — remove `TaskTabs` render and its four props
- `libs/client/src/Client__App.res` — new `flex-col` layout, wire `Client__TopBar`

**Deleted:**
- `libs/client/src/Client__TaskTabs.res`
- `libs/client/src/Client__TaskTabs.story.res`
- `libs/client/src/webpreview/Client__WebPreview__Nav.res`
- `libs/client/src/webpreview/Client__WebPreview__AnnotationControls.res`

---

## Task 1: Remove `Client__WebPreview__AnnotationControls` and simplify `Client__WebPreview`

**Files:**
- Delete: `libs/client/src/webpreview/Client__WebPreview__AnnotationControls.res`
- Modify: `libs/client/src/webpreview/Client__WebPreview.res`

- [ ] **Step 1: Delete `Client__WebPreview__AnnotationControls.res`**

```bash
rm libs/client/src/webpreview/Client__WebPreview__AnnotationControls.res
```

- [ ] **Step 2: Rewrite `Client__WebPreview.res`**

Remove: `module Nav = Client__WebPreview__Nav`, all nav button modules (`BackButton`, `ForwardButton`, `ReloadButton`, `DeviceModeToggle`, `OpenInNewWindow`), URL editing state (`editableUrl`, `isEditingUrl`), all URL/nav handlers, `Client__WebPreview__AnnotationControls` render, and `Nav.Navigation` block. Replace `<Nav.Container>` with a plain div. Keep the iframe rendering logic and device bar.

Replace the entire file with:

```rescript
/**
 * Client__WebPreview - Web preview panel
 *
 * Renders the iframe viewport. Nav controls have moved to Client__TopBar.
 */

// Hook to measure the available space in the viewport container
let useContainerSize = (ref: React.ref<Nullable.t<Dom.element>>): (int, int) => {
  let (size, setSize) = React.useState(() => (0, 0))

  React.useEffect(() => {
    switch ref.current->Nullable.toOption {
    | None => None
    | Some(element) =>
      let rect = WebAPI.Element.getBoundingClientRect(element->Obj.magic)
      setSize(_ => (rect.width->Float.toInt, rect.height->Float.toInt))

      let observer = FrontmanBindings.ResizeObserver.make(entries => {
        entries
        ->Array.get(0)
        ->Option.forEach(
          entry => {
            let cr = entry.contentRect
            setSize(_ => (cr.width->Float.toInt, cr.height->Float.toInt))
          },
        )
      })
      observer->FrontmanBindings.ResizeObserver.observe(element)
      Some(() => observer->FrontmanBindings.ResizeObserver.disconnect)
    }
  }, [])

  size
}

@react.component
let make = () => {
  let currentTaskClientId = Client__State.useSelector(Client__State.Selectors.currentTaskClientId)
  let isNewTask = Client__State.useSelector(Client__State.Selectors.isNewTask)
  let persistedTasks = Client__State.useSelector(Client__State.Selectors.tasks)
  let previewFrame = Client__State.useSelector(Client__State.Selectors.previewFrame)
  let deviceMode = Client__State.useSelector(Client__State.Selectors.deviceMode)
  let deviceOrientation = Client__State.useSelector(Client__State.Selectors.deviceOrientation)

  let containerRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)
  let (availableWidth, availableHeight) = useContainerSize(containerRef)

  React.useEffect(() => {
    Client__DeviceMode.persist(deviceMode, deviceOrientation)
    None
  }, (deviceMode, deviceOrientation))

  let effectiveDims = Client__DeviceMode.getEffectiveDimensions(deviceMode, deviceOrientation)

  let viewportStyle = switch effectiveDims {
  | None => None
  | Some((deviceWidth, deviceHeight)) =>
    let scale = if availableWidth > 16 && availableHeight > 16 {
      Client__DeviceMode.computeScaleFactor(
        ~deviceWidth,
        ~deviceHeight,
        ~availableWidth=availableWidth - 16,
        ~availableHeight=availableHeight - 16,
      )
    } else {
      1.0
    }
    Some((deviceWidth, deviceHeight, scale))
  }

  <div className="flex flex-col h-full bg-white">
    <Client__WebPreview__DeviceBar deviceMode orientation=deviceOrientation />

    <div
      ref={ReactDOM.Ref.callbackDomRef(el => {
        containerRef.current = el
        None
      })}
      className={switch effectiveDims {
      | None => "relative size-full overflow-y-hidden"
      | Some(
          _,
        ) => "relative size-full overflow-hidden flex items-start justify-center bg-[repeating-conic-gradient(#f3f4f6_0%_25%,#ffffff_0%_50%)] bg-[length:16px_16px]"
      }}
    >
      {switch previewFrame.contentDocument {
      | Some(document) =>
        <Client__WebPreview__Stage document={document} viewportStyle=?viewportStyle />
      | _ => React.null
      }}

      {
        let defaultUrl = Client__BrowserUrl.getInitialUrl()

        let allTasks = if isNewTask {
          Array.concat(
            [(currentTaskClientId, previewFrame.url)],
            persistedTasks->Array.map(task => {
              let clientId = Client__Task__Types.Task.getClientId(task)
              let taskPreviewFrame = Client__Task__Types.Task.getPreviewFrame(task, ~defaultUrl)
              (clientId, taskPreviewFrame.url)
            }),
          )
        } else {
          persistedTasks->Array.map(task => {
            let clientId = Client__Task__Types.Task.getClientId(task)
            let taskPreviewFrame = Client__Task__Types.Task.getPreviewFrame(task, ~defaultUrl)
            (clientId, taskPreviewFrame.url)
          })
        }

        allTasks
        ->Array.map(((clientId, url)) => {
          <Client__WebPreview__Body
            key={clientId}
            taskId={clientId}
            url={url}
            isActive={clientId == currentTaskClientId}
            viewportStyle=?viewportStyle
          />
        })
        ->React.array
      }
    </div>
  </div>
}
```

- [ ] **Step 3: Build to verify**

```bash
./bin/pod-exec yarn rescript build
```

Expected: clean build. If you see errors about `Client__WebPreview__AnnotationControls` or `Nav`, check that all references were removed from `Client__WebPreview.res`.

- [ ] **Step 4: Commit**

```bash
git add libs/client/src/webpreview/Client__WebPreview.res
git add libs/client/src/webpreview/Client__WebPreview__AnnotationControls.res
git commit -m "refactor: remove AnnotationControls and nav bar from WebPreview"
```

---

## Task 2: Create `Client__TopBar__LogoMenu`

**Files:**
- Create: `libs/client/src/Client__TopBar__LogoMenu.res`

The logo button opens a dropdown with: Settings, Help (Discord), Open in new window. Receives `isAgentRunning` as a prop so the parent controls the pulse animation.

- [ ] **Step 1: Create `libs/client/src/Client__TopBar__LogoMenu.res`**

```rescript
module Icons = Bindings__RadixUI__Icons
module DropdownMenu = Bindings__UI__DropdownMenu
module FrontmanLogo = Client__FrontmanLogo

@react.component
let make = (
  ~onSettingsClick: unit => unit,
  ~previewUrl: string,
  ~isAgentRunning: bool,
) => {
  let iconSize = {"width": "14px", "height": "14px"}

  <DropdownMenu.DropdownMenu>
    <DropdownMenu.DropdownMenuTrigger asChild=true>
      <button
        type_="button"
        className="flex items-center justify-center w-7 h-7 rounded cursor-pointer hover:bg-white/5"
      >
        <FrontmanLogo size=18 className={isAgentRunning ? "frontman-logo-pulse" : ""} />
      </button>
    </DropdownMenu.DropdownMenuTrigger>
    <DropdownMenu.DropdownMenuContent align="start" sideOffset=4 className="w-48">
      <DropdownMenu.DropdownMenuItem
        onSelect={_ => onSettingsClick()}
        className="flex items-center gap-2 cursor-pointer"
      >
        <Icons.GearIcon style={iconSize} />
        {React.string("Settings")}
      </DropdownMenu.DropdownMenuItem>
      <DropdownMenu.DropdownMenuItem
        onSelect={_ =>
          WebAPI.Window.open_(
            WebAPI.Global.window,
            ~url="https://discord.gg/xk8uXJSvhC",
            ~target="_blank",
            ~features="noopener,noreferrer",
          )->ignore}
        className="flex items-center gap-2 cursor-pointer"
      >
        <Icons.QuestionMarkCircledIcon style={iconSize} />
        {React.string("Help")}
      </DropdownMenu.DropdownMenuItem>
      <DropdownMenu.DropdownMenuSeparator />
      <DropdownMenu.DropdownMenuItem
        onSelect={_ =>
          WebAPI.Window.open_(
            WebAPI.Global.window,
            ~url=previewUrl,
            ~target="_blank",
            ~features="noopener,noreferrer",
          )->ignore}
        className="flex items-center gap-2 cursor-pointer"
      >
        <Icons.OpenInNewWindowIcon style={iconSize} />
        {React.string("Open in new window")}
      </DropdownMenu.DropdownMenuItem>
    </DropdownMenu.DropdownMenuContent>
  </DropdownMenu.DropdownMenu>
}
```

- [ ] **Step 2: Build to verify**

```bash
./bin/pod-exec yarn rescript build
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add libs/client/src/Client__TopBar__LogoMenu.res
git commit -m "feat: add Client__TopBar__LogoMenu component"
```

---

## Task 3: Create `Client__TopBar__WorkspaceDropdown`

**Files:**
- Create: `libs/client/src/Client__TopBar__WorkspaceDropdown.res`

Workspace pill trigger + dropdown with search + task list. Includes the "+ New" button and delete confirmation dialog. Reads `tasks`, `currentTaskId` from state. Calls `clearSession()` before delete/clear (same pattern as `Client__TaskTabs`).

- [ ] **Step 1: Create `libs/client/src/Client__TopBar__WorkspaceDropdown.res`**

```rescript
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
          // Search bar
          <div className="px-3 py-2 border-b border-zinc-700">
            <input
              type_="text"
              placeholder="Search workspaces..."
              value={search}
              onChange={e => setSearch(_ => (e->ReactEvent.Form.target)["value"])}
              className="w-full bg-transparent text-xs text-zinc-200 placeholder-zinc-500 outline-none"
              onClick={e => ReactEvent.Mouse.stopPropagation(e)}
            />
          </div>
          // Task list
          <div className="max-h-72 overflow-y-auto py-1">
            {Array.length(filteredTasks) > 0
              ? filteredTasks
                ->Array.map(task => {
                  let taskId =
                    Client__Task__Types.Task.getId(task)->Option.getOrThrow(
                      ~message="[WorkspaceDropdown] Task has no ID",
                    )
                  let taskTitle =
                    Client__Task__Types.Task.getTitle(task)->Option.getOr("Untitled")
                  let isActive = currentTaskId == Some(taskId)

                  <DropdownMenu.DropdownMenuItem
                    key={taskId}
                    className="flex items-center gap-2 cursor-pointer group/item mx-1 rounded"
                    onSelect={_ => handleTaskSwitch(taskId)}
                  >
                    <Icons.ChatBubbleIcon
                      style={{"width": "12px", "height": "12px"}}
                      className="shrink-0 text-zinc-500"
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
              : <DropdownMenu.DropdownMenuLabel className="text-xs text-zinc-500 py-3 text-center">
                  {React.string(
                    String.trim(search) != "" ? "No matching workspaces" : "No workspaces yet",
                  )}
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
        <Tooltip.TooltipContent sideOffset=4> {React.string("New workspace")} </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
    </div>

    // Delete confirmation dialog (rendered outside the dropdown to avoid stacking context issues)
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
```

- [ ] **Step 2: Build to verify**

```bash
./bin/pod-exec yarn rescript build
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add libs/client/src/Client__TopBar__WorkspaceDropdown.res
git commit -m "feat: add Client__TopBar__WorkspaceDropdown component"
```

---

## Task 4: Create `Client__TopBar`

**Files:**
- Create: `libs/client/src/Client__TopBar.res`

32px bar with left zone (logo menu + workspace dropdown) and right zone (reload + URL bar + device mode + settings gear + provider nudge). Owns URL editing state that was previously in `Client__WebPreview`. Left zone width matches `chatboxWidth` prop. A 1px vertical divider sits between zones.

- [ ] **Step 1: Create `libs/client/src/Client__TopBar.res`**

```rescript
module Icons = Bindings__RadixUI__Icons
module Button = Bindings__UI__Button
module Tooltip = Bindings__UI__Tooltip

@send external locationAssign: ('a, string) => unit = "assign"
@send external blur: Dom.element => unit = "blur"

@react.component
let make = (
  ~chatboxWidth: int,
  ~onSettingsClick: unit => unit,
  ~showProviderNudge: bool=false,
  ~onProviderNudgeDismiss: unit => unit=() => (),
  ~onProviderNudgeCta: unit => unit=() => (),
) => {
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)
  let isNewTask = Client__State.useSelector(Client__State.Selectors.isNewTask)
  let previewUrl = Client__State.useSelector(Client__State.Selectors.previewUrl)
  let previewFrame = Client__State.useSelector(Client__State.Selectors.previewFrame)
  let deviceMode = Client__State.useSelector(Client__State.Selectors.deviceMode)

  let {clearSession} = Client__FrontmanProvider.useFrontman()

  // URL editing local state (moved here from Client__WebPreview)
  let (editableUrl, setEditableUrl) = React.useState(() => previewUrl)
  let (isEditingUrl, setIsEditingUrl) = React.useState(() => false)

  let displayedUrl = switch isEditingUrl {
  | true => editableUrl
  | false => previewUrl
  }

  let handleUrlChange = (e: ReactEvent.Form.t) => {
    let value = (e->ReactEvent.Form.target)["value"]
    setEditableUrl(_ => value)
  }

  let handleUrlKeyDown = (e: ReactEvent.Keyboard.t) => {
    switch ReactEvent.Keyboard.key(e) {
    | "Enter" =>
      switch Client__BrowserUrl.resolveUrlWithBase(~url=editableUrl, ~base=previewUrl) {
      | None => ()
      | Some(resolvedUrl) =>
        switch Client__BrowserUrl.isSameOriginWithBase(
          ~baseUrl=previewUrl,
          ~targetUrl=resolvedUrl,
        ) {
        | false => ()
        | true =>
          previewFrame.contentWindow->Option.forEach(contentWindow => {
            contentWindow.location->locationAssign(resolvedUrl)
          })
          Client__State.Actions.setPreviewUrl(~url=resolvedUrl)
          Client__State.Actions.clearAnnotations()
          Client__BrowserUrl.syncBrowserUrl(~previewUrl=resolvedUrl)
        }
      }
      let target: Dom.element = ReactEvent.Keyboard.target(e)->Obj.magic
      target->blur
    | "Escape" =>
      let target: Dom.element = ReactEvent.Keyboard.target(e)->Obj.magic
      target->blur
    | _ => ()
    }
  }

  let handleUrlFocus = (_e: ReactEvent.Focus.t) => {
    setIsEditingUrl(_ => true)
    setEditableUrl(_ => previewUrl)
  }

  let handleUrlBlur = (_e: ReactEvent.Focus.t) => {
    setIsEditingUrl(_ => false)
  }

  let handleReload = () => {
    previewFrame.contentWindow->Option.forEach(contentWindow => {
      WebAPI.Location.reload(contentWindow.location)
    })
    Client__State.Actions.clearAnnotations()
  }

  let handleNewTask = () => {
    if !isNewTask {
      clearSession()
      Client__State.Actions.clearCurrentTask()
    }
  }

  let deviceModeActive = Client__DeviceMode.isActive(deviceMode)
  let iconSize = {"width": "14px", "height": "14px"}
  let iconBtnCls = "cursor-pointer h-7 w-7 p-0 text-zinc-400"

  <div className="h-8 flex items-center shrink-0 bg-[#130d20] border-b border-[#1e1538]">
    // LEFT ZONE — width tracks the resizable chat panel
    <div
      style={{width: `${Int.toString(chatboxWidth)}px`}}
      className="flex items-center h-full shrink-0 px-1 gap-1 overflow-hidden"
    >
      <Client__TopBar__LogoMenu onSettingsClick previewUrl isAgentRunning />
      <Client__TopBar__WorkspaceDropdown onNewTask={handleNewTask} />
    </div>
    // Vertical divider — visually continues the panel border below
    <div className="w-px h-full bg-[#1e1538] shrink-0" />
    // RIGHT ZONE — takes remaining space
    <div className="flex items-center h-full flex-1 min-w-0 px-1 gap-1">
      // Reload
      <Tooltip.Tooltip>
        <Tooltip.TooltipTrigger asChild=true>
          <Button.Button
            variant=#ghost size=#sm onClick={_ => handleReload()} className=iconBtnCls
          >
            <Icons.ReloadIcon style={iconSize} />
          </Button.Button>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent sideOffset=4> {React.string("Reload")} </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
      // URL bar
      <input
        type_="text"
        value={displayedUrl}
        onChange={handleUrlChange}
        onKeyDown={handleUrlKeyDown}
        onFocus={handleUrlFocus}
        onBlur={handleUrlBlur}
        className="flex-1 min-w-0 h-6 px-2 text-xs bg-white/5 border border-white/10 rounded text-zinc-300 placeholder-zinc-600 focus:outline-none focus:ring-1 focus:ring-violet-500/50 focus:border-violet-500/50"
      />
      // Device mode toggle
      <Tooltip.Tooltip>
        <Tooltip.TooltipTrigger asChild=true>
          <Button.Button
            variant=#ghost
            size=#sm
            onClick={_ => Client__State.Actions.toggleDeviceMode()}
            className={`cursor-pointer h-7 w-7 p-0 ${deviceModeActive
                ? "text-blue-400"
                : "text-zinc-400"}`}
          >
            <Icons.MobileIcon style={iconSize} />
          </Button.Button>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent sideOffset=4>
          {React.string(deviceModeActive ? "Exit device mode" : "Toggle device mode")}
        </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
      // Settings gear with optional provider nudge
      <div className="relative">
        <Tooltip.Tooltip>
          <Tooltip.TooltipTrigger asChild=true>
            <Button.Button
              variant=#ghost size=#sm onClick={_ => onSettingsClick()} className=iconBtnCls
            >
              <Icons.GearIcon style={iconSize} />
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
        {switch showProviderNudge {
        | true =>
          <Client__ProviderNudgeBubble
            onOpenSettings=onProviderNudgeCta onDismiss=onProviderNudgeDismiss
          />
        | false => React.null
        }}
      </div>
    </div>
  </div>
}
```

- [ ] **Step 2: Build to verify**

```bash
./bin/pod-exec yarn rescript build
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add libs/client/src/Client__TopBar.res
git commit -m "feat: add Client__TopBar component with left and right zones"
```

---

## Task 5: Wire up `Client__App`, simplify `Client__Chatbox`, delete old files

**Files:**
- Modify: `libs/client/src/Client__App.res`
- Modify: `libs/client/src/Client__Chatbox.res`
- Delete: `libs/client/src/Client__TaskTabs.res`
- Delete: `libs/client/src/Client__TaskTabs.story.res`
- Delete: `libs/client/src/webpreview/Client__WebPreview__Nav.res`

These changes are coupled — do them all before building.

- [ ] **Step 1: Delete the old header files**

```bash
rm libs/client/src/Client__TaskTabs.res
rm libs/client/src/Client__TaskTabs.story.res
rm libs/client/src/webpreview/Client__WebPreview__Nav.res
```

- [ ] **Step 2: Rewrite `libs/client/src/Client__Chatbox.res`**

Remove: `module TaskTabs = Client__TaskTabs`, the four props (`~onSettingsClick`, `~showProviderNudge`, `~onProviderNudgeDismiss`, `~onProviderNudgeCta`), and the `<TaskTabs ...>` render on line 405.

Change the component signature from:
```rescript
@react.component
let make = (
  ~onSettingsClick: unit => unit,
  ~showProviderNudge: bool=false,
  ~onProviderNudgeDismiss: unit => unit=() => (),
  ~onProviderNudgeCta: unit => unit=() => (),
) => {
```

to:
```rescript
@react.component
let make = () => {
```

Remove the `module TaskTabs = Client__TaskTabs` alias near the top (line 15) and the `<TaskTabs onSettingsClick showProviderNudge onProviderNudgeDismiss onProviderNudgeCta />` render (line 405).

The opening of the returned JSX changes from:
```rescript
  <div className="relative flex flex-col h-full bg-[#180C2D] text-zinc-200">
    <TaskTabs onSettingsClick showProviderNudge onProviderNudgeDismiss onProviderNudgeCta />
    <Client__UpdateBanner />
```

to:
```rescript
  <div className="relative flex flex-col h-full bg-[#180C2D] text-zinc-200">
    <Client__UpdateBanner />
```

- [ ] **Step 3: Rewrite `libs/client/src/Client__App.res`**

Change the outer layout from `flex` (row) to `flex flex-col`, add `Client__TopBar` above the panel row, remove the four TaskTabs props from `<Client__Chatbox>`, and move the resize overlay inside the inner row div.

Replace the entire file with:

```rescript
module SettingsModal = Client__SettingsModal

@react.component
let make = (~apiBaseUrl: string) => {
  let {
    connectionState,
    sendPrompt,
    cancelPrompt,
    retryTurn,
    loadTask,
    deleteSession,
    authRedirectUrl,
    _,
  } = Client__FrontmanProvider.useFrontman()

  React.useEffect(() => {
    switch connectionState {
    | Connected | SessionActive(_) =>
      Client__Debug.init()
      Client__State.Actions.setAcpSession(
        ~sendPrompt,
        ~cancelPrompt,
        ~retryTurn,
        ~loadTask,
        ~deleteSession,
        ~apiBaseUrl,
      )
    | Disconnected | Error(_) => Client__State.Actions.clearAcpSession()
    | _ => ()
    }
    None
  }, (connectionState, sendPrompt, cancelPrompt, retryTurn, loadTask, deleteSession, apiBaseUrl))

  let (chatboxWidth, isResizing, handleResizeMouseDown) = Client__UseResizableWidth.use()

  let (settingsOpen, setSettingsOpen) = React.useState(() => false)
  let (settingsInitialTab, setSettingsInitialTab) = React.useState(() => None)

  let (ftueState, setFtueState) = React.useState(() => Client__FtueState.get())
  let (showCelebration, setShowCelebration) = React.useState(() => false)
  let (providerNudgeDismissed, setProviderNudgeDismissed) = React.useState(() => false)
  let hasProviderConfigured = Client__State.useSelector(
    Client__State.Selectors.hasAnyProviderConfigured,
  )
  let usageInfo = Client__State.useSelector(Client__State.Selectors.usageInfo)

  React.useEffect2(() => {
    switch (connectionState, ftueState) {
    | (Connected | SessionActive(_), Client__FtueState.WelcomeShown) =>
      setShowCelebration(_ => true)
      Client__FtueState.setCompleted()
      setFtueState(_ => Client__FtueState.Completed)
    | _ => ()
    }
    None
  }, (connectionState, ftueState))

  let openSettingsProviders = () => {
    setSettingsInitialTab(_ => Some("providers"))
    setSettingsOpen(_ => true)
  }

  let handleCelebrationDismiss = () => {
    setShowCelebration(_ => false)
  }

  let handleCelebrationConnectProvider = () => {
    setShowCelebration(_ => false)
    openSettingsProviders()
  }

  let showProviderNudge = switch (
    ftueState,
    hasProviderConfigured,
    providerNudgeDismissed,
    usageInfo,
  ) {
  | (Client__FtueState.Completed, false, false, Some(_)) => true
  | _ => false
  }

  let handleProviderNudgeDismiss = () => {
    setProviderNudgeDismissed(_ => true)
  }

  let handleProviderNudgeCta = () => {
    setProviderNudgeDismissed(_ => true)
    openSettingsProviders()
  }

  let handleSettingsOpenChange = (value: bool) => {
    setSettingsOpen(_ => value)
    switch value {
    | false => setSettingsInitialTab(_ => None)
    | true => ()
    }
  }

  <div className="flex flex-col h-screen w-screen bg-background text-foreground">
    <SettingsModal
      open_={settingsOpen} onOpenChange={handleSettingsOpenChange} initialTab=?{settingsInitialTab}
    />
    // FTUE: Welcome modal
    {switch (authRedirectUrl, ftueState) {
    | (Some(loginUrl), Client__FtueState.New) => <Client__WelcomeModal loginUrl />
    | _ => React.null
    }}
    // FTUE: Post-signup celebration overlay
    {switch showCelebration {
    | true =>
      <Client__PostSignupCelebration
        onDismiss=handleCelebrationDismiss onConnectProvider=handleCelebrationConnectProvider
      />
    | false => React.null
    }}
    // Top bar (sits above the panel split)
    <Client__TopBar
      chatboxWidth
      onSettingsClick={() => setSettingsOpen(_ => true)}
      showProviderNudge
      onProviderNudgeDismiss=handleProviderNudgeDismiss
      onProviderNudgeCta=handleProviderNudgeCta
    />
    // Main content area — flex row of chat + preview panels
    <div className="flex flex-1 min-h-0 w-full">
      // Transparent overlay during resize to prevent iframe from stealing mouse events
      {switch isResizing {
      | true => <div className="fixed inset-0 z-50 cursor-col-resize" />
      | false => React.null
      }}
      <div
        style={{width: `${Int.toString(chatboxWidth)}px`}}
        className="h-full border-r flex flex-col p-2 overflow-hidden relative shrink-0"
      >
        <Client__Chatbox />
        // Resize handle on right edge
        <div
          className={[
            "absolute top-0 right-0 w-1 h-full cursor-col-resize transition-colors",
            switch isResizing {
            | true => "bg-zinc-500"
            | false => "hover:bg-zinc-600"
            },
          ]->Array.join(" ")}
          onMouseDown={handleResizeMouseDown}
        />
      </div>
      <div className="grow h-full p-1 min-w-0">
        <Client__WebPreview />
      </div>
    </div>
  </div>
}
```

- [ ] **Step 4: Build to verify**

```bash
./bin/pod-exec yarn rescript build
```

Expected: clean build with no references to `Client__TaskTabs` or `Client__WebPreview__Nav`. If you see errors, check that:
- `Client__Chatbox.res` no longer imports or renders `TaskTabs`
- `Client__App.res` no longer passes the four removed props to `<Client__Chatbox>`
- No remaining `.res` file imports `Client__WebPreview__Nav`

- [ ] **Step 5: Commit**

```bash
git add libs/client/src/Client__App.res
git add libs/client/src/Client__Chatbox.res
git add libs/client/src/Client__TaskTabs.res
git add libs/client/src/Client__TaskTabs.story.res
git add libs/client/src/webpreview/Client__WebPreview__Nav.res
git commit -m "refactor: wire Client__TopBar into App, remove TaskTabs and WebPreview nav"
```

---

## Task 6: Add Storybook stories

**Files:**
- Create: `libs/client/src/Client__TopBar.story.res`
- Create: `libs/client/src/Client__TopBar__WorkspaceDropdown.story.res`

Stories provide visual regression coverage and serve as a quick smoke test for the new components. Reuse the fixture helpers from the deleted `Client__TaskTabs.story.res` (they're reproduced below).

- [ ] **Step 1: Create `libs/client/src/Client__TopBar__WorkspaceDropdown.story.res`**

```rescript
open Bindings__Storybook

module StateReducer = Client__State__StateReducer
module StateTypes = Client__State__Types
module Store = Client__State__Store

let _forceState = (state: StateTypes.state) => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(Store.store, state)
}

module Fixtures = {
  let makeTask = (~id, ~title, ~createdAt, ~updatedAt=?, ~withMessages=false): StateReducer.Task.t => {
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
      let taskId = StateTypes.Task.getId(task)->Option.getOrThrow(~message="[Fixtures] Task must have ID")
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
  title: "Components/TopBar/WorkspaceDropdown",
  component: Obj.magic(Client__TopBar__WorkspaceDropdown.make),
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

let noWorkspaces: Story.t<args> = {
  name: "No Workspaces",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div className="p-2 bg-[#130d20]">
        <Client__TopBar__WorkspaceDropdown onNewTask={() => ()} />
      </div>
    </ContextWrapper>
  },
}

let singleWorkspace: Story.t<args> = {
  name: "Single Workspace (active)",
  render: _ => {
    let task = Fixtures.makeTask(~id="t1", ~title="Fix login page", ~createdAt=Date.now(), ~withMessages=true)
    React.useEffect0(() => {
      _forceState(Fixtures.stateWithTasks(~tasks=[task], ~currentTaskId="t1"))
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div className="p-2 bg-[#130d20]">
        <Client__TopBar__WorkspaceDropdown onNewTask={() => ()} />
      </div>
    </ContextWrapper>
  },
}

let manyWorkspaces: Story.t<args> = {
  name: "Many Workspaces",
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
        <Client__TopBar__WorkspaceDropdown onNewTask={() => ()} />
      </div>
    </ContextWrapper>
  },
}
```

- [ ] **Step 2: Create `libs/client/src/Client__TopBar.story.res`**

```rescript
open Bindings__Storybook

module StateReducer = Client__State__StateReducer
module StateTypes = Client__State__Types
module Store = Client__State__Store

let _forceState = (state: StateTypes.state) => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(Store.store, state)
}

module Fixtures = {
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
  title: "Components/TopBar",
  component: Obj.magic(Client__TopBar.make),
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

let defaultBar: Story.t<args> = {
  name: "Default (no workspaces)",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div style={{width: "900px"}}>
        <Client__TopBar
          chatboxWidth=400
          onSettingsClick={() => ()}
          showProviderNudge=false
          onProviderNudgeDismiss={() => ()}
          onProviderNudgeCta={() => ()}
        />
      </div>
    </ContextWrapper>
  },
}

let withNudge: Story.t<args> = {
  name: "With Provider Nudge",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div style={{width: "900px"}}>
        <Client__TopBar
          chatboxWidth=400
          onSettingsClick={() => ()}
          showProviderNudge=true
          onProviderNudgeDismiss={() => ()}
          onProviderNudgeCta={() => ()}
        />
      </div>
    </ContextWrapper>
  },
}

let narrowChatPanel: Story.t<args> = {
  name: "Narrow chat panel (280px)",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div style={{width: "900px"}}>
        <Client__TopBar
          chatboxWidth=280
          onSettingsClick={() => ()}
          showProviderNudge=false
          onProviderNudgeDismiss={() => ()}
          onProviderNudgeCta={() => ()}
        />
      </div>
    </ContextWrapper>
  },
}
```

- [ ] **Step 3: Build to verify**

```bash
./bin/pod-exec yarn rescript build
```

Expected: clean build. If you see an error about `forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll` not found, verify the exact name with the step below.

- [ ] **Step 4: Verify the exact helper function name**

```bash
grep -n "forceSet\|resetState" libs/client/src/state/Client__StateSnapshot__Storybook.res
```

If the name differs, update both story files to match.

- [ ] **Step 5: Commit**

```bash
git add libs/client/src/Client__TopBar.story.res
git add libs/client/src/Client__TopBar__WorkspaceDropdown.story.res
git commit -m "feat: add Storybook stories for Client__TopBar and WorkspaceDropdown"
```

---

## Task 7: Final build and smoke test

- [ ] **Step 1: Clean build**

```bash
./bin/pod-exec yarn rescript build
```

Expected: zero errors, zero warnings about unused modules.

- [ ] **Step 2: Verify no stale references to deleted modules**

```bash
grep -r "TaskTabs\|WebPreview__Nav\|AnnotationControls" libs/client/src --include="*.res" -l
```

Expected: no output. If any files are listed, open them and remove the references.

- [ ] **Step 3: Run vitest**

```bash
./bin/pod-exec yarn vitest run
```

Expected: all tests pass.

- [ ] **Step 4: Open Storybook and smoke test visually**

Start Storybook in the worktree dev server and verify:
- `Components/TopBar` stories render the 32px bar correctly
- `Components/TopBar/WorkspaceDropdown` stories render the pill and dropdown
- Clicking the workspace pill opens the task list
- Clicking the logo opens the overflow menu

- [ ] **Step 5: Commit**

```bash
git add -p  # stage any last fixes
git commit -m "chore: final build verification for unified top bar"
```
