# Agent Guidelines for ask-the-llm

## Build/Test Commands
- **Build all**: `make build`
- **Agent test**: `cd libs/agent && make test`
- **Agent test single**: `cd libs/agent && yarn vitest run --run path/to/test`
- **Agent format**: `cd libs/agent && make format`

## Key Principles
- ReScript codebase - functional style, Result types for errors
- File naming: `Client__ComponentName.res` (flat folder + namespacing)
- Task runner: Makefiles only - never yarn/npm scripts directly
- Test files: `*.test.res.mjs`
- Story files: `*.story.res` (co-located with components)

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
