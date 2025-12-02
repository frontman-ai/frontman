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

## Reference Docs
See `agent_docs/rescript-guide.md` for ReScript patterns when needed.
