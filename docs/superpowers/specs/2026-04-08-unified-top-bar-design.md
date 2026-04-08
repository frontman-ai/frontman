# Unified Top Bar — Design Spec

**Issue:** #802  
**Date:** 2026-04-08  
**Type:** Layout refactor (no new state, no new API)

---

## Summary

Replace the two separate panel headers (chat's `Client__TaskTabs` and preview's `Client__WebPreview__Nav`) with a single 32px top bar spanning the full viewport width. Same functionality, new structure. Prepares the UI for future workspace/git integration features.

---

## Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│ [F] [▼ Workspace name]           + New  │  ↻  [  URL bar  ]  📱  ⚙  │
│         LEFT ZONE (above chat)          │   RIGHT ZONE (above preview) │
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

The top bar left zone width is set to `chatboxWidth` (an `int` prop passed from `Client__App`, which owns it via `Client__UseResizableWidth.use()`). The right zone takes remaining space. A vertical divider between zones visually continues the panel border below.

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
| Logo (18×18px) | Frontman "F", pulse when agent running, click opens `Client__TopBar__LogoMenu` |
| Workspace dropdown pill | Current task title + chevron, click opens `Client__TopBar__WorkspaceDropdown` |
| "+ New" ghost button | Creates new task (same logic as current `TaskTabs`) |

**Right zone (preview controls):**
| Element | Behavior |
|---------|----------|
| Reload (22×22px) | Reloads preview iframe |
| URL bar | Dark-themed, editable, shows current preview URL |
| Device mode toggle (22×22px) | Toggles responsive device simulation |
| Settings gear (22×22px) | Opens settings panel, shows nudge dot, renders `Client__ProviderNudgeBubble` |

The right zone owns the URL editing local state (`editableUrl`, `isEditingUrl`) moved from `Client__WebPreview`. It reads `Selectors.previewUrl`, `Selectors.previewFrame`, and `Selectors.deviceMode` directly from state, and dispatches `Actions.toggleDeviceMode`, `Actions.setPreviewUrl`, `Actions.clearAnnotations`. The reload handler accesses `previewFrame.contentWindow` from state (same as current `Client__WebPreview` does).

`Client__ProviderNudgeBubble` renders inside a `relative`-positioned wrapper around the settings gear, preserving its current `absolute top-full right-0` positioning behaviour.

---

### `Client__TopBar__WorkspaceDropdown`

280px popover triggered by clicking the workspace pill in the left zone.

**State reads:**
- `Selectors.tasks` — sorted list (by `updatedAt` desc, same selector as `TaskTabs`)
- `Selectors.currentTaskId` — for "Current" badge
- `Selectors.isNewTask` — guards "+ New" button (no-op if already on blank task)

**Also uses:** `Client__FrontmanProvider.useFrontman().clearSession` — required before deleting the current task or clearing it for a new one (tears down the ACP connection first).

**Dispatches:** `Actions.switchTask`, `Actions.deleteTask`, `Actions.clearCurrentTask`. No new actions.

**Contents:**
- Search bar at top (filters list by name, local state)
- Task list, most-recently-updated first
- Each entry: task title, "Current" badge on active task, trash icon (hover-reveal, triggers delete confirmation dialog same as current `TaskTabs`)

---

### `Client__TopBar__LogoMenu`

Dropdown popover on logo click.

**Items:**
| Label | Action |
|-------|--------|
| Settings | Calls `onSettingsClick` prop |
| Help (Discord) | Opens `https://discord.gg/xk8uXJSvhC` in new tab |
| Open in new window | Opens current `previewUrl` in new tab |

Reads `Selectors.previewUrl` for the "Open in new window" item. No reducer changes.

---

## Removals

### `Client__TaskTabs.res` + `Client__TaskTabs.story.res`

Deleted. All functionality migrated to the new top bar components.

### `Client__WebPreview__Nav.res`

Deleted. `Nav.Navigation`, `Nav.Container`, `Nav.NavButton`, and `Nav.UrlInput` are no longer used. `Client__WebPreview` replaces `Nav.Container` with a plain `<div className="flex flex-col h-full">`.

### `Client__WebPreview__AnnotationControls.res`

Deleted. The selection toggle is redundant with `PromptInput`'s `onSelectElement`. The freeze-animations feature is removed for now and can be re-added in a future PR as a top bar slot.

---

## Modified Components

### `Client__Chatbox`

- Removes props: `onSettingsClick`, `showProviderNudge`, `onProviderNudgeDismiss`, `onProviderNudgeCta` (these were only threaded through to `TaskTabs`)
- Removes `<TaskTabs ...>` render
- Chat content now starts immediately with `Client__UpdateBanner` then the scroll container

### `Client__App`

- Layout changes to `flex col: [TopBar | flex row: [Chat | Preview]]`
- Passes `chatboxWidth` to `Client__TopBar`
- Passes settings/nudge props directly to `Client__TopBar` instead of `Client__Chatbox`
- Removes settings/nudge props from `<Client__Chatbox>` call

### `Client__WebPreview`

- Removes `Nav.Navigation` and all associated state/handlers: `editableUrl`, `isEditingUrl`, `handleReload`, `handleBack`, `handleForward`, `handleUrlChange`, `handleUrlKeyDown`, `handleUrlFocus`, `handleUrlBlur`, `handleOpenInNewTab`, `handleToggleDeviceMode`
- Removes `Client__WebPreview__AnnotationControls` render
- Inlines the freeze CSS `useEffect` logic if needed, or removes entirely (per decision: remove entirely)
- Replaces `Nav.Container` with plain div
- First rendered child becomes `Client__WebPreview__DeviceBar` (conditional) then the iframe viewport

---

## State Changes

**None.** No new actions, reducers, effects, or selectors. All existing state covers the new components.

---

## Storybook Stories

- `Client__TopBar.story.res` — top bar with/without active workspace, agent running state
- `Client__TopBar__WorkspaceDropdown.story.res` — empty state, single task, many tasks, search filtering

Fixture helpers from `Client__TaskTabs.story.res` can be reused in the new story files before the old file is deleted.

---

## Future Slots (not in this PR)

These are designed into the layout but not rendered:
- Status dots per workspace entry (Draft / In review / Merged)
- Status text in top bar left zone ("Draft · 3 changes")
- Change count per workspace
- Notification badges for review comments
- Section headers in dropdown ("Active" / "Recent")

---

## Acceptance Criteria

- [ ] Single 32px top bar replaces both panel headers
- [ ] Left zone shows logo, workspace dropdown pill, "+ New" button
- [ ] Right zone shows reload, URL bar, device mode toggle, settings gear
- [ ] Workspace dropdown opens on pill click with search and task list
- [ ] Logo click opens overflow menu with settings, help, open-in-new-window
- [ ] Chat panel has no header — messages start immediately
- [ ] Preview panel has no nav bar — iframe starts immediately (or DeviceBar if active)
- [ ] All existing functionality preserved (task switching, delete, settings, provider nudge, preview nav, device mode)
- [ ] `Client__ProviderNudgeBubble` renders correctly near settings gear
- [ ] Storybook stories for new components
- [ ] Resizable divider still works and top bar left zone tracks its width
- [ ] `Client__WebPreview__AnnotationControls` removed, freeze feature gone
