# Frontman Execution Context Extension

## Status

This document defines version `1` of the Frontman-specific MCP extension
`ai.frontman/execution-context` for MCP `2026-07-28`.

The extension is mandatory only for browser tool execution over Frontman's custom
Phoenix transport, where Phoenix is the MCP client and the browser is the MCP
server. It is not required on Streamable HTTP requests from the browser to a
framework server.

## Purpose

MCP is stateless and requires state spanning requests to be identified explicitly.
Frontman must associate a browser tool execution with both its durable task and its
durable persisted tool call. Connection identity, channel identity, request order,
and prior requests are not substitutes for either identifier.

The extension carries protocol context only. It does not authenticate a peer,
authorize a tool, grant task access, establish execution ownership, or prove that
either identifier exists.

## Identifier And Version

The extension identifier is:

```text
ai.frontman/execution-context
```

The identifier uses the reverse-DNS `ai.frontman/` prefix and does not use an
MCP-reserved prefix.

Version `1` support is advertised with this settings object:

```json
{
  "ai.frontman/execution-context": {
    "version": 1
  }
}
```

The `version` field is required and must equal the integer `1`. Additional settings
fields are preserved but have no version `1` meaning. An absent setting, missing
version, or any other version is not compatible with version `1`.

## Negotiation

The browser server advertises version `1` under
`server/discover` result `capabilities.extensions`.

The Phoenix client advertises version `1` under
`_meta.io.modelcontextprotocol/clientCapabilities.extensions` on every applicable
request. A prior request or discovery exchange does not satisfy this per-request
requirement.

Both advertisements must contain compatible version `1` settings before browser
tool execution can proceed.

If the browser server does not advertise compatible support, the Phoenix client
sends no `tools/call` request and terminates the attempted execution with this local
failure classification:

```json
{
  "reason": "missing_required_server_extension",
  "extension": "ai.frontman/execution-context",
  "requiredVersion": 1
}
```

This is not a JSON-RPC error received from the peer and must not be represented as
one. The later execution owner maps the local failure into the canonical persisted
tool outcome without claiming that the browser emitted an MCP response.

If an applicable request does not declare compatible client support, the browser server returns
`MissingRequiredClientCapabilityError` `-32021` with:

```json
{
  "requiredCapabilities": {
    "extensions": {
      "ai.frontman/execution-context": {
        "version": 1
      }
    }
  }
}
```

There is no core fallback because browser execution cannot safely infer durable
task or tool-call identity from the transport. In particular, implementations must
not fall back to an ACP session ID, Phoenix topic, channel process, connection ID,
or locally generated replacement identifier.

## Request Metadata

Every `tools/call` request sent over the custom Phoenix transport includes:

```json
{
  "_meta": {
    "ai.frontman/execution-context": {
      "taskId": "task-1",
      "toolCallId": "tool-call-1"
    }
  }
}
```

`taskId` is the opaque, non-empty durable Frontman task identifier.

`toolCallId` is the opaque, non-empty durable identifier of the persisted Frontman
tool call whose execution is being requested.

Both fields are required strings. Receivers preserve additional context fields but
assign them no version `1` meaning. Receivers must not parse, normalize, replace, or
derive either identifier from connection state.

Missing or malformed execution-context metadata is invalid request parameters and
returns `InvalidParamsError` `-32602`. A syntactically valid context still undergoes
later ownership, existence, replay, and authorization checks before any side effect.

Validation order is significant. The browser first parses ordinary required MCP
request metadata, then checks the per-request client capability and returns `-32021`
when it is absent or incompatible, then validates execution-context metadata and
returns `-32602` when that context is absent or malformed. Context-shape validation
must not absorb a missing-capability error.

## Lifecycle

The context applies to one request. Cancellation and its terminal response correlate
through the JSON-RPC request ID, while durable recovery and deduplication use the
extension's `toolCallId`. Reconnect does not transfer ownership or authorize replay
by itself.

The browser must pass the validated task and tool-call identifiers into execution
and cancellation ownership. Framework relays must not receive or invent this
Phoenix-specific context unless a future extension version explicitly defines that
behavior.

## Security

Extension metadata is untrusted peer input. The browser validates its shape before
lookup or execution. Trusted persistence and authenticated transport state determine
whether the referenced task and tool call are accessible and executable.

Logging must not include tool arguments or unrelated metadata values. Diagnostic
records may include bounded identifiers only under the repository's later logging
and privacy policy.

## Normative Basis

- [MCP statelessness](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#statelessness)
- [MCP extension negotiation](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning#extension-negotiation)
- [MCP metadata and required client capabilities](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#meta)
- [MCP tools calling](https://modelcontextprotocol.io/specification/2026-07-28/server/tools#calling-tools)
