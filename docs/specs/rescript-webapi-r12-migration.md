# Spec: ReScript 12 WebAPI Migration

## Objective

Use the newest official `@rescript/webapi` source that supports ReScript 12:
upstream commit `5e2d4d5db8257fea0fb3cc2dde5c4699d263a62f`. Keep ReScript
`12.3.0` and use compiler errors to migrate Frontman from local compatibility
facades to official flat `WebAPI.*` modules.

## Commands

- Install: `make install`
- Clean compile: `make clean && make rescript-build`
- Format: `make rescript-format`
- Package tests: each affected package's `make test`

## Project Structure

- `libs/experimental-rescript-webapi/`: pinned official source
- `libs/bindings/`: Frontman-only browser bindings
- `libs/client/`: main DOM consumer
- `libs/frontman-{protocol,core,client,vite,astro,nextjs}/`: shared and adapter consumers

## Code Style

Use official flat modules and typed conversions:

```rescript
let document = WebAPI.Window.current->WebAPI.Window.document
let element: WebAPI.Element.t = document->WebAPI.Document.createElement("div")
let node = element->WebAPI.Element.asNode
```

Do not recreate `DOMAPI`, `Global`, `FetchAPI`, or other removed facades.

## Testing Strategy

- Replace vendor source first and save initial compiler output.
- Fix compiler errors in dependency order: bindings, protocol, core, client,
  public client, then framework adapters.
- Compile after each error class and run each owning package's tests.
- Restore a local vendor operation only when an active typed call site requires
  it and official `5e2d4d5` lacks an equivalent.

## Boundaries

- Always keep ReScript and runtime at stable `12.3.0`.
- Always pin WebAPI to exact commit `5e2d4d5`.
- Never add alpha dependencies.
- Never use `%raw`, `Obj.magic`, or compatibility aliases only to silence the compiler.
- Preserve public behavior and package interfaces.

## Success Criteria

- Vendored source matches official `5e2d4d5`, except documented required patches.
- Update command is pinned to `5e2d4d5`, not floating `main`.
- No application source references removed compatibility facades.
- Clean workspace compile and affected package tests pass on ReScript `12.3.0`.
- Changeset documents the migration.

## Open Questions

None.

## Vendor Patch Manifest

Frontman keeps these narrow additions because active call sites require APIs absent
from `5e2d4d5`:

- Namespace: `"namespace": "WebAPI"` prevents module-name collisions in the workspace.
- DOM traversal: document body/canvas creation, fragment children, parent element,
  node type/text, iframe document/window, collection conversion, and nullable file access.
- Browser events: clipboard and drag event types, data transfer access, and nullable files.
- Files: typed `FileReader` construction, events, result access, and data URL reads.
- Test harness: `.res.mjs` runtime paths match ReScript `12.3.0` output.
- Package metadata: retain local `0.1.2`, use the workspace compiler catalog,
  constrain the peer dependency below ReScript 13, and omit docs-only tooling.

Frontman-specific React and checked DOM downcasts remain in
`libs/bindings/src/Bindings__WebAPI.res`, not the vendored package.
