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
- Shared dependencies (node_modules symlinked)

**Management:**
- `make worktree-list` - List all worktrees
- `make worktree-status` - Show git status of all worktrees
- `make worktree-remove NAME=feature/my-feature` - Remove worktree
- `make worktree-clean` - Clean stale worktrees

**Structure:**
- `.worktrees/<branch-name>/` - Worktree directory
- `.worktrees/<branch-name>/.claude/` - Isolated Claude context
- `.worktrees/<branch-name>/node_modules` - Symlink to main repo

## Key Principles
- ReScript codebase - functional style, Result types for errors
- File naming: `Client__ComponentName.res` (flat folder + namespacing)
- Task runner: Makefiles only - never yarn/npm scripts directly
- Test files: `*.test.res.mjs`
- Story files: `*.story.res` (co-located with components)

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

## Reference Docs
See `agent_docs/rescript-guide.md` for ReScript patterns when needed.
