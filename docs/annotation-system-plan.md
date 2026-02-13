# Annotation System Plan

Replace Frontman's current single-element picker with an Agentation-inspired annotation
system ported to ReScript. Supports both quick single-click and batch annotation mode
(multiple elements with per-element comments).

**Inspiration**: [Agentation](https://github.com/benjitaylor/agentation) — a visual
feedback tool that captures structured element data (selectors, component names, positions)
for AI agents. We port the UX/concepts to ReScript and integrate with Frontman's existing
element identification pipeline (which is stronger) and agent execution pipeline.

**Key decisions**:
- Everything is an annotation, even single-element quick mode (unified model)
- Annotation controls live in the emulated browser toolbar (`Nav.Navigation`)
- Frontman's source detection pipeline is kept and augmented (not replaced)
- No Agentation MCP server — annotations flow through Frontman's ACP channel
- No backward compatibility concerns — system is not deployed yet
- All code ported to ReScript (no JS/TS dependency on Agentation package)

---

## Deliverables

- [D1: Annotation types + Quick mode state (client only)](#d1-annotation-types--quick-mode-state-client-only)
- [D2: ACP + Server — annotations end-to-end](#d2-acp--server--annotations-end-to-end)
- [D3: Enhanced element data](#d3-enhanced-element-data)
- [D4: Markers + Toolbar controls + Batch mode UI](#d4-markers--toolbar-controls--batch-mode-ui)
- [D5: Drag selection + Multi-select + Animation freeze](#d5-drag-selection--multi-select--animation-freeze)
- [D6: Cleanup + Polish](#d6-cleanup--polish)

### Summary

| Deliverable | Testable Outcome | Risk |
|-------------|-----------------|------|
| D1 | Current flow works identically on new data model | Low |
| D2 | Full pipeline works with new annotation wire format | Medium |
| D3 | Agent receives richer context (classes, text, tag) | Low |
| D4 | Multi-annotation visual UX, batch messages sent | High |
| D5 | Drag-select, multi-select, animation freeze | Medium |
| D6 | No dead code, all tests pass | Low |

---

## D1: Annotation types + Quick mode state (client only)

**Status**: `pending`

**Goal**: Replace `SelectedElement` with the annotation model in client state. Quick mode
works exactly like the current element picker — click an element, it becomes the single
annotation. No visual changes except what is needed to keep the existing flow working.

A temporary adapter (`annotationToLegacyContentBlocks`) converts the first annotation back
into the old `selected_component` / `selected_component_screenshot` content block shape so
`taskToContentBlocks` and the server continue to work unchanged.

### Tasks

- [ ] **D1.1** Create `libs/client/src/Client__Annotation__Types.res`
  - `Annotation.position` type: `{xPercent: float, yAbsolute: float}`
  - `Annotation.boundingBox` type: `{x: float, y: float, width: float, height: float}`
  - `Annotation.t` type with fields:
    - `id: string`
    - `element: WebAPI.DOMAPI.element` (live DOM ref, not serialized)
    - `comment: option<string>` (optional in Quick mode)
    - `selector: option<string>` (CSS selector via @medv/finder)
    - `screenshot: option<string>` (base64 JPEG via @zumer/snapdom)
    - `sourceLocation: option<Client__Types.SourceLocation.t>`
    - `tagName: string`
    - `cssClasses: option<string>`
    - `boundingBox: option<boundingBox>`
    - `nearbyText: option<string>`
    - `position: position`
    - `timestamp: float`
    - `selectedText: option<string>`

- [ ] **D1.2** Modify `libs/client/src/state/Client__Task__Types.res`
  - Add `annotationMode` variant: `Off | Quick | Batch`
  - In task state variants (New, Loading, Loaded), replace:
    - `selectedElement: option<SelectedElement.t>` → `annotations: array<Annotation.t>`
    - `webPreviewIsSelecting: bool` → `annotationMode: annotationMode`
  - Add `pendingAnnotation: option<{element: WebAPI.DOMAPI.element, position: Annotation.position, tagName: string}>`
  - Add temporary adapter: `annotationToLegacyContentBlocks` that converts first annotation
    to the old `selected_component` / `selected_component_screenshot` content block format
  - Keep `taskToContentBlocks` working by calling the adapter

- [ ] **D1.3** Modify `libs/client/src/state/Client__Task__Reducer.res`
  - Remove actions: `SetSelectedElement`, `ToggleWebPreviewSelection`, `NavigateToParentElement`, `NavigateToChildElement`
  - Remove effect: `FetchElementDetails`
  - Add actions:
    - `SetAnnotationMode(annotationMode)`
    - `AddAnnotation({element, position, tagName})` — creates annotation with generated id, fires effect
    - `RemoveAnnotation({id: string})`
    - `ClearAnnotations`
    - `AnnotationDetailsResolved({id, selector, screenshot, sourceLocation})`
  - Add effect: `FetchAnnotationDetails({id: string, element: WebAPI.DOMAPI.element})`
    - Runs same 3 parallel ops: @medv/finder, @zumer/snapdom, source detection + server resolution
    - On resolve, dispatches `AnnotationDetailsResolved`
  - In Quick mode: `AddAnnotation` clears existing annotations first (max 1)

- [ ] **D1.4** Modify `libs/client/src/state/Client__State.res`
  - Replace selectors:
    - `selectedElement` → `annotations`
    - `webPreviewIsSelecting` → `annotationMode`
  - Replace action creators:
    - `setSelectedElement` → `addAnnotation`
    - `toggleWebPreviewSelection` → `setAnnotationMode`
  - Add: `removeAnnotation`, `clearAnnotations`

- [ ] **D1.5** Modify `libs/client/src/webpreview/Client__WebPreview.res`
  - `SelectElement` button: dispatch `SetAnnotationMode(Quick)` / `SetAnnotationMode(Off)` instead of `toggleWebPreviewSelection`
  - Read `annotationMode` selector instead of `webPreviewIsSelecting`

- [ ] **D1.6** Modify `libs/client/src/webpreview/Client__WebPreview__Stage.res`
  - Click handler: create annotation via `addAnnotation(~element, ~position, ~tagName)` instead of `setSelectedElement`
  - Read `annotationMode != Off` instead of `webPreviewIsSelecting`
  - Pass `annotations[0]` to `ClickedElement` component (it reads the element ref for positioning)

- [ ] **D1.7** Modify `libs/client/src/webpreview/Client__WebPreview__ClickedElement.res`
  - Read from annotations (first annotation's element) instead of selectedElement

- [ ] **D1.8** Modify `libs/client/src/Client__SelectedElementDisplay.res`
  - Read from annotations (first annotation) instead of selectedElement
  - Remove navigate-to-parent/child controls (will be redesigned in D4)

- [ ] **D1.9** Modify `libs/client/src/Client__Chatbox.res`
  - Use new selectors/actions (`annotationMode`, `annotations`, `setAnnotationMode`)

- [ ] **D1.10** Modify `libs/client/src/state/Client__StateSnapshot.res`
  - Serialize/deserialize annotations instead of SelectedElement

- [ ] **D1.11** Modify `libs/client/src/state/Client__State__StateReducer.res`
  - Update `sendMessageToAPIImpl` — it currently calls `taskToContentBlocks` which uses
    the adapter, so minimal changes here. Just ensure it compiles with new type signatures.

- [ ] **D1.12** Update `libs/client/test/Client__State__Types.test.res`
  - Test the temporary `annotationToLegacyContentBlocks` adapter produces valid content blocks

### How to test

**Manual**:
1. Start dev environment
2. Open Frontman in browser
3. Click "Select Element" in browser toolbar — verify cursor changes to crosshair
4. Hover over elements in iframe — verify highlight appears
5. Click an element — verify border appears around it
6. Verify element info shows in chatbox (component name, tag)
7. Type a message and send — verify the agent receives element context and acts on it
8. Click a different element — verify previous selection is replaced
9. Toggle selection off — verify cursor returns to normal, element stays selected
10. Full round-trip: select element → send message → agent edits file → verify correctness

**Automated**:
- `annotationToLegacyContentBlocks` tests in `Client__State__Types.test.res`
- Build succeeds: `make build` (or ReScript compiler) with no errors

---

## D2: ACP + Server — annotations end-to-end

**Status**: `pending`

**Goal**: Replace the `selected_component` wire format and server-side extraction with the
unified annotation format. Remove the temporary adapter from D1. Full pipeline: client
annotation → ACP content blocks → server extraction → LLM message context.

### Tasks

- [ ] **D2.1** Modify `libs/client/src/state/Client__Task__Types.res`
  - Replace `taskToContentBlocks` to generate annotation content blocks
  - Remove `annotationToLegacyContentBlocks` adapter
  - Remove `selectedElementToContentBlock`, `selectedElementScreenshotToContentBlock`
  - New format per annotation:
    - Block 1 (resource): `_meta: {annotation: true, annotation_index, annotation_id, comment, file, line, column, component_name, component_props, parent, tag_name}`
    - Block 2 (screenshot blob): `_meta: {annotation_screenshot: true, annotation_index, annotation_id}`
  - Handle annotations with no source location: fall back to selector in URI

- [ ] **D2.2** Modify `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`
  - Remove `extract_selected_component/1`, `extract_selected_component_screenshot/1`
  - Add `extract_annotations/1`:
    - Find blocks where `_meta["annotation"] == true`
    - Group with screenshot blocks by `annotation_id`
    - Return list of annotation structs: `%{id, file, line, column, component_name, component_props, parent, comment, tag_name, css_classes, nearby_text, screenshot}`
  - Replace `append_component_location/2` + `append_screenshot/2` with `append_annotations/2`:
    - Generates `[Annotated Elements]` section with per-annotation details
    - Appends screenshot image content parts
  - Update `UserMessage.new/1` to call `extract_annotations/1`
  - Update `to_llm_message/1` to call `append_annotations/2`
  - Update `has_selected_component?` → `has_annotations?` (checks if any interaction has non-empty annotations)

- [ ] **D2.3** Modify `apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex`
  - Replace `selected_component` / `selected_component_screenshot` fields with `annotations` list in UserMessage schema
  - Each annotation: `%{id, file, line, column, component_name, component_props, parent, comment, tag_name, css_classes, nearby_text, screenshot}`

- [ ] **D2.4** Modify `apps/frontman_server/lib/frontman_server/agents/prompts.ex`
  - Remove `selected_component_guidance/0`
  - Add `annotation_guidance/0`:
    - Instructions for handling annotated elements (single or multiple)
    - Address each annotation's comment
    - Read exact file, don't explore
    - Use CSS classes and nearby text for disambiguation

- [ ] **D2.5** Modify `apps/frontman_server/lib/frontman_server/agents.ex`
  - Replace `has_selected_component?` with `has_annotations?`
  - Pass `has_annotations: true/false` to `RootAgent.new()` and `Prompts.build()`

- [ ] **D2.6** Modify `apps/frontman_server/lib/frontman_server/agents/root_agent.ex`
  - Replace `has_selected_component` field with `has_annotations`

- [ ] **D2.7** Modify `apps/frontman_server/lib/frontman_server/tasks.ex`
  - Replace `has_selected_component?/2` with `has_annotations?/2`

- [ ] **D2.8** Remove `SelectedElement` module from `Client__Task__Types.res`
  - Remove the entire `SelectedElement` module definition
  - Remove any remaining references

### How to test

**Manual**:
1. Select an element, send a message
2. Add `IO.inspect(annotations, label: "ANNOTATIONS")` in `extract_annotations/1` (temporary)
3. Verify server receives annotations in new format with correct fields
4. Verify agent still receives file/line/column context and acts correctly
5. Verify screenshots still appear in LLM context (check agent response references visual details)
6. Remove the IO.inspect

**Automated**:
- Client: Update `Client__State__Types.test.res` — test `taskToContentBlocks` produces new annotation block format
- Server: ExUnit tests for `extract_annotations/1` and `append_annotations/2`
- Build succeeds with no errors

---

## D3: Enhanced element data

**Status**: `pending`

**Goal**: Augment annotations with additional context from Agentation's approach. The agent
gets richer information per annotation: CSS classes, nearby text, bounding box.

### Tasks

- [ ] **D3.1** Modify `FetchAnnotationDetails` effect handler in `Client__Task__Reducer.res`
  - Add to the parallel operations:
    - CSS classes: `element.className` → `cssClasses`
    - Nearby text: `element.textContent` + sibling textContent, truncated to ~200 chars → `nearbyText`
    - Bounding box: `element.getBoundingClientRect()` → `boundingBox`
  - Include these in `AnnotationDetailsResolved` dispatch

- [ ] **D3.2** Update `taskToContentBlocks` in `Client__Task__Types.res`
  - Include `css_classes`, `nearby_text`, `bounding_box` in annotation `_meta`

- [ ] **D3.3** Update server `extract_annotations/1` in `interaction.ex`
  - Read `css_classes`, `nearby_text` from `_meta`

- [ ] **D3.4** Update `append_annotations/2` in `interaction.ex`
  - Include `CSS Classes:` and `Nearby Text:` lines in the `[Annotated Elements]` LLM message section

### How to test

**Manual**:
1. Select an element with CSS classes (e.g., a styled button)
2. Send a message
3. Check server logs (IO.inspect) to verify:
   - `css_classes` is populated (e.g., `"btn btn-primary"`)
   - `nearby_text` has surrounding text
   - `tag_name` is present
4. Verify the LLM message includes the new fields
5. Test: "change the btn-primary class color" — agent should understand the CSS class reference

**Automated**:
- Update client content block tests for new fields
- Update server ExUnit tests for extraction and LLM message formatting

---

## D4: Markers + Toolbar controls + Batch mode UI

**Status**: `pending`

**Goal**: Port the visual UX from Agentation. Multiple annotations with numbered markers.
Annotation controls in the browser toolbar. Comment popup for batch mode.

### Tasks

- [ ] **D4.1** Create `libs/client/src/webpreview/Client__WebPreview__AnnotationControls.res`
  - Rendered inline in `Nav.Navigation`, replacing `SelectElement` button
  - Mode toggle: cycles Off → Quick → Batch (segmented control or dropdown)
    - Off: default cursor icon
    - Quick: cursor-click icon (current)
    - Batch: layers/multi-select icon
  - Annotation count badge (visible when count > 0)
  - Clear button (visible when annotations exist)

- [ ] **D4.2** Modify `libs/client/src/webpreview/Client__WebPreview.res`
  - Remove inline `SelectElement` module
  - Render `AnnotationControls` in `Nav.Navigation` where SelectElement was

- [ ] **D4.3** Create `libs/client/src/webpreview/Client__WebPreview__AnnotationMarkers.res`
  - Rendered in Stage overlay
  - For each annotation: numbered circle marker positioned over the element
  - Position computed from iframe offset + annotation bounding box
  - Re-positions on scroll and DOM mutations (reuse pattern from ClickedElement)
  - Click on marker → select/highlight that annotation
  - Visual style: colored numbered circles (inspired by Agentation)

- [ ] **D4.4** Create `libs/client/src/webpreview/Client__WebPreview__AnnotationPopup.res`
  - Rendered in Stage overlay when `pendingAnnotation` is Some
  - Positioned near the clicked element
  - Contains: element info header (tag + component name), comment text input, Confirm/Cancel buttons
  - On confirm: dispatches `ConfirmAnnotation({id, comment})`
  - On cancel: dispatches `CancelPendingAnnotation`
  - Escape key dismisses

- [ ] **D4.5** Modify `libs/client/src/state/Client__Task__Reducer.res` — Batch mode logic
  - Add actions: `ConfirmAnnotation({id, comment})`, `CancelPendingAnnotation`, `UpdateAnnotationComment({id, comment})`, `SetEditingAnnotation(option<string>)`
  - `AddAnnotation` in Batch mode: does NOT clear existing annotations, adds to the array
  - `AddAnnotation` in Quick mode: clears existing annotations first (max 1), no popup needed (auto-confirm with empty comment)

- [ ] **D4.6** Modify `libs/client/src/webpreview/Client__WebPreview__Stage.res`
  - Quick mode click: create annotation immediately (no popup)
  - Batch mode click: create pending annotation → show popup
  - Render `AnnotationMarkers` for all annotations
  - Remove rendering of `ClickedElement` (replaced by markers)

- [ ] **D4.7** Refactor `libs/client/src/Client__SelectedElementDisplay.res` → annotation list
  - Show all annotations: number, component/tag name, comment snippet, remove button
  - Click on annotation → scroll/highlight in preview
  - "Clear all" action at bottom
  - In Quick mode (1 annotation): similar to current but with new model

- [ ] **D4.8** Remove `libs/client/src/webpreview/Client__WebPreview__ClickedElement.res`
  - Replaced by AnnotationMarkers

### How to test

**Manual (Quick mode)**:
1. Toggle to Quick mode in toolbar controls
2. Click element — single numbered marker "1" appears
3. Element info shows in chatbox annotation list
4. Click different element — marker moves, old one removed
5. Send message — works as before

**Manual (Batch mode)**:
1. Toggle to Batch mode
2. Click element 1 → popup appears → type "fix hover color" → confirm
3. Marker "1" appears on element 1
4. Click element 2 → popup → type "make this larger" → confirm
5. Marker "2" appears on element 2
6. Chatbox shows list of 2 annotations with comments
7. Send message — verify:
   - Server receives 2 annotations with respective comments
   - Agent addresses both annotations
   - Agent receives 2 screenshots

**Manual (annotation management)**:
1. In Batch mode, create 3 annotations
2. Remove annotation 2 from the list — marker disappears, markers renumber to 1,2
3. Clear all — all markers and list items removed

---

## D5: Drag selection + Multi-select + Animation freeze

**Status**: `pending`

**Goal**: Port remaining Agentation power-user UX features.

### Tasks

- [ ] **D5.1** Drag selection (Batch mode only)
  - In `Client__WebPreview__Stage.res`: detect cmd+shift+drag
  - Draw rectangle overlay during drag
  - On release: find elements within rectangle (port Agentation's algorithm: sample points, query meaningful tags, overlap check, semantic filtering)
  - Create pending annotation for the group → show popup for comment
  - Annotation marked with `isMultiSelect: true` (add field to `Annotation.t`)

- [ ] **D5.2** Multi-select via cmd+shift+click (Batch mode only)
  - cmd+shift+click toggles elements into a pending group
  - Visual: temporary highlight on each selected element
  - Click without modifiers → popup for combined comment
  - Creates a single grouped annotation

- [ ] **D5.3** Animation freeze
  - Add freeze toggle button to `AnnotationControls`
  - On activate: postMessage to iframe to inject CSS:
    `* { animation-play-state: paused !important; transition: none !important; }`
  - Also pause `<video>` and animated `<img>` elements
  - On deactivate: remove injected CSS, resume videos
  - Requires a small script injected into the iframe to handle the postMessage

- [ ] **D5.4** Enhanced hover tooltip
  - Modify `Client__WebPreview__HoveredElement.res`
  - Show tag name + component name (if source detection resolves quickly)
  - Position tooltip near the hover highlight

### How to test

**Manual (drag select)**:
1. In Batch mode, hold cmd+shift and drag over a section
2. Verify: blue rectangle during drag, elements in area highlighted
3. On release: popup appears with count of selected elements
4. Confirm → grouped annotation with marker appears

**Manual (multi-select)**:
1. In Batch mode, cmd+shift+click on 3 elements
2. Each gets a temporary highlight
3. Click without modifiers → popup for the group
4. Confirm → single annotation

**Manual (freeze)**:
1. Navigate to a page with CSS animations
2. Click freeze button — animations stop
3. Click again — animations resume

**Manual (hover)**:
1. Enter selection mode, hover over elements
2. Verify tooltip shows "BUTTON" or "Button (src/components/Button.tsx)"

---

## D6: Cleanup + Polish

**Status**: `pending`

**Goal**: Remove dead code, ensure all tests pass, clean up temporary scaffolding.

### Tasks

- [ ] **D6.1** Remove dead files
  - `Client__WebPreview__ClickedElement.res` (if not already removed in D4)

- [ ] **D6.2** Remove dead code
  - `SelectedElement` module from `Client__Task__Types.res` (if not already removed in D2)
  - Old `selectedElementToContentBlock` / `selectedElementScreenshotToContentBlock`
  - Navigate-to-parent/child logic
  - Old `selected_component` paths in server code
  - Any unused imports

- [ ] **D6.3** Update Storybook stories
  - Any stories referencing old `SelectedElement` types
  - Add stories for new components: AnnotationControls, AnnotationMarkers, AnnotationPopup

- [ ] **D6.4** Update state snapshot serialization
  - Ensure `Client__StateSnapshot.res` handles annotations correctly for Storybook fixtures

- [ ] **D6.5** Final test pass
  - All ReScript compiler warnings resolved
  - All existing tests updated and passing
  - All new tests passing

### How to test

**Automated**:
- `make build` succeeds with no warnings
- All tests pass
- Storybook compiles and renders

**Manual**:
- Full walkthrough: Quick mode → select → send → agent acts
- Full walkthrough: Batch mode → annotate 3 elements → send → agent addresses all 3
- Verify no console errors, no broken UI states

---

## Architecture Reference

### Data flow

```
User clicks element in iframe
        │
        ▼
Client__WebPreview__Stage (click handler)
        │ dispatches AddAnnotation
        ▼
Client__Task__Reducer
        │ creates annotation, fires FetchAnnotationDetails effect
        ▼
FetchAnnotationDetails effect (parallel):
  ├─ @medv/finder → CSS selector
  ├─ @zumer/snapdom → screenshot (base64 JPEG)
  ├─ dom-element-to-component-source → SourceLocation
  │   └─ POST /frontman/resolve-source-location → relative path
  ├─ element.className → cssClasses
  ├─ element.textContent + siblings → nearbyText
  └─ element.getBoundingClientRect() → boundingBox
        │ dispatches AnnotationDetailsResolved
        ▼
Annotation stored in task state
        │ user sends message
        ▼
taskToContentBlocks (Client__Task__Types.res)
  │ per annotation:
  │   Block 1: resource with _meta {annotation: true, file, line, ...}
  │   Block 2: screenshot blob with _meta {annotation_screenshot: true}
        │
        ▼ ACP session/prompt via Phoenix channel
        │
Server: TaskChannel → Tasks.add_user_message()
        │
        ▼
interaction.ex: extract_annotations(content_blocks)
  → list of %{id, file, line, column, component_name, comment, ...}
        │
        ▼
to_llm_message: append_annotations()
  → "[Annotated Elements]\n### 1. 'Fix hover'\nFile: src/Button.tsx:42:5\n..."
  → image content parts for screenshots
        │
        ▼
Swarm agent executes with rich annotation context
```

### File inventory

**New files**:
| File | Purpose |
|------|---------|
| `libs/client/src/Client__Annotation__Types.res` | Annotation type definitions |
| `libs/client/src/webpreview/Client__WebPreview__AnnotationControls.res` | Toolbar controls (D4) |
| `libs/client/src/webpreview/Client__WebPreview__AnnotationMarkers.res` | Numbered markers overlay (D4) |
| `libs/client/src/webpreview/Client__WebPreview__AnnotationPopup.res` | Comment input popup (D4) |

**Modified files (client)**:
| File | Deliverable |
|------|-------------|
| `libs/client/src/state/Client__Task__Types.res` | D1, D2, D3 |
| `libs/client/src/state/Client__Task__Reducer.res` | D1, D3, D4, D5 |
| `libs/client/src/state/Client__State.res` | D1 |
| `libs/client/src/state/Client__State__StateReducer.res` | D1 |
| `libs/client/src/webpreview/Client__WebPreview.res` | D1, D4 |
| `libs/client/src/webpreview/Client__WebPreview__Stage.res` | D1, D4, D5 |
| `libs/client/src/webpreview/Client__WebPreview__HoveredElement.res` | D5 |
| `libs/client/src/Client__SelectedElementDisplay.res` | D1, D4 |
| `libs/client/src/Client__Chatbox.res` | D1 |
| `libs/client/src/state/Client__StateSnapshot.res` | D1, D6 |
| `libs/client/test/Client__State__Types.test.res` | D1, D2, D3 |

**Modified files (server)**:
| File | Deliverable |
|------|-------------|
| `apps/frontman_server/lib/frontman_server/tasks/interaction.ex` | D2, D3 |
| `apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex` | D2 |
| `apps/frontman_server/lib/frontman_server/agents/prompts.ex` | D2 |
| `apps/frontman_server/lib/frontman_server/agents.ex` | D2 |
| `apps/frontman_server/lib/frontman_server/agents/root_agent.ex` | D2 |
| `apps/frontman_server/lib/frontman_server/tasks.ex` | D2 |

**Removed files**:
| File | Deliverable |
|------|-------------|
| `libs/client/src/webpreview/Client__WebPreview__ClickedElement.res` | D4/D6 |
