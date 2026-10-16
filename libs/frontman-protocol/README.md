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

#### MCP baseline and deployment prerequisites

The Phoenix orchestration server is the MCP client. The browser is its MCP server.
They exchange JSON-RPC 2.0 objects through `mcp:message` on the `task:<task_id>` Phoenix channel.
The socket authenticates the embedded-client token and origin. The channel authorizes task access through the user's scope.
See [socket authentication](../../apps/frontman_server/lib/frontman_server_web/channels/user_socket.ex) and [task-channel handling](../../apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex).

The MCP version is `2026-07-28`. Every request carries version and client capabilities in `params._meta`:
- `io.modelcontextprotocol/protocolVersion`
- `io.modelcontextprotocol/clientCapabilities`
- `io.modelcontextprotocol/clientInfo` (optional identity, supplied by Elixir)

The browser checks metadata on each request. MCP has no initialization handshake here.
`server/discover` is optional for callers, but the current Elixir channel requests discovery before the tool catalog.
For `tools/call`, the browser requires the caller's `ai.frontman/execution-context` v1 capability and metadata containing `taskId` and `callId`.
The `taskId` must match the browser handler's session.
Elixir separately requires the browser to advertise both `ai.frontman/execution-context` v1 and `ai.frontman/tool-metadata` v1 during discovery.
Browser discovery advertises `tools.listChanged: false`. Discovery and catalogs use `cacheScope: "private"` and `ttlMs: 0`.
See [shared contracts](src/FrontmanProtocol__MCP.res), [browser dispatch](../frontman-client/src/FrontmanClient__MCP.res), and [Elixir discovery validation](../../apps/frontman_server/lib/frontman_server_web/channels/task_channel/mcp_initializer.ex).

**Pending core work, not optional exemptions:**
- Elixir currently validates tool responses as completed results. A valid `input_required` interim, including a state-only result, does not receive distinct handling.
- The browser currently rejects `subscriptions/listen` as an unknown method. Subscription acknowledgment and closure remain pending even with no supported change notifications.

These gaps prevent a claim of complete MCP conformance. Optional client-input features do not exempt implementations from core message patterns.
Automatic MRTR retry is not implemented. The MCP rules permit a client to decline retry, but recognition of valid interims remains necessary.

ACP retains its independent `initialize` exchange on `acp:message`.
The framework/WordPress relay uses separate protocol versions `1.0` and `2.0`.
MCP version changes do not replace either contract or impose Streamable HTTP headers or GET removal on the relay.
The browser currently ignores MCP notifications, including `notifications/cancelled`. ACP session cancellation does not provide MCP request cancellation.
On reconnect, the channel redispatches unresolved tool calls without a read/write guard. External writes can repeat.
This documentation does not fix replay safety or authorize uncertain-write replay.

Authoritative references:
- [MCP base protocol](https://modelcontextprotocol.io/specification/2026-07-28/basic/index.md)
- [Per-request versioning](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning.md)
- [MRTR](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr.md) and [subscriptions](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/subscriptions.md)
- [Pinned upstream schema](https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/86f6e0c675afea9a8f233e09b6faf566b126086c/schema/2026-07-28/schema.ts)

The [production workflow](../../.github/workflows/deploy.yml) selects main pushes under `libs/**` and `apps/frontman_server/**`, including README changes.
It deploys server and hosted-browser artifacts. An `environment: production` declaration does not prove that required approvals exist.

Before any merge, an operator must provide evidence of an effective deployment hold or approval gate for affected main pushes.
The evidence must identify the control and approver without credentials.
The actual hold and an isolated pre-production target remain unverified. The inactive production slot is not proof of staging.
This local documentation candidate does not authorize merge or rollout.
Production rollout requires approved artifact compatibility, rollback evidence, and explicit acceptance or a separate fix for uncertain-write replay.

### Relay

Framework tool relay protocol:
- `remoteTool` - Remote tool execution request
- `toolsResponse` - Tool execution response

### Tool

Tool interface definitions:
- `ServerTool` module type - Server-side tool with execution context
- `BrowserTool` module type - Browser-side tool without context
- `ExecutionContext` - Tool execution context with project/source root

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
