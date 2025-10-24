# Agent Guidelines for ask-the-llm

## Build/Test Commands
- **Build all**: `make build` (ReScript compilation)
- **Client build**: `cd apps/client && make build` (TypeScript + Vite)
- **Client lint**: `cd apps/client && make lint` (ESLint)
- **Agent test**: `cd libs/agent && make test` (Vitest)
- **Agent test single**: `cd libs/agent && yarn vitest run --run path/to/test`
- **Agent test watch**: `cd libs/agent && make test-watch`
- **Agent format check**: `cd libs/agent && make lint`
- **Agent format**: `cd libs/agent && make format`

## Code Style Guidelines
- **ReScript**: Never use mutable - use `ref` instead. Functional programming style.
- **TypeScript**: Strict mode enabled. Use React.FC with interfaces. Inline styles preferred.
- **Imports**: Group by external libs, then internal modules. Use absolute imports.
- **Naming**: camelCase for variables/functions, PascalCase for components/types.
- **Folder structure**: keep a flat folder structure, use rescript namespacing convention when needed
- **Error handling**: Use Result types in ReScript, try/catch in TypeScript.
- **Testing**: Vitest with Node environment. Test files: `*.test.res.mjs`
- **Task runner**: Makefiles only - never use yarn/npm scripts directly.
- never run via yarn or any other task runner, we use makefile only!
- never user Obj.magic unless you have explicit permission from the user
- dont use mutable. use ref