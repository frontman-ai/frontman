# Top Bar UX Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 7 UX problems identified in the top bar: logo junk drawer, misleading "workspace" label, navigation instability at narrow widths, hover-only delete, device mode mode-blindness, and simultaneous nudge badge+bubble.

**Architecture:** All changes are local to the top bar components and `Client__App`. No new state actions, reducers, or effects. The nudge sequencing logic lives in `Client__App` as derived booleans from two existing state variables. `Client__TopBar__LogoMenu` is deleted and its two items are redistributed as icon buttons in the right zone.

**Tech Stack:** ReScript 12, React, Tailwind CSS, Radix UI Icons.

---

## File Map

**Deleted:**
- `libs/client/src/Client__TopBar__LogoMenu.res`
- `libs/client/src/Client__TopBar__LogoMenu.story.res`

**Modified:**
- `libs/client/src/Client__TopBar.res` — remove logo menu, add help+open-in-new-window buttons, min-width left zone, device mode pill, split nudge props
- `libs/client/src/Client__TopBar__WorkspaceDropdown.res` — always-visible trash, "workspace"→"task" copy
- `libs/client/src/Client__App.res` — sequential nudge logic, new prop names
- `libs/client/src/Client__TopBar.story.res` — update prop names, add nudge badge story
- `libs/client/src/Client__TopBar__WorkspaceDropdown.story.res` — rename "workspace" → "task" in story names/copy

---

## Task 1: Delete LogoMenu and make logo non-interactive

The logo currently opens a dropdown with Help and Open-in-new-window. Those items move to the right zone in Task 2. First, gut the logo: remove the click handler and dropdown, leave just the visual.

**Files:**
- Delete: `libs/client/src/Client__TopBar__LogoMenu.res`
- Delete: `libs/client/src/Client__TopBar__LogoMenu.story.res`
- Modify: `libs/client/src/Client__TopBar.res`

- [ ] **Step 1: Delete the LogoMenu source files**

```bash
rm libs/client/src/Client__TopBar__LogoMenu.res
rm libs/client/src/Client__TopBar__LogoMenu.story.res
```

- [ ] **Step 2: Add FrontmanLogo import to TopBar and replace the logo menu render**

In `libs/client/src/Client__TopBar.res`, add `module FrontmanLogo = Client__FrontmanLogo` after the existing module aliases at the top:

```rescript
module Icons = Bindings__RadixUI__Icons
module Button = Bindings__UI__Button
module Tooltip = Bindings__UI__Tooltip
module FrontmanLogo = Client__FrontmanLogo
```

Then in the left zone JSX, replace:

```rescript
<Client__TopBar__LogoMenu previewUrl isAgentRunning />
```

with:

```rescript
<div className="flex items-center justify-center w-7 h-7 shrink-0">
  <FrontmanLogo size=18 className={isAgentRunning ? "frontman-logo-pulse" : ""} />
</div>
```

- [ ] **Step 3: Build to verify no compile errors**

```bash
./bin/pod-exec make rescript-build
```

Expected: build succeeds with no errors. If you see "Client__TopBar__LogoMenu not found", confirm the file was deleted and the import removed.

- [ ] **Step 4: Commit**

```bash
jj describe -m "refactor: remove LogoMenu, make logo non-interactive"
jj new
```

---

## Task 2: Add Help and Open-in-new-window to the right zone

Move the two items that were in the logo menu into the right zone as icon buttons. Help (`?`) goes between device mode and settings. Open-in-new-window (`↗`) goes between reload and the URL bar.

**Files:**
- Modify: `libs/client/src/Client__TopBar.res`

- [ ] **Step 1: Add the Open-in-new-window button after the Reload button**

In `libs/client/src/Client__TopBar.res`, in the RIGHT ZONE section, add this block immediately after the closing `</Tooltip.Tooltip>` of the Reload button:

```rescript
// Open in new window
<Tooltip.Tooltip>
  <Tooltip.TooltipTrigger asChild=true>
    <Button.Button
      variant=#ghost
      size=#sm
      onClick={_ =>
        WebAPI.Window.open_(
          WebAPI.Global.window,
          ~url=previewUrl,
          ~target="_blank",
          ~features="noopener,noreferrer",
        )->ignore}
      className=iconBtnCls
    >
      <Icons.OpenInNewWindowIcon style={iconSize} />
    </Button.Button>
  </Tooltip.TooltipTrigger>
  <Tooltip.TooltipContent sideOffset=4>
    {React.string("Open in new window")}
  </Tooltip.TooltipContent>
</Tooltip.Tooltip>
```

- [ ] **Step 2: Add the Help button between device mode and settings**

In the RIGHT ZONE, add this block immediately before the `// Settings gear with optional provider nudge` comment:

```rescript
// Help
<Tooltip.Tooltip>
  <Tooltip.TooltipTrigger asChild=true>
    <Button.Button
      variant=#ghost
      size=#sm
      onClick={_ =>
        WebAPI.Window.open_(
          WebAPI.Global.window,
          ~url="https://discord.gg/xk8uXJSvhC",
          ~target="_blank",
          ~features="noopener,noreferrer",
        )->ignore}
      className=iconBtnCls
    >
      <Icons.QuestionMarkCircledIcon style={iconSize} />
    </Button.Button>
  </Tooltip.TooltipTrigger>
  <Tooltip.TooltipContent sideOffset=4>
    {React.string("Help")}
  </Tooltip.TooltipContent>
</Tooltip.Tooltip>
```

- [ ] **Step 3: Build to verify**

```bash
./bin/pod-exec make rescript-build
```

Expected: build succeeds. The right zone now has: Reload, Open-in-new-window, URL bar, Device mode, Help, Settings.

- [ ] **Step 4: Commit**

```bash
jj describe -m "feat: add Help and Open-in-new-window buttons to top bar right zone"
jj new
```

---

## Task 3: Left zone min-width + device mode pill treatment

Two small fixes to `Client__TopBar.res`:
1. Left zone width: clamp at 240px minimum so nav controls never get clipped when the user drags the chat panel narrow.
2. Device mode active state: replace "icon turns blue" with a visible pill background so it reads as a mode indicator, not just a tinted button.

**Files:**
- Modify: `libs/client/src/Client__TopBar.res`

- [ ] **Step 1: Clamp left zone width**

In `libs/client/src/Client__TopBar.res`, find the left zone `<div>` with `style={{width: ...}}`:

```rescript
<div
  style={{width: `${Int.toString(chatboxWidth)}px`}}
  className="flex items-center h-full shrink-0 px-1 gap-1 overflow-hidden"
>
```

Replace with:

```rescript
<div
  style={{width: `${Int.toString(chatboxWidth >= 240 ? chatboxWidth : 240)}px`}}
  className="flex items-center h-full shrink-0 px-1 gap-1 overflow-hidden"
>
```

- [ ] **Step 2: Fix device mode active state**

Find the device mode button's `className` expression:

```rescript
className={`cursor-pointer h-7 w-7 p-0 ${deviceModeActive
    ? "text-blue-400"
    : "text-zinc-400"}`}
```

Replace with:

```rescript
className={`cursor-pointer h-7 w-7 p-0 ${deviceModeActive
    ? "bg-blue-500/15 text-blue-400 rounded"
    : "text-zinc-400"}`}
```

- [ ] **Step 3: Build to verify**

```bash
./bin/pod-exec make rescript-build
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
jj describe -m "fix: left zone min-width 240px, device mode pill active state"
jj new
```

---

## Task 4: Always-visible trash icon in WorkspaceDropdown

The trash icon is currently hidden until hover (`opacity-0 group-hover/item:opacity-100`). This is inaccessible on touch devices and hides a key affordance. Change to always-visible at reduced opacity, full on hover.

**Files:**
- Modify: `libs/client/src/Client__TopBar__WorkspaceDropdown.res`

- [ ] **Step 1: Update trash icon wrapper className**

In `libs/client/src/Client__TopBar__WorkspaceDropdown.res`, find:

```rescript
<span
  className="p-0.5 rounded-sm opacity-0 group-hover/item:opacity-100 hover:bg-zinc-700 transition-opacity duration-150 cursor-pointer shrink-0"
  onClick={e => handleDeleteClick(e, taskId)}
>
```

Replace with:

```rescript
<span
  className="p-0.5 rounded-sm opacity-40 hover:opacity-100 hover:bg-zinc-700 transition-opacity duration-150 cursor-pointer shrink-0"
  onClick={e => handleDeleteClick(e, taskId)}
>
```

- [ ] **Step 2: Build to verify**

```bash
./bin/pod-exec make rescript-build
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
jj describe -m "fix: trash icon always visible in task dropdown (was hover-only)"
jj new
```

---

## Task 5: Update "workspace" copy to "task"

The internal code uses "task" everywhere. The UI says "workspace." Align them.

**Files:**
- Modify: `libs/client/src/Client__TopBar__WorkspaceDropdown.res`

- [ ] **Step 1: Update placeholder and empty state strings**

In `libs/client/src/Client__TopBar__WorkspaceDropdown.res`:

Replace:
```rescript
placeholder="Search workspaces..."
```
With:
```rescript
placeholder="Search tasks..."
```

Replace:
```rescript
{React.string(
  String.trim(search) != "" ? "No matching workspaces" : "No workspaces yet",
)}
```
With:
```rescript
{React.string(
  String.trim(search) != "" ? "No matching tasks" : "No tasks yet",
)}
```

Replace the `+` New button tooltip text:
```rescript
{React.string("New workspace")}
```
With:
```rescript
{React.string("New task")}
```

- [ ] **Step 2: Build to verify**

```bash
./bin/pod-exec make rescript-build
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
jj describe -m "fix: rename 'workspace' to 'task' in top bar copy"
jj new
```

---

## Task 6: Sequential nudge logic (badge XOR bubble, never both)

Currently `showProviderNudge=true` renders both the badge dot and the `ProviderNudgeBubble`. Split into two props so they're mutually exclusive. Logic: bubble shows first; once dismissed without acting, badge persists. CTA click clears both.

**Files:**
- Modify: `libs/client/src/Client__TopBar.res`
- Modify: `libs/client/src/Client__App.res`

- [ ] **Step 1: Split nudge props in Client__TopBar**

In `libs/client/src/Client__TopBar.res`, update the `make` function signature. Replace:

```rescript
~showProviderNudge: bool=false,
~onProviderNudgeDismiss: unit => unit=() => (),
~onProviderNudgeCta: unit => unit=() => (),
```

With:

```rescript
~showProviderNudgeBubble: bool=false,
~showProviderNudgeBadge: bool=false,
~onProviderNudgeDismiss: unit => unit=() => (),
~onProviderNudgeCta: unit => unit=() => (),
```

- [ ] **Step 2: Update badge render to use showProviderNudgeBadge**

In the settings gear JSX, find the badge span inside the button:

```rescript
{switch showProviderNudge {
| true =>
  <span
    className="absolute -top-0.5 -right-0.5 size-2 rounded-full bg-violet-500 ring-2 ring-zinc-900"
  />
| false => React.null
}}
```

Replace with:

```rescript
{switch showProviderNudgeBadge {
| true =>
  <span
    className="absolute -top-0.5 -right-0.5 size-2 rounded-full bg-violet-500 ring-2 ring-zinc-900"
  />
| false => React.null
}}
```

- [ ] **Step 3: Update bubble render to use showProviderNudgeBubble**

Find:

```rescript
{switch showProviderNudge {
| true =>
  <Client__ProviderNudgeBubble
    onOpenSettings=onProviderNudgeCta onDismiss=onProviderNudgeDismiss
  />
| false => React.null
}}
```

Replace with:

```rescript
{switch showProviderNudgeBubble {
| true =>
  <Client__ProviderNudgeBubble
    onOpenSettings=onProviderNudgeCta onDismiss=onProviderNudgeDismiss
  />
| false => React.null
}}
```

- [ ] **Step 4: Add nudgeBubbleDismissed state in Client__App and derive split booleans**

In `libs/client/src/Client__App.res`, add a new state variable after the existing `providerNudgeDismissed` line:

```rescript
let (providerNudgeDismissed, setProviderNudgeDismissed) = React.useState(() => false)
let (nudgeBubbleDismissed, setNudgeBubbleDismissed) = React.useState(() => false)
```

Replace the current `showProviderNudge` derivation:

```rescript
let showProviderNudge = switch (
  ftueState,
  hasProviderConfigured,
  providerNudgeDismissed,
  usageInfo,
) {
| (Client__FtueState.Completed, false, false, Some(_)) => true
| _ => false
}
```

With:

```rescript
let showNudge = switch (ftueState, hasProviderConfigured, providerNudgeDismissed, usageInfo) {
| (Client__FtueState.Completed, false, false, Some(_)) => true
| _ => false
}
let showProviderNudgeBubble = showNudge && !nudgeBubbleDismissed
let showProviderNudgeBadge = showNudge && nudgeBubbleDismissed
```

- [ ] **Step 5: Update handleProviderNudgeDismiss to only dismiss the bubble**

Replace:

```rescript
let handleProviderNudgeDismiss = () => {
  setProviderNudgeDismissed(_ => true)
}
```

With:

```rescript
let handleProviderNudgeDismiss = () => {
  setNudgeBubbleDismissed(_ => true)
}
```

(`handleProviderNudgeCta` stays unchanged — it sets `providerNudgeDismissed`, which clears `showNudge` entirely.)

- [ ] **Step 6: Update TopBar call in Client__App to use new prop names**

Replace:

```rescript
<Client__TopBar
  chatboxWidth
  onSettingsClick={() => setSettingsOpen(_ => true)}
  showProviderNudge
  onProviderNudgeDismiss=handleProviderNudgeDismiss
  onProviderNudgeCta=handleProviderNudgeCta
/>
```

With:

```rescript
<Client__TopBar
  chatboxWidth
  onSettingsClick={() => setSettingsOpen(_ => true)}
  showProviderNudgeBubble
  showProviderNudgeBadge
  onProviderNudgeDismiss=handleProviderNudgeDismiss
  onProviderNudgeCta=handleProviderNudgeCta
/>
```

- [ ] **Step 7: Build to verify**

```bash
./bin/pod-exec make rescript-build
```

Expected: build succeeds. If you see "Unbound value showProviderNudge", ensure all three occurrences were updated (TopBar props, App derivation, App JSX call).

- [ ] **Step 8: Commit**

```bash
jj describe -m "fix: sequential provider nudge — badge and bubble are mutually exclusive"
jj new
```

---

## Task 7: Update Storybook stories

Update prop names and story copy to match all the above changes.

**Files:**
- Modify: `libs/client/src/Client__TopBar.story.res`
- Modify: `libs/client/src/Client__TopBar__WorkspaceDropdown.story.res`

- [ ] **Step 1: Update TopBar stories — fix prop names**

In `libs/client/src/Client__TopBar.story.res`, every story renders `Client__TopBar` with `showProviderNudge`. Replace all three occurrences:

In `defaultBar` and `narrowChatPanel`, replace:
```rescript
showProviderNudge=false
```
With:
```rescript
showProviderNudgeBubble=false
showProviderNudgeBadge=false
```

In `withNudge`, replace:
```rescript
showProviderNudge=true
```
With:
```rescript
showProviderNudgeBubble=true
showProviderNudgeBadge=false
```

- [ ] **Step 2: Add nudge badge story to TopBar stories**

At the end of `libs/client/src/Client__TopBar.story.res`, add:

```rescript
let withNudgeBadge: Story.t<args> = {
  name: "With Provider Nudge Badge (bubble dismissed)",
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
          showProviderNudgeBubble=false
          showProviderNudgeBadge=true
          onProviderNudgeDismiss={() => ()}
          onProviderNudgeCta={() => ()}
        />
      </div>
    </ContextWrapper>
  },
}
```

- [ ] **Step 3: Update WorkspaceDropdown story names and copy**

In `libs/client/src/Client__TopBar__WorkspaceDropdown.story.res`:

Replace:
```rescript
title: "Components/TopBar/WorkspaceDropdown",
```
With:
```rescript
title: "Components/TopBar/TaskDropdown",
```

Replace story name:
```rescript
name: "No Workspaces",
```
With:
```rescript
name: "No Tasks",
```

Replace story name:
```rescript
name: "Single Workspace (active)",
```
With:
```rescript
name: "Single Task (active)",
```

Replace story name:
```rescript
name: "Many Workspaces",
```
With:
```rescript
name: "Many Tasks",
```

- [ ] **Step 4: Build to verify**

```bash
./bin/pod-exec make rescript-build
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
jj describe -m "chore: update stories for top bar UX polish (prop names, copy)"
jj new
```

---

## Self-Review Checklist

- [x] Logo non-interactive: Task 1
- [x] Help button in right zone: Task 2
- [x] Open-in-new-window in right zone: Task 2
- [x] Left zone min-width 240px: Task 3
- [x] Device mode pill active state: Task 3
- [x] Trash always visible: Task 4
- [x] "workspace" → "task" copy: Task 5
- [x] Nudge badge + bubble mutually exclusive: Task 6
- [x] Stories updated: Task 7
- [x] `Client__TopBar__LogoMenu` deleted: Task 1
