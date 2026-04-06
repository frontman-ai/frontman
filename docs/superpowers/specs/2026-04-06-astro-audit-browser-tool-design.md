# Design: `get_astro_audit` Browser Tool

**Issue**: #782
**Date**: 2026-04-06

## Summary

Add a browser tool that reads Astro's built-in dev toolbar audit results (accessibility + performance) and exposes them to the Frontman agent. The tool lives in `libs/frontman-astro-browser` and is conditionally registered only for Astro projects.

## Architecture

### Dependency Injection via Factory Pattern

The tool needs access to the preview iframe's document to traverse the Astro dev toolbar's shadow DOM. The preview iframe reference lives in `libs/client`'s state store, but `frontman-astro-browser` cannot depend on `libs/client` (circular).

Solution: follow the existing factory pattern from `FrontmanAstro__Tool__GetResolvedRoutes` — the tool's `make` function closes over a `getPreviewDoc` callback provided at construction time.

### Shared `previewContext` Type

Define `previewContext` in `FrontmanProtocol__Tool` (alongside `BrowserTool`), so both `libs/client` and `libs/frontman-astro-browser` can reference it:

```rescript
type previewContext = {
  doc: WebAPI.DOMAPI.document,
  win: WebAPI.DOMAPI.window,
}
```

Update `Client__Tool__ElementResolver` to:
- Use the shared `previewContext` type instead of its own local definition
- Export a `getPreviewDoc: unit => option<previewContext>` function alongside the existing `withPreviewDoc`

### Tool Name

Add to `FrontmanProtocol__Tool.ToolNames`:
```rescript
let getAstroAudit = "get_astro_audit"
```

## Tool Implementation

**File**: `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Tool__GetAstroAudit.res`

### Factory

```rescript
let make = (~getPreviewDoc: unit => option<previewContext>): module(BrowserTool)
```

### Input

Empty — no parameters needed. The tool reads the current audit state from the DOM.

```rescript
@schema
type input = {placeholder?: bool}
```

### Output

```rescript
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
```

### Shadow DOM Traversal

The audit data lives behind two layers of shadow DOM:

```
doc.querySelector('astro-dev-toolbar')
  .shadowRoot
  .querySelector('astro-dev-toolbar-app-canvas[data-app-id="astro:audit"]')
  .shadowRoot
  .querySelector('astro-dev-toolbar-audit-window')
  .audits  // Array<{ auditedElement: HTMLElement, rule: AuditRule }>
```

All shadow roots use `mode: "open"`, so they are fully traversable.

Use typed externals for:
- `.audits` property on the custom `astro-dev-toolbar-audit-window` element
- Rule field resolution: `title`, `message`, `description` can each be `string | (Element) => string`. Use `Js.typeof` to check and call if function, return as-is if string.

### Category Inference

Derive from the audit rule code prefix:
- Codes starting with `"perf-"` → `"performance"`
- Everything else → `"a11y"`

### Element Info

Keep it simple — `tagName` from the audited element, class-based selector (`tagName.className`), and a truncated text snippet. No `@medv/finder` dependency to keep the package lightweight.

### Error Handling

All cases return `Ok` with empty audits and an explanatory `message` (not `Error`):
- Preview iframe not available → `"Preview iframe is not available"`
- `astro-dev-toolbar` element not found → `"Astro dev toolbar not found. Is this an Astro dev page?"`
- Audit window has empty `.audits` → `"No audit results found. The audit may not have run yet."`

## Registry Wiring

### `FrontmanAstroBrowser__Registry`

Changes from static array to factory function:

```rescript
let browserTools = (
  ~getPreviewDoc: unit => option<FrontmanProtocol__Tool.previewContext>,
): array<tool> => [
  FrontmanAstroBrowser__Tool__GetAstroAudit.make(~getPreviewDoc),
]
```

### `Client__ToolRegistry.forFramework`

The existing Astro branch constructs `getPreviewDoc` from the state store:

```rescript
| Astro =>
  let getPreviewDoc = () => {
    let state = StateStore.getState(Client__State__Store.store)
    let frame = Client__State__StateReducer.Selectors.previewFrame(state)
    switch (frame.contentDocument, frame.contentWindow) {
    | (Some(doc), Some(win)) => Some({FrontmanProtocol__Tool.doc, win})
    | _ => None
    }
  }
  base->addTools(
    FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry.browserTools(~getPreviewDoc)
  )
```

### Package Dependencies

`frontman-astro-browser` already depends on `@frontman-ai/frontman-protocol` and `@rescript/webapi`. No new dependencies needed.

`libs/client` already depends on `@frontman-ai/astro-browser` (via `forFramework` wiring). No changes needed.

## Testing

### Registry Test

Update existing `FrontmanAstroBrowser__Registry.test.res`:
- `browserTools(~getPreviewDoc=() => None)` returns array of length 1
- First tool has name `"get_astro_audit"`

### Tool Unit Tests

New file `FrontmanAstroBrowser__Tool__GetAstroAudit.test.res`:
- Preview unavailable: `getPreviewDoc` returns `None` → `Ok({audits: [], message: Some("Preview iframe is not available")})`
- Cannot test happy path without real Astro DOM — graceful degradation paths only

## Files Changed

1. `libs/frontman-protocol/src/FrontmanProtocol__Tool.res` — add `previewContext` type, add `getAstroAudit` to `ToolNames`
2. `libs/client/src/tools/Client__Tool__ElementResolver.res` — use shared `previewContext`, export `getPreviewDoc`
3. `libs/client/src/Client__ToolRegistry.res` — update `forFramework` Astro branch to pass `getPreviewDoc`
4. `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Tool__GetAstroAudit.res` — new tool (factory)
5. `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Registry.res` — change to factory function
6. `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res` — update for factory signature
7. `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Tool__GetAstroAudit.test.res` — new test file

## Not In Scope

- No server-side changes
- No toolbar websocket relay or persistent store
- No re-running audit rules — reads Astro's own results directly
- No `@medv/finder` in astro-browser package
