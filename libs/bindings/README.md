# @frontman/bindings

ReScript bindings for Node.js and browser APIs, providing ergonomic wrappers around standard modules and web APIs.

## Stack

- [ReScript](https://rescript-lang.org) with ES6 modules
- Node.js APIs (fs, path, child_process, streams)
- Browser APIs (WebStreams, TypedArrays)
- OpenTelemetry for observability

## Key Modules

- `ChildProcess` - Spawn and execute processes with promise-based API
- `Fs` - File system operations (read, write, access, mkdir)
- `Path` - Path manipulation utilities
- `Process` - Process environment and utilities
- `NodeStreams` - Readable/writable stream bindings
- `WebStreams` - Browser stream API bindings
- `OpenTelemetry` - Tracing and observability bindings
- `Chrome` - Chrome DevTools Protocol bindings
- `Dotenv` - Environment variable loading

## Development

Build the library:

```sh
make build
```

Watch mode for development:

```sh
make dev
```

## Usage

**ReScript:**
```rescript
open Bindings

// Read a file
let content = await Fs.readFile(~path="./config.json", ~encoding="utf-8")

// Execute a command
let result = await ChildProcess.exec("ls -la")
```

## Commands

Run `make` or `make help` to see all available commands.
