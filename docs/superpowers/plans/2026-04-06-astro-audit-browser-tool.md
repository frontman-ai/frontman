# Astro Audit Browser Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `get_astro_audit` browser tool that reads Astro's dev toolbar audit results and exposes them to the Frontman agent.

**Architecture:** Factory pattern (same as `GetResolvedRoutes`) — tool closes over a `getPreviewDoc` callback at construction time. Shared `previewContext` type in `frontman-protocol` bridges the dependency gap between `libs/client` and `libs/frontman-astro-browser`. Shadow DOM traversal uses typed externals for Astro custom element APIs.

**Tech Stack:** ReScript 12, `@rescript/webapi`, Sury schemas, vitest

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `libs/frontman-protocol/src/FrontmanProtocol__Tool.res` | Add `previewContext` type + `getAstroAudit` tool name |
| Modify | `libs/frontman-astro-browser/rescript.json` | Add `@rescript/webapi` to dependencies |
| Modify | `libs/client/src/tools/Client__Tool__ElementResolver.res` | Use shared `previewContext`, export `getPreviewDoc` |
| Modify | `libs/client/src/Client__ToolRegistry.res` | Update `forFramework` to pass `getPreviewDoc` to Astro registry |
| Create | `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Tool__GetAstroAudit.res` | Tool implementation (factory) |
| Modify | `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Registry.res` | Change to factory function |
| Modify | `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res` | Update for factory signature |
| Create | `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Tool__GetAstroAudit.test.res` | Tool unit tests |

---

## Task 1: Add shared `previewContext` type and tool name to `frontman-protocol`

**Files:**
- Modify: `libs/frontman-protocol/src/FrontmanProtocol__Tool.res:43-44` (after ToolNames), `:22-43` (ToolNames block)

- [ ] **Step 1: Add `previewContext` type**

Add after the `executionMode` type (line 18) and before `ToolNames`:

```rescript
// Context for browser tools that access the preview iframe
type previewContext = {
  doc: WebAPI.DOMAPI.document,
  win: WebAPI.DOMAPI.window,
}
```

- [ ] **Step 2: Add `getAstroAudit` to `ToolNames`**

Add to the browser tools section of `ToolNames` (after `question` on line 42):

```rescript
  let getAstroAudit = "get_astro_audit"
```

- [ ] **Step 3: Build frontman-protocol to verify**

Run: `cd libs/frontman-protocol && yarn rescript build`
Expected: Build succeeds with no errors.

- [ ] **Step 4: Commit**

```bash
git add libs/frontman-protocol/src/FrontmanProtocol__Tool.res
git commit -m "feat(protocol): add previewContext type and getAstroAudit tool name"
```

---

## Task 2: Update `ElementResolver` to use shared type and export `getPreviewDoc`

**Files:**
- Modify: `libs/client/src/tools/Client__Tool__ElementResolver.res:14-35`

- [ ] **Step 1: Replace local `previewContext` with shared type**

Replace lines 14-35 with:

```rescript
// ============================================================================
// Preview frame access
// ============================================================================

// Re-export from protocol for consumers that import from ElementResolver
type previewContext = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.previewContext

// Get preview iframe context if available. Used by forFramework to inject
// into framework-specific browser tool factories.
let getPreviewDoc = (): option<previewContext> => {
  let state = StateStore.getState(Client__State__Store.store)
  let previewFrame = Client__State__StateReducer.Selectors.previewFrame(state)
  switch (previewFrame.contentDocument, previewFrame.contentWindow) {
  | (Some(doc), Some(win)) => Some({doc, win})
  | _ => None
  }
}

// Eliminates repeated getState -> previewFrame -> switch contentDocument boilerplate.
// Calls `fn` with the preview iframe's document and window when available,
// or `onUnavailable` when the preview frame isn't ready.
let withPreviewDoc = (
  ~onUnavailable: unit => 'a,
  fn: previewContext => 'a,
): 'a =>
  switch getPreviewDoc() {
  | Some(ctx) => fn(ctx)
  | None => onUnavailable()
  }
```

- [ ] **Step 2: Build client to verify no type breakage**

Run: `cd libs/client && yarn rescript build`
Expected: Build succeeds. All existing tools that use `withPreviewDoc` and `previewContext` continue to compile because the type shape is identical.

- [ ] **Step 3: Run client tests**

Run: `cd libs/client && yarn vitest run`
Expected: All existing tests pass.

- [ ] **Step 4: Commit**

```bash
git add libs/client/src/tools/Client__Tool__ElementResolver.res
git commit -m "refactor(client): use shared previewContext type, export getPreviewDoc"
```

---

## Task 3: Add `@rescript/webapi` dependency to `frontman-astro-browser`

**Files:**
- Modify: `libs/frontman-astro-browser/rescript.json`

- [ ] **Step 1: Add `@rescript/webapi` to rescript.json dependencies**

The `previewContext` type references `WebAPI.DOMAPI.document` and `WebAPI.DOMAPI.window`. The package already has `@rescript/webapi` in `package.json` devDependencies but it's missing from `rescript.json` dependencies.

Change the dependencies array from:

```json
"dependencies": [
  "@frontman-ai/frontman-protocol",
  "sury"
]
```

to:

```json
"dependencies": [
  "@frontman-ai/frontman-protocol",
  "@rescript/webapi",
  "sury"
]
```

- [ ] **Step 2: Build to verify**

Run: `cd libs/frontman-astro-browser && yarn rescript build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add libs/frontman-astro-browser/rescript.json
git commit -m "chore(astro-browser): add @rescript/webapi to rescript dependencies"
```

---

## Task 4: Implement `GetAstroAudit` tool

**Files:**
- Create: `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Tool__GetAstroAudit.res`
- Create: `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Tool__GetAstroAudit.test.res`

- [ ] **Step 1: Write the failing test**

Create `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Tool__GetAstroAudit.test.res`:

```rescript
open Vitest

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let makeTool = (~getPreviewDoc) =>
  FrontmanAiAstroBrowser.FrontmanAstroBrowser__Tool__GetAstroAudit.make(~getPreviewDoc)

let unpackName = (toolModule: module(Tool.BrowserTool)): string => {
  module T = unpack(toolModule)
  T.name
}

let unpackExecute = (
  toolModule: module(Tool.BrowserTool),
): (
  FrontmanAiAstroBrowser.FrontmanAstroBrowser__Tool__GetAstroAudit.input,
  ~taskId: string,
  ~toolCallId: string,
) => promise<Tool.toolResult<FrontmanAiAstroBrowser.FrontmanAstroBrowser__Tool__GetAstroAudit.output>> => {
  module T = unpack(toolModule)
  (input, ~taskId, ~toolCallId) => T.execute(Obj.magic(input), ~taskId, ~toolCallId)->Promise.thenResolve(r => Obj.magic(r))
}

describe("FrontmanAstroBrowser__Tool__GetAstroAudit", _t => {
  test("tool name is get_astro_audit", t => {
    let tool = makeTool(~getPreviewDoc=() => None)
    t->expect(unpackName(tool))->Expect.toBe("get_astro_audit")
  })

  testAsync("returns message when preview is unavailable", async t => {
    let tool = makeTool(~getPreviewDoc=() => None)
    let execute = unpackExecute(tool)
    let result = await execute({}, ~taskId="t1", ~toolCallId="tc1")
    switch result {
    | Ok({audits, message}) => {
        t->expect(audits->Array.length)->Expect.toBe(0)
        t->expect(message)->Expect.toEqual(Some("Preview iframe is not available"))
      }
    | Error(e) => t->expect(e)->Expect.toBe("should not error")
    }
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd libs/frontman-astro-browser && yarn rescript build && yarn vitest run`
Expected: Compilation fails — `FrontmanAstroBrowser__Tool__GetAstroAudit` module not found.

- [ ] **Step 3: Write the tool implementation**

Create `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Tool__GetAstroAudit.res`:

```rescript
// Browser tool that reads Astro's dev toolbar audit results.
//
// The Astro dev toolbar runs ~26 accessibility and performance checks.
// This tool traverses the toolbar's shadow DOM to extract those results
// and make them available to the agent.
//
// Uses factory pattern: make(~getPreviewDoc) => module(BrowserTool).
// The BrowserTool interface only passes (input, ~taskId, ~toolCallId) to
// execute, so there's no way to thread the preview doc accessor through
// the standard interface. The factory closes over getPreviewDoc at
// construction time.

S.enableJson()

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let name = Tool.ToolNames.getAstroAudit
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous

let description = `Read accessibility and performance audit results from Astro's dev toolbar.

Returns the current audit findings without parameters. Each entry includes
the rule code, category (a11y or performance), human-readable title/message/description,
and information about the offending element.

Returns an empty array with a message if:
- The preview iframe is not available
- The Astro dev toolbar is not present on the page
- The audit has not run yet`

@schema
type input = {placeholder?: bool}

@schema
type elementInfo = {
  tagName: string,
  selector: string,
  textSnippet: string,
}

@schema
type auditEntry = {
  code: string,
  category: string,
  title: string,
  message: string,
  description: string,
  element: elementInfo,
}

@schema
type output = {
  audits: array<auditEntry>,
  message: option<string>,
}

let emptyResult = (~message): Tool.toolResult<output> =>
  Ok({audits: [], message: Some(message)})

// Typed externals for Astro dev toolbar custom element APIs.
// The audit data lives behind two shadow DOM layers, all mode: "open".

// Resolve a rule field that can be string | (Element) => string.
// Uses Js.typeof to check at runtime and calls if function.
@val external jsTypeof: 'a => string = "typeof"

let resolveRuleField = (field: 'a, element: WebAPI.DOMAPI.element): string => {
  switch jsTypeof(field) {
  | "function" =>
    let fn: WebAPI.DOMAPI.element => string = Obj.magic(field)
    fn(element)
  | _ => Obj.magic(field)
  }
}

// Get .audits property from the audit window custom element.
// Returns array of {auditedElement, rule} objects.
type auditRule = {
  code: string,
  title: unknown,
  message: unknown,
  description: unknown,
}

type rawAudit = {
  auditedElement: WebAPI.DOMAPI.element,
  rule: auditRule,
}

@get external getAudits: WebAPI.DOMAPI.element => Nullable.t<array<rawAudit>> = "audits"

let categoryFromCode = (code: string): string =>
  switch code->String.startsWith("perf-") {
  | true => "performance"
  | false => "a11y"
  }

let elementSelector = (el: WebAPI.DOMAPI.element): string => {
  let tag = el.tagName->String.toLowerCase
  let className =
    el->WebAPI.Element.getAttribute("class")->Null.toOption->Option.getOr("")->String.trim
  switch className {
  | "" => tag
  | cls => `${tag}.${cls->String.split(" ")->Array.join(".")}`
  }
}

let elementTextSnippet = (el: WebAPI.DOMAPI.element): string => {
  let text =
    (el :> WebAPI.DOMAPI.node)
    ->WebAPI.Node.textContent
    ->Null.toOption
    ->Option.getOr("")
    ->String.trim
  switch text->String.length > 80 {
  | true => text->String.slice(~start=0, ~end=80) ++ "..."
  | false => text
  }
}

let convertAudit = (raw: rawAudit): auditEntry => {
  let el = raw.auditedElement
  {
    code: raw.rule.code,
    category: categoryFromCode(raw.rule.code),
    title: resolveRuleField(raw.rule.title, el),
    message: resolveRuleField(raw.rule.message, el),
    description: resolveRuleField(raw.rule.description, el),
    element: {
      tagName: el.tagName->String.toLowerCase,
      selector: elementSelector(el),
      textSnippet: elementTextSnippet(el),
    },
  }
}

let extractAudits = (doc: WebAPI.DOMAPI.document): Tool.toolResult<output> => {
  // Layer 1: find astro-dev-toolbar
  let toolbar = doc->WebAPI.Document.querySelector("astro-dev-toolbar")->Null.toOption
  switch toolbar {
  | None => emptyResult(~message="Astro dev toolbar not found. Is this an Astro dev page?")
  | Some(toolbar) =>
    // Layer 2: toolbar's shadow root → audit app canvas
    let toolbarShadow = toolbar.shadowRoot->Null.toOption
    switch toolbarShadow {
    | None => emptyResult(~message="Astro dev toolbar shadow root not accessible")
    | Some(shadowRoot) =>
      let auditCanvas =
        shadowRoot
        ->WebAPI.ShadowRoot.querySelector(
          `astro-dev-toolbar-app-canvas[data-app-id="astro:audit"]`,
        )
        ->Null.toOption
      switch auditCanvas {
      | None => emptyResult(~message="Astro audit app not found in dev toolbar")
      | Some(canvas) =>
        // Layer 3: audit canvas shadow root → audit window
        let canvasShadow = canvas.shadowRoot->Null.toOption
        switch canvasShadow {
        | None => emptyResult(~message="Astro audit canvas shadow root not accessible")
        | Some(canvasShadowRoot) =>
          let auditWindow =
            canvasShadowRoot
            ->WebAPI.ShadowRoot.querySelector("astro-dev-toolbar-audit-window")
            ->Null.toOption
          switch auditWindow {
          | None => emptyResult(~message="Astro audit window element not found")
          | Some(auditEl) =>
            let rawAudits = getAudits(auditEl)->Nullable.toOption->Option.getOr([])
            switch rawAudits->Array.length {
            | 0 =>
              emptyResult(~message="No audit results found. The audit may not have run yet.")
            | _ => Ok({audits: rawAudits->Array.map(convertAudit), message: None})
            }
          }
        }
      }
    }
  }
}

let make = (
  ~getPreviewDoc: unit => option<Tool.previewContext>,
): module(Tool.BrowserTool) => {
  module(
    {
      let name = name
      let visibleToAgent = visibleToAgent
      let executionMode = executionMode
      let description = description
      type input = input
      type output = output
      let inputSchema = inputSchema
      let outputSchema = outputSchema
      let execute = async (_input, ~taskId as _, ~toolCallId as _) =>
        switch getPreviewDoc() {
        | None => emptyResult(~message="Preview iframe is not available")
        | Some({doc}) => extractAudits(doc)
        }
    }
  )
}
```

- [ ] **Step 4: Build and run tests**

Run: `cd libs/frontman-astro-browser && yarn rescript build && yarn vitest run`
Expected: Both tests pass — name check and preview-unavailable case.

- [ ] **Step 5: Commit**

```bash
git add libs/frontman-astro-browser/src/FrontmanAstroBrowser__Tool__GetAstroAudit.res \
       libs/frontman-astro-browser/test/FrontmanAstroBrowser__Tool__GetAstroAudit.test.res
git commit -m "feat(astro-browser): add get_astro_audit browser tool"
```

---

## Task 5: Update registry to factory function

**Files:**
- Modify: `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Registry.res`
- Modify: `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res`

- [ ] **Step 1: Update the test**

Replace `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res` with:

```rescript
open Vitest

module Registry = FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let unpackName = (toolModule: module(Tool.BrowserTool)): string => {
  module T = unpack(toolModule)
  T.name
}

describe("FrontmanAstroBrowser__Registry", _t => {
  test("browserTools returns one tool", t => {
    let tools = Registry.browserTools(~getPreviewDoc=() => None)
    t->expect(tools->Array.length)->Expect.toBe(1)
  })

  test("first tool is get_astro_audit", t => {
    let tools = Registry.browserTools(~getPreviewDoc=() => None)
    let name = tools->Array.getUnsafe(0)->unpackName
    t->expect(name)->Expect.toBe("get_astro_audit")
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd libs/frontman-astro-browser && yarn rescript build && yarn vitest run`
Expected: Fails — `browserTools` is still a static array, not a function.

- [ ] **Step 3: Update the registry**

Replace `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Registry.res` with:

```rescript
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

type tool = module(Tool.BrowserTool)

let browserTools = (~getPreviewDoc: unit => option<Tool.previewContext>): array<tool> => [
  FrontmanAstroBrowser__Tool__GetAstroAudit.make(~getPreviewDoc),
]
```

- [ ] **Step 4: Build and run tests**

Run: `cd libs/frontman-astro-browser && yarn rescript build && yarn vitest run`
Expected: All 4 tests pass (2 registry + 2 tool).

- [ ] **Step 5: Commit**

```bash
git add libs/frontman-astro-browser/src/FrontmanAstroBrowser__Registry.res \
       libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res
git commit -m "feat(astro-browser): change browserTools to factory accepting getPreviewDoc"
```

---

## Task 6: Wire up `forFramework` in client registry

**Files:**
- Modify: `libs/client/src/Client__ToolRegistry.res:60-67`

- [ ] **Step 1: Update `forFramework` to pass `getPreviewDoc`**

Replace the `forFramework` function (lines 60-67) with:

```rescript
// Build a registry with core browser tools + framework-specific tools
let forFramework = (framework: Client__RuntimeConfig.frameworkId): t => {
  let base = coreBrowserTools()
  switch framework {
  | Astro =>
    let getPreviewDoc = Client__Tool__ElementResolver.getPreviewDoc
    base->addTools(FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry.browserTools(~getPreviewDoc))
  | Nextjs | Vite | Wordpress => base
  }
}
```

- [ ] **Step 2: Build client to verify**

Run: `cd libs/client && yarn rescript build`
Expected: Build succeeds. The `FrontmanProvider` already calls `forFramework(runtimeConfig.framework)` on line 223 — no changes needed there.

- [ ] **Step 3: Run client tests**

Run: `cd libs/client && yarn vitest run`
Expected: All existing tests pass.

- [ ] **Step 4: Commit**

```bash
git add libs/client/src/Client__ToolRegistry.res
git commit -m "feat(client): wire getPreviewDoc into Astro browser tool registry"
```

---

## Task 7: Add changeset

**Files:**
- Create: `.changeset/<generated-name>.md`

- [ ] **Step 1: Create changeset**

Run: `yarn changeset`

Select:
- `@frontman-ai/astro-browser`: minor
- `@frontman-ai/frontman-protocol`: minor
- `@frontman-ai/client`: patch

Summary: `Add get_astro_audit browser tool that reads Astro dev toolbar accessibility and performance audit results`

If `yarn changeset` is not interactive-friendly, create the file manually:

```bash
cat > .changeset/astro-audit-tool.md << 'EOF'
---
"@frontman-ai/astro-browser": minor
"@frontman-ai/frontman-protocol": minor
"@frontman-ai/client": patch
---

Add get_astro_audit browser tool that reads Astro dev toolbar accessibility and performance audit results
EOF
```

- [ ] **Step 2: Commit**

```bash
git add .changeset/astro-audit-tool.md
git commit -m "chore: add changeset for astro audit browser tool"
```
