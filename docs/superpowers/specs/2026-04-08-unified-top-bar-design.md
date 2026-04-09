# Unified Top Bar — Design Spec

**Issue:** #802  
**Date:** 2026-04-08 (UX revision: 2026-04-09)  
**Type:** Layout refactor (no new state, no new API)

---

## Summary

Replace the two separate panel headers (chat's `Client__TaskTabs` and preview's `Client__WebPreview__Nav`) with a single 32px top bar spanning the full viewport width. Same functionality, improved UX. Prepares the UI for future workspace/git integration features.

---

## Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│ [F] [▼ Task name] [+]          │  [⟳] [↗] [  URL bar  ]  [📱]  [?] [⚙] │
│    LEFT ZONE (min 240px)       │      RIGHT ZONE (flex-1)             │
└──────────────────────────────────────────────────────────────────────┘
```

`Client__App` layout changes from:

```
flex row: [Chat panel | Preview panel]
```

to:

```
flex col:
  [Client__TopBar (32px, full width)]
  [flex row: [Chat panel | Preview panel]]
```

The top bar left zone width tracks `chatboxWidth` with a minimum of `240px` (`max(chatboxWidth, 240)`). This keeps the visual divider aligned with the panel border below at typical widths, while preventing navigation controls from being clipped when the chat panel is dragged narrow. The right zone takes remaining space. A vertical divider between zones visually continues the panel border below.

---

## New Components

### `Client__TopBar`

32px strip, full width, flex row. Renders left zone and right zone side by side.

**Props:**
- `chatboxWidth: int` — from `Client__App` via `Client__UseResizableWidth`
- `onSettingsClick: unit => unit`
- `showProviderNudge: bool`
- `onProviderNudgeDismiss: unit => unit`
- `onProviderNudgeCta: unit => unit`

**State reads:** `Selectors.isAgentRunning` (for logo pulse animation)

**Left zone:**
| Element | Behavior |
|---------|----------|
| Logo (18×18px) | Frontman "F", pulse when agent running, **not interactive** (no click, no menu) |
| Task dropdown pill | Current task title + chevron, click opens `Client__TopBar__WorkspaceDropdown` |
| `+` New ghost button | Creates new task (tooltip: "New task") |

**Right zone (preview controls):**
| Element | Behavior |
|---------|----------|
| Reload (22×22px) | Reloads preview iframe |
| Open in new window (22×22px) | Opens `previewUrl` in new tab (↗ icon, tooltip: "Open in new window") |
| URL bar | Dark-themed, editable, shows current preview URL |
| Device mode toggle (22×22px) | Toggles responsive device simulation. Active state: `bg-blue-500/15 text-blue-400 rounded` pill — communicates mode, not just color |
| Help (22×22px) | Opens `https://discord.gg/xk8uXJSvhC` in new tab (`?` icon, tooltip: "Help") |
| Settings gear (22×22px) | Opens settings panel, shows nudge badge or bubble (never both — see nudge section) |

The right zone owns the URL editing local state (`editableUrl`, `isEditingUrl`) moved from `Client__WebPreview`. It reads `Selectors.previewUrl`, `Selectors.previewFrame`, and `Selectors.deviceMode` directly from state, and dispatches `Actions.toggleDeviceMode`, `Actions.setPreviewUrl`, `Actions.clearAnnotations`. The reload handler accesses `previewFrame.contentWindow` from state.

`Client__ProviderNudgeBubble` renders inside a `relative`-positioned wrapper around the settings gear.

---

### Provider Nudge — Sequential Logic

The badge and bubble are **mutually exclusive**. Both must never render at the same time.

| State | Badge | Bubble |
|-------|-------|--------|
| Nudge not yet shown | hidden | hidden |
| Nudge active (first time) | hidden | visible |
| User dismissed bubble without acting | visible | hidden |
| User opened settings and acted | hidden | hidden |

The parent component (`Client__App`) controls `showProviderNudge`. This sequential logic is implemented there — the top bar simply receives `showProviderNudgeBubble: bool` and `showProviderNudgeBadge: bool` as separate props.

---

### `Client__TopBar__WorkspaceDropdown`

280px popover triggered by clicking the task pill in the left zone. The "workspace" label is **retired** — all copy uses "task."

**State reads:**
- `Selectors.tasks` — sorted list (by `updatedAt` desc)
- `Selectors.currentTaskId` — for "Current" badge
- `Selectors.isNewTask` — guards `+` New button (no-op if already on blank task)

**Also uses:** `Client__FrontmanProvider.useFrontman().clearSession`

**Dispatches:** `Actions.switchTask`, `Actions.deleteTask`, `Actions.clearCurrentTask`. No new actions.

**Contents:**
- Search bar at top (placeholder: "Search tasks...", filters list by name, local state)
- Task list, most-recently-updated first
- Each entry: chat icon, task title, "Current" badge on active task, **trash icon always visible** (reduced opacity at rest: `opacity-40`, full on hover/focus)
- Delete triggers confirmation dialog (unchanged)
- Empty states: "No tasks yet" / "No matching tasks"

The trash icon must not be hover-only. It must be reachable without a pointer device.

---

### `Client__TopBar__LogoMenu` — **Removed**

This component is deleted. Its items are redistributed:
- **Settings** — was redundant (gear icon already present); removed
- **Help** — becomes `?` icon button in the right zone
- **Open in new window** — becomes `↗` icon button in the right zone

---

## Removals

### `Client__TaskTabs.res` + `Client__TaskTabs.story.res`

Deleted. All functionality migrated to the new top bar components.

### `Client__WebPreview__Nav.res`

Deleted. `Nav.Navigation`, `Nav.Container`, `Nav.NavButton`, and `Nav.UrlInput` are no longer used. `Client__WebPreview` replaces `Nav.Container` with a plain `<div className="flex flex-col h-full">`.

### `Client__WebPreview__AnnotationControls.res`

Deleted. The selection toggle is redundant with `PromptInput`'s `onSelectElement`. The freeze-animations feature is removed for now and can be re-added in a future PR as a top bar slot.

### `Client__TopBar__LogoMenu.res` + `Client__TopBar__LogoMenu.story.res`

Deleted. Logo becomes a plain visual element. Items redistributed to right zone (see above).

---

## Modified Components

### `Client__Chatbox`

- Removes props: `onSettingsClick`, `showProviderNudge`, `onProviderNudgeDismiss`, `onProviderNudgeCta`
- Removes `<TaskTabs ...>` render
- Chat content starts immediately with `Client__UpdateBanner` then the scroll container

### `Client__App`

- Layout changes to `flex col: [TopBar | flex row: [Chat | Preview]]`
- Passes `chatboxWidth` to `Client__TopBar`
- Passes settings/nudge props directly to `Client__TopBar` instead of `Client__Chatbox`
- Removes settings/nudge props from `<Client__Chatbox>` call
- Implements sequential nudge logic: tracks whether bubble has been dismissed without action, derives `showProviderNudgeBubble` and `showProviderNudgeBadge` booleans

### `Client__WebPreview`

- Removes `Nav.Navigation` and all associated state/handlers
- Removes `Client__WebPreview__AnnotationControls` render
- Replaces `Nav.Container` with plain div

---

## State Changes

**None.** No new reducer actions, effects, or selectors. All existing state covers the new components. The nudge sequencing is local state in `Client__App`.

---

## Storybook Stories

- `Client__TopBar.story.res` — idle state, agent running (logo pulse), device mode active, nudge badge visible, nudge bubble visible
- `Client__TopBar__WorkspaceDropdown.story.res` — empty state, single task, many tasks, search filtering, delete confirmation

---

## Copy Changes

All user-visible strings updated from "workspace" to "task":

| Old | New |
|-----|-----|
| "Search workspaces..." | "Search tasks..." |
| "New workspace" (tooltip) | "New task" |
| "No workspaces yet" | "No tasks yet" |
| "No matching workspaces" | "No matching tasks" |
| "Delete task?" dialog | unchanged (was already correct) |

---

## Future Slots (not in this PR)

These are designed into the layout but not rendered:
- Status dots per task entry (Draft / In review / Merged)
- Status text in top bar left zone ("Draft · 3 changes")
- Change count per task
- Notification badges for review comments
- Section headers in dropdown ("Active" / "Recent")

---

## Acceptance Criteria

- [ ] Single 32px top bar replaces both panel headers
- [ ] Left zone: logo (non-interactive), task dropdown pill, `+` New button
- [ ] Right zone: reload, open-in-new-window, URL bar, device mode toggle, help, settings gear
- [ ] Left zone min-width 240px — controls never clipped by chat panel resize
- [ ] Task dropdown: search bar, task list, always-visible trash icons, empty states
- [ ] Logo is not clickable (no menu, no dropdown)
- [ ] `Client__TopBar__LogoMenu` deleted
- [ ] Device mode active state renders as a pill (`bg-blue-500/15 text-blue-400 rounded`), not just a blue icon
- [ ] Provider nudge: badge and bubble never render simultaneously
- [ ] All "workspace" copy updated to "task"
- [ ] Chat panel has no header — messages start immediately
- [ ] Preview panel has no nav bar — iframe starts immediately
- [ ] All existing functionality preserved (task switching, delete, settings, provider nudge, preview nav, device mode)
- [ ] `Client__WebPreview__AnnotationControls` removed
- [ ] Storybook stories for `Client__TopBar` and `Client__TopBar__WorkspaceDropdown`
- [ ] Resizable divider still works
