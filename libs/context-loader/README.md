# @frontman/context-loader

Dynamically discovers and loads configuration files from global, local, and custom paths, building a comprehensive context for agents.

## Stack

- [ReScript](https://rescript-lang.org) with ES6 modules
- File system discovery and traversal
- Path normalization

## Features

- Discovers configuration files from multiple locations (global, local, custom)
- Returns detailed metadata about each file (path, content, source type)
- Tracks whether files were auto-discovered or explicitly specified
- Supports configurable search paths

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
open ContextLoader

let context = await load({
  globalPaths: ["/home/user/.config"],
  localPaths: ["./"],
  customFiles: ["./custom-config.md"],
})

// Each file includes metadata:
// - path: absolute path to file
// - content: file contents
// - source: Global | Local | Custom
// - discovered: whether file was auto-discovered
```

## Dependencies

- `@frontman/bindings` - File system operations

## Commands

Run `make` or `make help` to see all available commands.
