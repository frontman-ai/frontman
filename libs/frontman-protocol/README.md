# @frontman-ai/frontman-protocol

Shared protocol definitions and type schemas for communication between clients and servers, defining the contract for tool-based systems.

## Stack

- [ReScript](https://rescript-lang.org) with ES6 modules
- JSON schema definitions via Sury
- Protocol module type definitions

## Protocols

### MCP (Model Context Protocol)

Types for AI agent communication:
- `server/discover` - Capability and version discovery
- `tools/list` - List available tools
- `tools/call` - Execute a tool

### Tool

Tool interface definitions:
- `ServerTool` module type - Server-side tool with execution context
- `BrowserTool` module type - Browser-side tool without context
- `ExecutionContext` - Tool execution context with project/source root

Framework integrations expose these tools through the MCP `server/discover`, `tools/list`, and `tools/call` contracts. There is no separate Relay protocol or private tool route contract.

## Development

Build the library:

```sh
make build
```

## Usage

**ReScript:**
```rescript
open FrontmanProtocol

// Define a server tool
module MyTool: Tool.ServerTool = {
  let name = "MyTool"
  let description = "Does something useful"

  type input = { path: string }
  type output = { content: string }

  let inputSchema = ...
  let outputSchema = ...

  let execute = async (ctx, input) => {
    // Implementation
  }
}
```

## Commands

Run `make` or `make help` to see all available commands.
