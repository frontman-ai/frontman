# Framework-Conditional Browser Tool Registration

**Issue:** #786
**Unblocks:** #782 (Astro dev toolbar audit browser tool)
**Date:** 2026-04-05

## Problem

All browser tools in `libs/client/` are registered unconditionally via `Client__ToolRegistry.coreBrowserTools()` in `Client__FrontmanProvider.res`. There is no mechanism to register browser tools conditionally based on the active framework (Astro, Next.js, Vite, WordPress).

The server-side already solves this with per-framework tool registries (`FrontmanAstro__ToolRegistry`, `FrontmanNextjs__ToolRegistry`). The client side lacks an equivalent.

## Scope

Infrastructure only. No actual framework-specific browser tool implementations. The Astro browser package exports an empty tool array; issue #782 will add the first real tool (`GetAstroAudit`).

## Design

### Approach: Framework-specific browser tool packages

Each framework that needs browser-specific tools gets a lightweight sibling package (e.g., `libs/frontman-astro-browser/`). The client imports these packages and switches on the runtime framework ID to compose the final tool registry.

Only Astro gets a package now. Other frameworks get packages when they need browser-specific tools.

### New package: `libs/frontman-astro-browser/`

```
libs/frontman-astro-browser/
  package.json
  rescript.json
  Makefile
  src/
    FrontmanAstroBrowser__Registry.res
```

**Dependencies:** `@frontman-ai/frontman-protocol` (for `BrowserTool` module type), `sury`.

No dependency on `@frontman-ai/astro` (the server adapter) or `@frontman-ai/client`. This keeps the dependency graph clean:

```
@frontman-ai/frontman-protocol   (BrowserTool module type)
       ^                    ^
       |                    |
@frontman-ai/astro-browser  |   (framework browser tools)
       ^                    |
       |                    |
@frontman-ai/client --------+   (imports browser packages, switches on framework)
```

**`FrontmanAstroBrowser__Registry.res`:**

```rescript
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

type tool = module(Tool.BrowserTool)

let browserTools: array<tool> = []
```

### Modified: `Client__ToolRegistry.res`

Add a `forFramework` function that composes the core browser tools with framework-specific tools:

```rescript
let forFramework = (framework: Client__RuntimeConfig.frameworkId): t => {
  let base = coreBrowserTools()
  switch framework {
  | Astro =>
    base->addTools(
      FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry.browserTools,
    )
  | Nextjs | Vite | Wordpress => base
  }
}
```

The `tool` type in both `Client__ToolRegistry` and `FrontmanAstroBrowser__Registry` is `module(Tool.BrowserTool)` via the same protocol module — structurally identical.

### Modified: `Client__FrontmanProvider.res`

In the `useEffect0` initialization (line 211), replace:

```rescript
// Before
let toolRegistry = Client__ToolRegistry.coreBrowserTools()

// After
let toolRegistry = Client__ToolRegistry.forFramework(runtimeConfig.framework)
```

`runtimeConfig` is already read on line 205, so `framework` is available.

### Modified: `libs/client/rescript.json` and `package.json`

Add `@frontman-ai/astro-browser` as a dependency so the client can import the Astro browser registry.

### Modified: root `package.json`

Add `libs/frontman-astro-browser` to the workspaces array.

## Testing

### Existing tests (must stay green)

`libs/client/test/Client__ToolRegistry.test.res` — all existing tests for `make`, `coreBrowserTools`, `addTools`, `merge`, `getToolByName` remain unchanged.

### New tests in `Client__ToolRegistry.test.res`

```rescript
describe("forFramework", _t => {
  test("Astro returns core browser tools (empty framework tools for now)", t => {
    let registry = ToolRegistry.forFramework(Astro)
    // Same count as coreBrowserTools since Astro array is empty
    t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
  })

  test("Nextjs returns core browser tools", t => {
    let registry = ToolRegistry.forFramework(Nextjs)
    t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
  })

  test("Vite returns core browser tools", t => {
    let registry = ToolRegistry.forFramework(Vite)
    t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
  })

  test("Wordpress returns core browser tools", t => {
    let registry = ToolRegistry.forFramework(Wordpress)
    t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
  })
})
```

### New test in `libs/frontman-astro-browser/`

```rescript
test("browserTools is a valid empty array", t => {
  let tools = FrontmanAstroBrowser__Registry.browserTools
  t->expect(tools->Array.length)->Expect.toBe(0)
})
```

## File inventory

| Action | Path | Description |
|--------|------|-------------|
| NEW | `libs/frontman-astro-browser/package.json` | Package definition |
| NEW | `libs/frontman-astro-browser/rescript.json` | ReScript config |
| NEW | `libs/frontman-astro-browser/Makefile` | Standard Makefile |
| NEW | `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Registry.res` | Empty browser tools array |
| EDIT | `libs/client/src/Client__ToolRegistry.res` | Add `forFramework` function |
| EDIT | `libs/client/src/Client__FrontmanProvider.res` | Use `forFramework` instead of `coreBrowserTools` |
| EDIT | `libs/client/rescript.json` | Add `@frontman-ai/astro-browser` dependency |
| EDIT | `libs/client/package.json` | Add `@frontman-ai/astro-browser` dependency |
| EDIT | `package.json` (root) | Add workspace entry |
| EDIT | `libs/client/test/Client__ToolRegistry.test.res` | Add `forFramework` tests |
| NEW | `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res` | Registry test |

## Future extension

When #782 adds `GetAstroAudit`:
1. Create `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Tool__GetAstroAudit.res`
2. Add `module(FrontmanAstroBrowser__Tool__GetAstroAudit)` to the `browserTools` array
3. No changes needed in client — the `forFramework` switch already wires it in

When another framework needs browser tools (e.g., Next.js):
1. Create `libs/frontman-nextjs-browser/` following the same pattern
2. Add it as a client dependency
3. Add a `Nextjs` case to `forFramework`
