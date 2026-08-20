# @frontman-ai/frontman-client

Browser protocol library for Frontman. It implements the browser MCP server used over Frontman's custom Phoenix transport and the Streamable HTTP MCP client used to discover and execute tools on framework integrations.

## Stack

- [ReScript](https://rescript-lang.org) with ES6 modules
- MCP (Model Context Protocol) for AI agent communication
- Phoenix channels for real-time WebSocket transport
- JSON-RPC 2.0 protocol
- Streamable HTTP with JSON or standard SSE responses

## Features

- MCP server implementation for handling agent requests over Phoenix channels
- MCP Streamable HTTP client targeting exact `POST /mcp`
- Connection management and reconnection
- Framework tool discovery, validation, caching, and execution
- Task-based async execution

## Key Modules

- `FrontmanClient__MCP` - Browser MCP server over the custom Phoenix transport
- `FrontmanClient__MCP__Client` - Sessionless Streamable HTTP client for framework MCP servers
- `FrontmanClient__MCP__SSE` - Standard SSE response parser for Streamable HTTP
- `FrontmanClient__MCP__Server` - Combines browser-local and remote framework tools
- `FrontmanClient__Phoenix__Channel` - Phoenix WebSocket channel integration
- `FrontmanClient__ACP` - Agent Client Protocol implementation

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
let client = FrontmanClient__MCP__Client.make(
  ~baseUrl="http://localhost:5173",
  ~requestHeaders=Dict.fromArray([("Authorization", "Bearer local-token")]),
)

switch await FrontmanClient__MCP__Client.connect(client) {
| Ok() =>
  await FrontmanClient__MCP__Client.executeTool(
    client,
    ~name="read_file",
    ~arguments=JSON.Encode.object(Dict.fromArray([("path", JSON.Encode.string("src/App.tsx"))])),
  )
| Error(message) => Error(message)
}
```

## Dependencies

- `phoenix` ^1.7.0 - WebSocket transport
- `@frontman-ai/frontman-protocol` - Type definitions

## Commands

Run `make` or `make help` to see all available commands.
