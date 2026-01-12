# @frontman/frontman-core

Core server functionality shared across framework adapters, providing a composable tool registry and HTTP server implementation with built-in file system and code search tools.

## Stack

- [ReScript](https://rescript-lang.org) with ES6 modules
- Composable tool registry pattern
- SSE for streaming
- Ripgrep for fast content search (with git grep fallback)

## Features

- Composable tool registry for managing server-side tools
- Core tool execution engine
- Safe path validation
- Event streaming utilities

## Built-in Tools

- `ReadFile` - Read file with offset/limit support
- `WriteFile` - Write file content
- `ListFiles` - List directory contents
- `FileExists` - Check file existence
- `Grep` - Fast pattern search using ripgrep
- `SearchFiles` - File glob pattern matching
- `LoadAgentInstructions` - Load agent configuration files

## Development

Build the library:

```sh
make build
```

Run tests:

```sh
make test
```

## Usage

**ReScript:**
```rescript
open FrontmanCore

// Create a tool registry
let registry = ToolRegistry.create()
  ->ToolRegistry.register(Tool.ReadFile.make())
  ->ToolRegistry.register(Tool.Grep.make())

// Execute a tool
let result = await Server.executeTool(registry, "ReadFile", {
  "path": "/src/main.ts"
})
```

## Dependencies

- `@frontman/bindings` - File I/O and process execution
- `@frontman/frontman-protocol` - Tool type definitions
- `vscode-ripgrep` - Fast content search

## Commands

Run `make` or `make help` to see all available commands.
