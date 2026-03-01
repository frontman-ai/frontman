# @frontman-ai/frontman-client

Browser-based client library implementing MCP (Model Context Protocol) server for AI agent tool execution, with support for multiple transport mechanisms.

## Stack

- [ReScript](https://rescript-lang.org) with ES6 modules
- MCP (Model Context Protocol) for AI agent communication
- Phoenix channels for real-time WebSocket transport
- JSON-RPC 2.0 protocol
- SSE for streaming responses

## Features

- MCP server implementation for handling agent requests
- Multiple transport options (Phoenix channels, SSE, JSON-RPC)
- Connection management and reconnection
- Framework tool relay for delegating to dev server
- Task-based async execution

## Key Modules

- `MCP` - Model Context Protocol server implementation
- `Connection` - Connection management
- `JsonRpc` - JSON-RPC 2.0 message formatting
- `Phoenix__Channel` - Phoenix WebSocket channel integration
- `SSE` - Server-Sent Events for streaming
- `ACP` - Agent Control Protocol implementation
- `Relay` - Framework tool relay

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
open FrontmanClient

// Initialize MCP server
let server = MCP.create({
  tools: myTools,
  onToolCall: async (name, args) => {
    // Handle tool execution
  }
})

// Connect via Phoenix channel
let channel = Phoenix__Channel.create(socket, "agent:lobby")
```

## Dependencies

- `phoenix` ^1.7.0 - WebSocket transport
- `@frontman-ai/frontman-protocol` - Type definitions

## Commands

Run `make` or `make help` to see all available commands.
