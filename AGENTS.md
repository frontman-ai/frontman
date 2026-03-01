# Agent Guidelines for Frontman


## Worktree Workflow

This repo uses git worktrees for parallel feature development with isolated Claude contexts.

**Create worktree:**
```bash
make worktree-create BRANCH=feature/my-feature
cd .worktrees/feature/my-feature
```

**Benefits:**
- Work on multiple features without branch switching
- Isolated Claude Code context per feature (separate history)
- Parallel dev servers on different ports
- Self-contained dependencies per worktree

**Management (short aliases):**
- `make wt` - **Dashboard** — shows all worktrees, pod status, URLs, and actions at a glance
- `make wt-new BRANCH=...` - Create containerized worktree
- `make wt-dev BRANCH=...` - Start dev servers (mprocs TUI)
- `make wt-stop BRANCH=...` - Pause (preserves data)
- `make wt-start BRANCH=...` - Resume paused worktree
- `make wt-sh BRANCH=...` - Shell into container
- `make wt-rm BRANCH=...` - Full cleanup (pod + volumes + worktree)
- `make wt-urls BRANCH=...` - Show service URLs
- `make wt-logs BRANCH=...` - Tail container logs

**Management (long form):**
- `make worktree-list` - List all worktrees
- `make worktree-status` - Show git status of all worktrees
- `make worktree-remove BRANCH=feature/my-feature` - Remove worktree
- `make worktree-clean` - Clean stale worktrees

**Secrets:**
- Dev secrets (WORKOS keys, API keys) are stored as `op://` references in `apps/frontman_server/envs/.dev.secrets.env` and resolved at runtime via 1Password CLI (`op run`)
- The server Makefile wraps `mix phx.server` with `op run --env-file=envs/.dev.secrets.env` so secrets are injected as env vars
- Requires 1Password CLI (`op`) to be installed and authenticated
- If the server fails on startup with WORKOS errors, ensure `op` is signed in (`op signin`)

**Structure:**
- `.worktrees/<branch-name>/` - Worktree directory
- `.worktrees/<branch-name>/.claude/` - Isolated Claude context (history, plans, todos)

## Containerized Worktrees

When working in a containerized worktree (created via `make worktree-pod-create`),
source files live on the host but the toolchain runs inside a Podman container.

**File operations** (read, write, search, git): Run directly on the host.

**Toolchain commands** (mix, yarn, node): Prefix with `./bin/pod-exec`:
- `./bin/pod-exec mix test`
- `./bin/pod-exec yarn vitest run`
- `./bin/pod-exec mix format --check-formatted`
- `./bin/pod-exec make rescript-build`

**Lifecycle:**
```bash
# One-time infra setup
make infra-up

# Per-feature
make worktree-pod-create BRANCH=feature/cool-thing
make worktree-pod-dev BRANCH=feature/cool-thing

# Pause/resume
make worktree-pod-stop BRANCH=feature/cool-thing
make worktree-pod-start BRANCH=feature/cool-thing

# Done
make worktree-pod-remove BRANCH=feature/cool-thing
```

**Architecture:** Each worktree gets its own Podman pod with a postgres container
and a dev container sharing localhost. A single Caddy reverse proxy routes
`{hash}.{service}.frontman.local` to the correct pod. dnsmasq resolves
`*.frontman.local` to `127.0.0.1`.

## Key Principles
- ReScript codebase - functional style, Result types for errors
- File naming: `Client__ComponentName.res` (flat folder + namespacing)
- Task runner: Makefiles only - never yarn/npm scripts directly
- Test files: `*.test.res.mjs`
- Story files: `*.story.res` (co-located with components)
- Prefer `switch` over `if/else` — use pattern matching for control flow, even for simple boolean/option checks

## Raw JS vs ReScript

- Prefer ReScript/WebAPI bindings and typed externals over `%raw` JavaScript.
- Use `%raw` only when there is no practical typed binding or the browser API cannot be expressed cleanly in ReScript.
- Keep `%raw` blocks minimal and isolated to small interop boundaries; keep business logic and event handling in ReScript.
- For DOM/browser events, prefer typed ReScript handlers plus small externals for missing fields instead of full raw listener implementations.
- Use `Js.typeof(value)` for runtime type checks — it compiles directly to JS `typeof` and returns a `string` (`"string"`, `"number"`, `"boolean"`, `"object"`, `"function"`, `"undefined"`). No `%raw` needed.
- For JS built-ins not in the standard library, prefer typed externals over `%raw` wrappers:
  ```rescript
  // GOOD — typed external, compiles to Array.isArray(x)
  @scope("Array") @val
  external isArray: 'a => bool = "isArray"

  // BAD — unnecessary %raw for something that has a clean binding
  let isArray: 'a => bool = %raw(`function(v) { return Array.isArray(v) }`)
  ```

## Error Handling Philosophy

**Crash early and obviously. Never swallow exceptions.**

- Use `Option.getOrThrow`, `Result.getOrThrow` when the value should always exist
- Let pattern match failures crash - they surface bugs faster than silent fallbacks
- No defensive `Option.getOr(defaultValue)` to hide unexpected states
- No catch-all handlers that silently ignore malformed input
- When something unexpected happens, crash loudly so we see the error and fix the root cause
- Server channel handlers: no fallback clauses for invalid payloads (zero silent failures)

## JSON Parsing with Sury

**Always use Sury schemas for JSON parsing/serialization** instead of manual `JSON.Decode.*` / `Dict.get` patterns.

### Using @schema annotation (preferred)
Add `@schema` annotation to type definitions for automatic schema derivation:
```rescript
@schema
type userConfig = {
  name: string,
  age: int,
  email: option<string>,
}

// Sury automatically generates `userConfigSchema`
// Use it for parsing (wrap in try/catch for error handling):
try {
  let config = S.parseJsonOrThrow(json, userConfigSchema)
  // use config
} catch {
| _ => // handle error
}

// And serialization:
try {
  let jsonString = S.reverseConvertToJsonStringOrThrow(config, userConfigSchema)
  // use jsonString
} catch {
| _ => // handle error
}
```

### Field annotations
Use `@s.describe` for field documentation:
```rescript
@schema
type input = {
  @s.describe("The user's full name")
  name: string,
  @s.describe("Age in years")
  age: int,
}
```

### Why Sury over manual parsing?
- **Type-safe**: Compile-time guarantees for JSON structure
- **Less boilerplate**: No manual `Dict.get` + `Option.flatMap` chains
- **Automatic**: Schema derived from type definition
- **Bidirectional**: Same schema for parsing and serialization
- **Better errors**: Structured error messages on parse failure

## State Management in Client (libs/client)

**All API calls and side effects MUST go through the StateReducer** unless explicitly instructed otherwise.

### Architecture
- `Client__State.res` - Public API: `useSelector`, `Actions`, `Selectors`
- `Client__State__StateReducer.res` - Reducer with actions, effects, and state transitions
- `Client__State__Store.res` - Store instance and dispatch
- `Client__State__Types.res` - Type definitions

### Reading State
Always use selectors via `useSelector`:
```rescript
let messages = Client__State.useSelector(Client__State.Selectors.messages)
let isStreaming = Client__State.useSelector(Client__State.Selectors.isStreaming)
```

### Dispatching Actions (Including API Calls)
Use `Client__State.Actions.*` for ALL state changes and API operations:
```rescript
// User interactions
Client__State.Actions.addUserMessage(~content)
Client__State.Actions.switchTask(~taskId)

// API operations - these trigger side effects
Client__State.Actions.fetchApiKeySettings()
Client__State.Actions.saveOpenRouterKey(~key)
```

### Adding New API Actions
1. **Define the action** in `Client__State__StateReducer.res`:
   ```rescript
   type action =
     | ...
     | FetchSomething
     | FetchSomethingSuccess({data: someType})
     | FetchSomethingError({error: string})
   ```

2. **Define the effect** for async work:
   ```rescript
   type effect =
     | ...
     | FetchSomethingEffect({apiBaseUrl: string})
   ```

3. **Handle the action** in `next` function - return state + effects:
   ```rescript
   | FetchSomething =>
     state->FrontmanReactStatestore.StateReducer.update(
       ~sideEffects=[FetchSomethingEffect({apiBaseUrl: state.apiBaseUrl})],
     )
   ```

4. **Implement the effect handler** in `handleEffect`:
   ```rescript
   | FetchSomethingEffect({apiBaseUrl}) =>
     let fetch = async () => {
       let response = await Fetch.fetch(...)
       if response.ok {
         dispatch(FetchSomethingSuccess({data: ...}))
       } else {
         dispatch(FetchSomethingError({error: "..."}))
       }
     }
     fetch()->ignore
   ```

5. **Expose action creator** in `Client__State.res`:
   ```rescript
   module Actions = {
     let fetchSomething = () => dispatch(FetchSomething)
   }
   ```

### What NOT to Do
```rescript
// BAD - Direct API call in component
@react.component
let make = () => {
  let handleClick = async () => {
    let response = await Fetch.fetch("/api/something")
    // ...
  }
}

// GOOD - Dispatch action that triggers effect
@react.component
let make = () => {
  let handleClick = () => {
    Client__State.Actions.fetchSomething()
  }
}
```

### Exception
Only bypass the reducer when explicitly requested for:
- One-off debugging/testing
- External library integrations that manage their own state
- Performance-critical operations where the overhead is unacceptable

## Storybook Guidelines (libs/client)

### Running Storybook
```bash
cd libs/client && make storybook
```

### Writing Stories in ReScript

Story files should be co-located with components: `Client__MyComponent.story.res`

**Critical rules:**

1. **Never use module aliases** - They compile to undefined exports that break Storybook:
   ```rescript
   // BAD - causes runtime errors
   module Message = Client__State__Types.Message
   let x = Message.SomeVariant

   // ALSO BAD - module S = SomeModule gets exported
   module ACPTypes = FrontmanClient__ACP__Types

   // GOOD - use fully qualified names or `open`
   let x = Client__State__Types.Message.SomeVariant
   // or
   open Client__State__Types
   let x = Message.SomeVariant
   ```

2. **Wrap fixtures/samples in a module** - Top-level `let` bindings get exported as stories:
   ```rescript
   // BAD - these become story entries in the sidebar
   let sampleData = [...]
   let mockEntries = [...]

   // GOOD - wrap in a module (modules are not exported as stories)
   module Samples = {
     let sampleData = [...]
     let mockEntries = [...]
   }

   // Usage in stories
   render: _ => <MyComponent data={Samples.sampleData} />
   ```

3. **Prefix private helpers with underscore** - Prevents them from being indexed as stories:
   ```rescript
   // Private helper (won't appear in sidebar)
   let _stateFromString = str => switch str { ... }
   ```

4. **Use inline string arrays for tags** - Don't use variables:
   ```rescript
   // GOOD
   tags: ["autodocs"]

   // BAD - CSF parser can't resolve variable references
   tags: [Tags.autodocs]
   ```

5. **Use ArgsAdapter for variant types** - Avoids module aliases and reduces boilerplate:
   ```rescript
   // Define adapter once (use underscore prefix to hide from story list)
   let _stateAdapter = ArgsAdapter.fromPairs([
     ("streaming", Client__State__Types.Message.InputStreaming),
     ("available", Client__State__Types.Message.InputAvailable),
     ("done", Client__State__Types.Message.OutputAvailable),
   ])

   // Use in render
   render: args => <MyComponent state={_stateAdapter.get(args.state)} />
   ```

6. **Story structure**:
   ```rescript
   open Bindings__Storybook

   type args = { myProp: string }

   let default: Meta.t<args> = {
     title: "Components/MyComponent",
     tags: ["autodocs"],
     decorators: [Decorators.darkBackground],
     render: args => <MyComponent prop={args.myProp} />,
   }

   let primary: Story.t<args> = {
     name: "Primary",
     args: { myProp: "value" },
   }
   ```

7. **Browser testing with play functions**:
   ```rescript
   let myStory: Story.t<args> = {
     name: "My Story",
     args: { ... },
     play: async ({canvasElement}) => {
       let screen = Browser.within(canvasElement)
       let element = screen->Browser.getByText("Expected Text")
       Browser.expect(element)->Browser.toBeVisible
     },
   }
   ```

## Changelog & Changesets

**All notable changes must be tracked via changesets.**

When making a change that should appear in the changelog, run `yarn changeset` and follow the prompts. This creates a markdown fragment in `.changeset/` describing the change.

- A CI check (`changelog-check.yml`) blocks PRs that don't include a changeset or direct `CHANGELOG.md` update
- Add the `skip-changelog` label to bypass for chore/docs-only PRs
- Changesets accumulate silently on `main` — no auto-PR is created on merge
- To release: run `make release` which triggers a GitHub workflow that runs `yarn changeset version`, creates a `release/vX.Y.Z` branch, and opens a PR for review
- When the release PR is merged, `release-tag.yml` automatically creates a git tag and GitHub Release
- The marketing site reads `/CHANGELOG.md` at build time for the `/changelog` page — keep entries in [Keep a Changelog](https://keepachangelog.com/) format: `## [version] - YYYY-MM-DD`

## Reference Docs
See `agent_docs/rescript-guide.md` for ReScript patterns when needed.
