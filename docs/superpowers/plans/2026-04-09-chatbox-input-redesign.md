# Chatbox Input Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the chatbox composition surface to reflect its true purpose — a task-composition interface — with stable button positions, a clear visual hierarchy where purple = submit only, and a flush/divided aesthetic.

**Architecture:** The composition zone (everything below the chat history divider) is restyled flush with the `#130d20` panel background. `Client__PromptInput` owns the toolbar and input field. `Client__SelectedElementDisplay` is restyled to match the flush context. `Client__Chatbox` adds the divider and reorders the zone elements. No new components; no new dependencies.

**Tech Stack:** ReScript, React, Tailwind CSS, daisyUI, Radix UI (Select only — no new Radix deps needed), Storybook for visual verification.

---

### How to build and verify

```bash
# From the repo root or worktree root
./bin/pod-exec make rescript-build     # compile ReScript
cd libs/client && make storybook        # visual verification in browser
```

After each task, build and open Storybook to confirm the visual change before committing.

---

### Task 1: Create PromptInput Storybook stories (visual baseline)

**Files:**
- Create: `libs/client/src/components/frontman/Client__PromptInput.story.res`

This gives us a visual test harness before touching any production code.

- [ ] **Step 1: Create the story file**

```rescript
// libs/client/src/components/frontman/Client__PromptInput.story.res
open Bindings__Storybook

type args = {
  isAgentRunning: bool,
  hasActiveACPSession: bool,
  isSelecting: bool,
  hasAnnotations: bool,
  isEnrichingAnnotations: bool,
  disabled: bool,
}

let default: Meta.t<args> = {
  title: "Frontman/PromptInput",
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
  render: args =>
    <Client__PromptInput
      onSubmit={(~text as _, ~inputItems as _) => ()}
      onCancel={() => ()}
      modelConfigOption=None
      isModelsConfigLoading=false
      selectedModelValue=None
      onModelChange={_ => ()}
      isAgentRunning={args.isAgentRunning}
      hasActiveACPSession={args.hasActiveACPSession}
      isSelecting={args.isSelecting}
      hasAnnotations={args.hasAnnotations}
      isEnrichingAnnotations={args.isEnrichingAnnotations}
      disabled={args.disabled}
      onSelectElement={Some(() => ())}
    />,
}

let defaultState: Story.t<args> = {
  name: "Default (idle, session active)",
  args: {
    isAgentRunning: false,
    hasActiveACPSession: true,
    isSelecting: false,
    hasAnnotations: false,
    isEnrichingAnnotations: false,
    disabled: false,
  },
}

let selectionMode: Story.t<args> = {
  name: "Selection mode active",
  args: {
    isAgentRunning: false,
    hasActiveACPSession: true,
    isSelecting: true,
    hasAnnotations: false,
    isEnrichingAnnotations: false,
    disabled: false,
  },
}

let withAnnotations: Story.t<args> = {
  name: "Has annotations",
  args: {
    isAgentRunning: false,
    hasActiveACPSession: true,
    isSelecting: false,
    hasAnnotations: true,
    isEnrichingAnnotations: false,
    disabled: false,
  },
}

let agentRunning: Story.t<args> = {
  name: "Agent running",
  args: {
    isAgentRunning: true,
    hasActiveACPSession: true,
    isSelecting: false,
    hasAnnotations: false,
    isEnrichingAnnotations: false,
    disabled: false,
  },
}

let disabled: Story.t<args> = {
  name: "Disabled (usage exhausted)",
  args: {
    isAgentRunning: false,
    hasActiveACPSession: true,
    isSelecting: false,
    hasAnnotations: false,
    isEnrichingAnnotations: false,
    disabled: true,
  },
}
```

- [ ] **Step 2: Build and verify story loads**

```bash
./bin/pod-exec make rescript-build
cd libs/client && make storybook
```

Open `http://localhost:6006` and confirm "Frontman/PromptInput" appears in the sidebar with all five story variants.

- [ ] **Step 3: Commit**

```bash
jj describe -m "test: add PromptInput Storybook stories"
jj new
```

---

### Task 2: Strip the input field purple border and background tint

**Files:**
- Modify: `libs/client/src/components/frontman/Client__PromptInput.res` (around line 908)

The editable div currently has `bg-[#8051CD]/20 border-2 border-[#8051CD]/60 rounded-xl`. We replace this with a bottom border only, making the field flush with the panel background. This also removes the shape inconsistency (rounded-xl box inside a flat surface).

- [ ] **Step 1: Update the editable div className**

Find and replace the className array in the `make` component's editable div (around line 908):

```rescript
// BEFORE
className={[
  "w-full min-h-[48px] max-h-[200px] px-4 py-3",
  "bg-[#8051CD]/20 border-2 border-[#8051CD]/60 rounded-xl",
  "text-sm text-zinc-100",
  "overflow-y-auto",
  "focus:outline-none focus:border-[#8051CD]/80",
  "caret-[#8051CD] [caret-shape:block] [caret-animation:manual]",
  "whitespace-pre-wrap break-words",
  if isInputDisabled {
    "opacity-60 cursor-not-allowed"
  } else {
    ""
  },
]
->Array.filter(c => c != "")
->Array.join(" ")}

// AFTER
className={[
  "w-full min-h-[48px] max-h-[200px] px-4 py-3",
  "border-b border-white/10",
  "text-sm text-zinc-100",
  "overflow-y-auto",
  "focus:outline-none",
  "whitespace-pre-wrap break-words",
  if isInputDisabled {
    "opacity-60 cursor-not-allowed"
  } else {
    ""
  },
]
->Array.filter(c => c != "")
->Array.join(" ")}
```

Also update the outer drag overlay ring (around line 859) from `ring-violet-500/50` to `ring-white/20`:

```rescript
// BEFORE
className={`bg-[#130d20] relative shrink-0 ${isDragging
    ? "ring-2 ring-violet-500/50 ring-inset"
    : ""}`}

// AFTER
className={`bg-[#130d20] relative shrink-0 ${isDragging
    ? "ring-2 ring-white/20 ring-inset"
    : ""}`}
```

- [ ] **Step 2: Build and check Storybook**

```bash
./bin/pod-exec make rescript-build
```

Open Storybook "Default (idle, session active)" — the input area should be flat, no purple box, just a subtle bottom border line. The input should still be clearly editable via the placeholder text.

- [ ] **Step 3: Commit**

```bash
jj describe -m "style: remove purple border and tint from chat input field"
jj new
```

---

### Task 3: Restructure toolbar — new SelectElementButton + icon-only Attach

**Files:**
- Modify: `libs/client/src/components/frontman/Client__PromptInput.res`

This replaces the existing `SelectElementButton` sub-component and the `+` attachment button with new designs. The `SelectElementButton` gets three visual states. The attach button becomes icon-only at 32px, consistent with the toolbar height.

The current `SelectElementButton` is at around line 420. Replace it entirely:

- [ ] **Step 1: Replace the SelectElementButton sub-component**

Find the existing `SelectElementButton` module (around line 419) and replace it:

```rescript
// Select element button — three visual states:
// resting: zinc, label visible
// selecting: violet, shows "Selecting…"
// has-annotations (isSelecting=false but hasAnnotations=true): zinc-200 with dot indicator
module SelectElementButton = {
  @react.component
  let make = (
    ~onClick: unit => unit,
    ~isSelecting: bool,
    ~hasAnnotations: bool,
  ) => {
    let (label, extraClass) = switch (isSelecting, hasAnnotations) {
    | (true, _) => ("Selecting\xe2\x80\xa6", "text-violet-300 bg-violet-600/20 hover:bg-violet-600/30")
    | (false, true) => ("Select element", "text-zinc-200 hover:bg-white/6")
    | (false, false) => ("Select element", "text-zinc-400 hover:text-zinc-200 hover:bg-white/6")
    }

    <button
      type_="button"
      onClick={_ => onClick()}
      className={`inline-flex items-center gap-1.5 h-8 px-2.5 rounded-md text-xs font-medium
                 transition-colors ${extraClass}`}
      title={isSelecting ? "Cancel selection" : "Select an element in the preview"}
    >
      {switch isSelecting {
      | true =>
        <span
          className="w-1.5 h-1.5 rounded-full bg-violet-400 animate-pulse flex-shrink-0"
        />
      | false =>
        <Icons.CursorClickIcon size=13 className={hasAnnotations ? "text-zinc-200" : "text-zinc-400"} />
      }}
      <span> {React.string(label)} </span>
      {switch (isSelecting, hasAnnotations) {
      | (false, true) =>
        <span
          className="w-1.5 h-1.5 rounded-full bg-violet-400 flex-shrink-0"
          title="Element selected"
        />
      | _ => React.null
      }}
    </button>
  }
}
```

Note: `\xe2\x80\xa6` is the UTF-8 encoding for `…` (ellipsis). Alternatively write the character directly: `"Selecting…"`.

- [ ] **Step 2: Update the footer row in the main make component**

Find the footer div (around line 937) and replace it entirely:

```rescript
// Footer with tools and submit
<div className="flex items-center justify-between px-3 pb-2 pt-1">
  <div className="flex items-center gap-1">
    // Select Element button
    {switch onSelectElement {
    | Some(handler) =>
      <SelectElementButton
        onClick={handler}
        isSelecting={isSelecting}
        hasAnnotations={hasAnnotations}
      />
    | None => React.null
    }}

    // Attach button — icon only
    <button
      type_="button"
      onClick={_ => {
        fileInputRef.current
        ->Nullable.toOption
        ->Option.forEach(input => {
          let clickElement: Dom.element => unit = %raw(`function(el) { el.click(); }`)
          clickElement(input->Obj.magic)
        })
      }}
      className="inline-flex items-center justify-center w-8 h-8 rounded-md
                 text-zinc-400 hover:text-zinc-200 hover:bg-white/6
                 transition-colors"
      title="Attach files (images, PDFs)"
    >
      <Icons.PlusIcon size=15 />
    </button>
    <input
      ref={ReactDOM.Ref.domRef(fileInputRef)}
      type_="file"
      multiple=true
      accept={acceptedTypesString}
      onChange={handleFileInputChange}
      className="hidden"
    />

    // Overflow button — model selector
    <OverflowButton
      modelConfigOption
      isModelsConfigLoading
      selectedModelValue
      onModelChange
    />
  </div>

  // Submit / Stop
  <SubmitButton disabled={isSubmitDisabled} isAgentRunning onClick={doSubmit} onCancel />
</div>
```

- [ ] **Step 3: Add OverflowButton sub-component** (above `make`, after SelectElementButton)

```rescript
// Overflow button — ⋯ trigger that reveals the model selector in a panel above the toolbar
module OverflowButton = {
  @react.component
  let make = (
    ~modelConfigOption: option<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigOption>,
    ~isModelsConfigLoading: bool,
    ~selectedModelValue: option<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigValueId>,
    ~onModelChange: string => unit,
  ) => {
    let (isOpen, setIsOpen) = React.useState(() => false)

    <div className="relative">
      <button
        type_="button"
        onClick={_ => setIsOpen(prev => !prev)}
        className="inline-flex items-center justify-center w-8 h-8 rounded-md
                   text-zinc-400 hover:text-zinc-200 hover:bg-white/6
                   transition-colors"
        title="More options"
      >
        <span className="tracking-widest text-sm leading-none"> {React.string("\xc2\xb7\xc2\xb7\xc2\xb7")} </span>
      </button>
      {isOpen
        ? <div
            className="absolute bottom-10 left-0 z-50 min-w-[180px]
                       bg-zinc-900 border border-white/10 rounded-lg shadow-xl p-2"
          >
            <div className="text-[10px] text-zinc-500 px-2 pb-1 uppercase tracking-wide">
              {React.string("Model")}
            </div>
            {switch (isModelsConfigLoading, modelConfigOption) {
            | (true, _) =>
              <div className="px-2 py-1 text-xs text-zinc-500">
                {React.string("Loading...")}
              </div>
            | (false, Some(configOption)) =>
              <ModelSelector
                configOption
                selectedValue={selectedModelValue->Option.getOr("")}
                onModelChange={v => {
                  onModelChange(v)
                  setIsOpen(_ => false)
                }}
              />
            | (false, None) => React.null
            }}
          </div>
        : React.null}
    </div>
  }
}
```

Note: `\xc2\xb7\xc2\xb7\xc2\xb7` is `···` (three middle dots, U+00B7). You can also write `"···"` directly.

- [ ] **Step 4: Build and verify**

```bash
./bin/pod-exec make rescript-build
```

In Storybook: toolbar should show `[Select element] [+] [···]` on the left, `[Send]` on the right. All buttons are 32px tall. Check the "Selection mode active" story — Select Element button should pulse violet.

- [ ] **Step 5: Commit**

```bash
jj describe -m "feat: restructure chatbox toolbar with new SelectElement and overflow buttons"
jj new
```

---

### Task 4: Update SubmitButton — Stop becomes a pill, toolbar dims when running

**Files:**
- Modify: `libs/client/src/components/frontman/Client__PromptInput.res`

Two changes: the Stop button gets a text label and wider shape; the whole toolbar fades when the agent is running.

- [ ] **Step 1: Update SubmitButton sub-component** (around line 456)

```rescript
// Submit/Stop button
module SubmitButton = {
  @react.component
  let make = (
    ~disabled: bool,
    ~isAgentRunning: bool,
    ~onClick: unit => unit,
    ~onCancel: unit => unit,
  ) => {
    if isAgentRunning {
      // Stop — pill with text label, feels different from compose mode
      <button
        type_="button"
        onClick={e => {
          ReactEvent.Mouse.preventDefault(e)
          onCancel()
        }}
        className="inline-flex items-center gap-2 h-8 px-4 rounded-full
                   bg-[#985DF7] hover:bg-[#8247E5] text-white text-xs font-medium
                   transition-all hover:scale-105"
        title="Stop generation"
      >
        <StopIcon size=12 />
        <span> {React.string("Stop")} </span>
      </button>
    } else {
      // Send — circle, the sole purple element at rest
      <button
        type_="submit"
        disabled
        onClick={e => {
          ReactEvent.Mouse.preventDefault(e)
          onClick()
        }}
        className="flex items-center justify-center w-8 h-8 rounded-full
                   transition-all text-white
                   bg-[#985DF7] hover:bg-[#8247E5] hover:scale-105
                   disabled:bg-zinc-700/50 disabled:text-zinc-500 disabled:cursor-not-allowed disabled:scale-100"
        title="Send (Enter)"
      >
        <Icons.SendArrowIcon size=14 />
      </button>
    }
  }
}
```

- [ ] **Step 2: Dim the toolbar buttons when agent is running**

In the main `make` component, find the footer `<div className="flex items-center justify-between ...">` and update it to pass opacity through when running:

```rescript
<div className="flex items-center justify-between px-3 pb-2 pt-1">
  <div className={`flex items-center gap-1 transition-opacity ${isAgentRunning ? "opacity-40 pointer-events-none" : ""}`}>
    // ... toolbar buttons unchanged
  </div>
  <SubmitButton disabled={isSubmitDisabled} isAgentRunning onClick={doSubmit} onCancel />
</div>
```

- [ ] **Step 3: Build and verify**

```bash
./bin/pod-exec make rescript-build
```

In Storybook "Agent running": left toolbar should be faded, submit should read `[■ Stop]` as a pill. In "Default": submit is a purple circle, toolbar is full opacity.

- [ ] **Step 4: Commit**

```bash
jj describe -m "feat: stop button becomes pill with label, toolbar dims when agent running"
jj new
```

---

### Task 5: Restyle SelectedElementDisplay to flush design

**Files:**
- Modify: `libs/client/src/Client__SelectedElementDisplay.res`

The current outer container is a card: `rounded-xl border border-[#8051CD]/40 bg-[#180C2D]/80`. In the flush design this sits directly on `#130d20` — no card, no border, no elevated background.

- [ ] **Step 1: Update the outer container**

Find the outer container div in the `make` component (around line 173):

```rescript
// BEFORE
<div
  className="mx-3 mb-2 rounded-xl border border-[#8051CD]/40 bg-[#180C2D]/80 overflow-hidden"
>

// AFTER
<div className="mx-3 mb-1 overflow-hidden">
```

- [ ] **Step 2: Update the header row**

Find the header div (around line 176):

```rescript
// BEFORE
<div className="flex items-center gap-2.5 px-3.5 py-2.5">
  <Icons.CursorClickIcon size=18 className="text-[#985DF7] flex-shrink-0" />
  <span className="font-mono text-sm font-semibold text-[#985DF7] flex-grow">

// AFTER
<div className="flex items-center gap-2 px-0.5 py-1.5">
  <Icons.CursorClickIcon size=14 className="text-zinc-400 flex-shrink-0" />
  <span className="text-xs font-medium text-zinc-400 flex-grow">
```

Also update the Clear button:

```rescript
// BEFORE
<button
  onClick={_ => Client__State.Actions.clearAnnotations()}
  className="px-2.5 py-1 rounded-md text-xs font-medium text-zinc-300 bg-[#8051CD]/25 hover:bg-[#8051CD]/40 transition-colors flex-shrink-0"
  title="Clear all annotations"
>

// AFTER
<button
  onClick={_ => Client__State.Actions.clearAnnotations()}
  className="px-2 py-0.5 rounded text-xs text-zinc-500 hover:text-zinc-300 hover:bg-white/6 transition-colors flex-shrink-0"
  title="Clear all annotations"
>
```

- [ ] **Step 3: Update AnnotationRow number badge**

The number badge uses `bg-violet-600/80`. Update to neutral:

```rescript
// BEFORE
className="flex-shrink-0 flex items-center justify-center w-5 h-5 rounded-full bg-violet-600/80 text-white text-[10px] font-bold mt-0.5"

// AFTER
className="flex-shrink-0 flex items-center justify-center w-5 h-5 rounded-full bg-white/10 text-zinc-300 text-[10px] font-bold mt-0.5"
```

- [ ] **Step 4: Update the show-more toggle border**

```rescript
// BEFORE
className="w-full px-3.5 py-1.5 text-xs text-zinc-400 hover:text-zinc-200 transition-colors border-t border-[#8051CD]/20"

// AFTER
className="w-full px-0.5 py-1.5 text-xs text-zinc-400 hover:text-zinc-200 transition-colors border-t border-white/8"
```

- [ ] **Step 5: Build and verify**

```bash
./bin/pod-exec make rescript-build
```

Open the full app in dev and add some annotations — the display should appear flat on the dark background, no purple card.

- [ ] **Step 6: Commit**

```bash
jj describe -m "style: restyle SelectedElementDisplay to flush design"
jj new
```

---

### Task 6: Add composition zone divider in Chatbox

**Files:**
- Modify: `libs/client/src/Client__Chatbox.res` (around line 443)

The divider is a 1px `border-t border-white/8` line that separates message history from the composition zone. It wraps everything from `Client__SelectedElementDisplay` downward. The usage info banner moves above the divider.

- [ ] **Step 1: Reorder elements and add divider wrapper**

Find the bottom section of the `make` component (around line 442). Replace:

```rescript
// BEFORE
<Client__PlanDisplay entries=planEntries />
<Client__SelectedElementDisplay />
{switch (usageInfo, hasAnyKey) {
| (Some({limit: Some(limit), remaining: Some(remaining), hasServerKey: Some(true)}), false) =>
  <div className="px-4 pb-1 text-xs text-zinc-400 shrink-0">
    ...
  </div>
| _ => React.null
}}
{switch hasPendingQuestion {
| true => <Client__QuestionDrawer />
| false => <PromptInput ... />
}}

// AFTER
<Client__PlanDisplay entries=planEntries />
{switch (usageInfo, hasAnyKey) {
| (Some({limit: Some(limit), remaining: Some(remaining), hasServerKey: Some(true)}), false) =>
  <div className="px-4 pb-1 text-xs text-zinc-400 shrink-0">
    {React.string(
      `Free requests remaining: ${remaining->Int.toString} / ${limit->Int.toString}. Add your API key in Settings to remove limits.`,
    )}
  </div>
| _ => React.null
}}
<div className="border-t border-white/8 shrink-0">
  <Client__SelectedElementDisplay />
  {switch hasPendingQuestion {
  | true => <Client__QuestionDrawer />
  | false =>
    <PromptInput
      onSubmit={handleSubmit}
      onCancel={Client__State.Actions.cancelTurn}
      modelConfigOption
      isModelsConfigLoading
      selectedModelValue
      onModelChange={value => Client__State.Actions.setSelectedModelValue(~value)}
      isAgentRunning
      hasActiveACPSession
      disabled={isUsageExhausted}
      disabledPlaceholder="Free requests exhausted. Add your API key in Settings to continue."
      onSelectElement={Client__State.Actions.toggleWebPreviewSelection}
      isSelecting={webPreviewIsSelecting}
      hasAnnotations
      isEnrichingAnnotations={hasEnrichingAnnotations}
    />
  }}
</div>
```

- [ ] **Step 2: Build and verify**

```bash
./bin/pod-exec make rescript-build
```

Run the full app and verify: there is a visible 1px divider line between the message history and the composition zone. The annotations display (if any) and the input both sit below the divider on the flat `#130d20` background.

- [ ] **Step 3: Verify all five Storybook stories still render correctly**

```bash
cd libs/client && make storybook
```

Check Default, SelectionMode, WithAnnotations, AgentRunning, Disabled.

- [ ] **Step 4: Commit**

```bash
jj describe -m "feat: add composition zone divider, reorder usage banner above divider"
jj new
```

---

## Self-review checklist (done before publishing)

- [x] **Spec: flush/divided** — Task 6 adds `border-t border-white/8` divider. Task 2 removes input card. ✓
- [x] **Spec: buttons anchored at bottom** — Toolbar stays in footer row throughout all tasks. Context (SelectedElementDisplay) renders above it. ✓
- [x] **Spec: one purple = submit** — Task 2 removes purple from input. Task 5 removes purple from annotations display. Task 3/4 keeps purple only on submit/stop button. ✓
- [x] **Spec: Select Element dual-role** — Task 3 implements three visual states (resting / selecting / has-annotations). The button itself shows the "active context" indicator dot. ✓
- [x] **Spec: Stop as pill** — Task 4 implements `[■ Stop]` pill. ✓
- [x] **Spec: overflow hides model selector** — Task 3 moves model selector into `OverflowButton` panel. ✓
- [x] **Spec: toolbar dims when agent running** — Task 4 adds `opacity-40 pointer-events-none` to left toolbar when `isAgentRunning`. ✓
- [x] **Spec: context chips neutral styling** — The existing file/paste chips in PromptInput use `bg-violet-900/60`. These are a follow-up — they live in the `%raw` DOM manipulation functions (`createFileChipElement`, `createPastedTextChipElement`) and are out of scope for this plan. Flagged as future work.
- [x] **Type consistency** — `SelectElementButton` receives `~hasAnnotations: bool` (new prop). The call site in the footer already has `hasAnnotations` in scope. `OverflowButton` uses the same `modelConfigOption`/`isModelsConfigLoading`/`selectedModelValue`/`onModelChange` types as the existing `ModelSelector` call. ✓
- [x] **No placeholders** — All code blocks are complete. ✓
