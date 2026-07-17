# Frontman ACP Agent Attribution Extension v1

## Status

This document defines Frontman's version 1 agent-attribution extension for Agent
Client Protocol (ACP) v1. The key words **MUST**, **MUST NOT**, **REQUIRED**,
**SHOULD**, **SHOULD NOT**, and **MAY** are normative.

## Standards Basis

This extension follows these upstream requirements:

- ACP custom data belongs in `_meta`; implementations MUST NOT add custom fields
  at the root of ACP types:
  <https://agentclientprotocol.com/protocol/v1/extensibility#the-_meta-field>
- Custom capabilities are advertised through capability-object `_meta` fields:
  <https://agentclientprotocol.com/protocol/v1/extensibility#advertising-custom-capabilities>
- ACP peers negotiate the base protocol and capabilities during `initialize`:
  <https://agentclientprotocol.com/protocol/v1/initialization#capabilities>
- ACP v1 `messageId` is an optional, opaque, Agent-generated identifier. Chunks
  sharing an ID belong to one message:
  <https://agentclientprotocol.com/protocol/v1/prompt-turn#message-ids>
- The completed Message ID RFD further specifies uniqueness within a session,
  stability across chunks, and user-message ID generation by the Agent:
  <https://agentclientprotocol.com/rfds/message-id#proposed-structure>
- `session/load` streams all history notifications before returning its response:
  <https://agentclientprotocol.com/protocol/v1/session-setup#loading-a-session>
- Message content uses ACP `ContentBlock` values:
  <https://agentclientprotocol.com/protocol/v1/content#content-types>
- Extension timestamps use RFC 3339 Internet date/time syntax:
  <https://datatracker.ietf.org/doc/html/rfc3339#section-5.6>

Frontman requirements below narrow optional ACP behavior only after both peers
negotiate this extension. They do not alter ACP v1 wire types.

## Namespace And Keys

Frontman owns these `_meta` keys:

| Location | Key | Value |
| --- | --- | --- |
| `clientCapabilities._meta` and `agentCapabilities._meta` | `frontman.dev` | Capability namespace object |
| New/load session response `_meta` | `frontman.dev/agents` | Agent catalog array |
| User/agent message chunk `_meta` | `frontman.dev/agentId` | Agent ID string |
| User/agent message chunk `_meta` | `frontman.dev/timestamp` | RFC 3339 timestamp string |

No Frontman field may appear at the root of an ACP request, response, capability,
session update, or content block. ACP-standard `messageId` remains at the
`ContentChunk` root because ACP defines that field.

Unrelated `_meta` entries MUST be accepted and ignored by Frontman validation.

## Negotiation

### Client Advertisement

A Frontman client supporting this extension MUST advertise version 1 in
`clientCapabilities._meta`:

```json
{
  "jsonrpc": "2.0",
  "id": 0,
  "method": "initialize",
  "params": {
    "protocolVersion": 1,
    "clientCapabilities": {
      "fs": {
        "readTextFile": true,
        "writeTextFile": true
      },
      "terminal": true,
      "_meta": {
        "frontman.dev": {
          "agentAttribution": {
            "version": 1
          }
        }
      }
    },
    "clientInfo": {
      "name": "frontman",
      "title": "Frontman",
      "version": "1.0.0"
    }
  }
}
```

### Agent Advertisement

A supporting Agent MUST advertise version 1 in `agentCapabilities._meta`:

```json
{
  "jsonrpc": "2.0",
  "id": 0,
  "result": {
    "protocolVersion": 1,
    "agentCapabilities": {
      "loadSession": true,
      "promptCapabilities": {
        "image": true,
        "audio": false,
        "embeddedContext": true
      },
      "_meta": {
        "frontman.dev": {
          "agentAttribution": {
            "version": 1
          }
        }
      }
    },
    "agentInfo": {
      "name": "frontman-server",
      "title": "Frontman Server",
      "version": "1.0.0"
    },
    "authMethods": []
  }
}
```

Version 1 is negotiated only when both advertisements contain unsigned 16-bit
integer `version: 1`. Missing `frontman.dev`, missing `agentAttribution`, or a version
mismatch leaves the extension unnegotiated. An unsupported positive integer
from 1 through 65535 is not malformed; peers continue with generic ACP behavior.

If a peer advertises `frontman.dev.agentAttribution` but its value is not an
object, or its `version` is not an integer from 1 through 65535, a Frontman
implementation MUST fail initialization visibly. An Agent receiving a malformed request uses a
JSON-RPC invalid-params error. A Client receiving a malformed response rejects
initialization and reports the reason to the user.

## Agent Catalog

After version 1 negotiation, every successful `session/new` and `session/load`
response MUST contain `_meta["frontman.dev/agents"]`.

Each catalog entry has these Frontman-defined fields:

| Field | Requirement |
| --- | --- |
| `id` | REQUIRED non-empty string; stable identity and catalog key |
| `name` | REQUIRED non-empty programmatic name |
| `displayName` | REQUIRED non-empty user-facing name |
| `description` | REQUIRED string |
| `color` | REQUIRED string matching `^#[0-9A-Fa-f]{6}$` |

Catalog IDs MUST be unique. Clients MUST use the supplied color and MUST NOT
derive or substitute one. Unknown catalog-entry fields MUST be ignored.

### New Session

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "session/new",
  "params": {
    "cwd": "/home/user/project",
    "mcpServers": []
  }
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "sessionId": "sess_abc123",
    "_meta": {
      "frontman.dev/agents": [
        {
          "id": "planner",
          "name": "planner",
          "displayName": "Planner",
          "description": "Plans implementation work",
          "color": "#6D5EF5"
        },
        {
          "id": "executor",
          "name": "executor",
          "displayName": "Executor",
          "description": "Implements approved work",
          "color": "#16A085"
        }
      ]
    }
  }
}
```

### Loaded Session And ACP Ordering

Frontman MUST preserve ACP's load sequence: the Agent streams complete history
as `session/update` notifications and only then returns the `session/load`
response. Frontman MUST NOT send the load response before history.

To make the response catalog available before application state consumes
attributed history, the low-level Frontman client MUST buffer load-time
notifications. After the response arrives, it validates and installs the catalog,
then delivers buffered notifications in original wire order. Buffering changes no
ACP wire ordering and is invisible to generic clients.

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "session/load",
  "params": {
    "sessionId": "sess_abc123",
    "cwd": "/home/user/project",
    "mcpServers": []
  }
}
```

The Agent first sends history notifications such as the chunk examples below.
After all history:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "_meta": {
      "frontman.dev/agents": [
        {
          "id": "planner",
          "name": "planner",
          "displayName": "Planner",
          "description": "Plans implementation work",
          "color": "#6D5EF5"
        },
        {
          "id": "executor",
          "name": "executor",
          "displayName": "Executor",
          "description": "Implements approved work",
          "color": "#16A085"
        }
      ]
    }
  }
}
```

The Agent MUST validate the complete catalog and replay sequence before emitting
the first history notification. The Client MUST discard its whole replay buffer
if response metadata or any buffered attributed update is invalid. Partial
history MUST NOT enter application state.

## Catalog Ownership And History

Frontman server exposes one current global product-agent catalog. Each catalog
entry defines one product agent. Session creation and loading MUST return that
catalog in active configuration order. Conversation history persists only the
stable catalog entry ID; it does not preserve display metadata snapshots.

Renaming, recoloring, or otherwise changing a catalog entry while retaining its
ID intentionally changes how all historical messages display. Every attributed
historical chunk MUST resolve to exactly one entry in the current catalog. If a
referenced ID has been removed, session load MUST crash before history emission.
Frontman server MUST NOT remap a missing ID to a default or synthetic agent.

## Attributed Message Chunks

After version 1 negotiation, every `user_message_chunk` and
`agent_message_chunk` emitted by Frontman MUST contain:

- ACP `messageId` as a present, non-empty string.
- `_meta["frontman.dev/agentId"]` as a present, non-empty string resolving in
  the session catalog.
- `_meta["frontman.dev/timestamp"]` as a present RFC 3339 timestamp.

All chunks belonging to one logical message MUST repeat identical `messageId`,
`agentId`, and `timestamp` values. Frontman clients compare `messageId` as an
opaque string and MUST NOT parse its implementation-specific structure.

For user chunks, `agentId` identifies the selected execution target for that
message. It does not identify the human author.

### Multi-block User Message

One accepted user message containing text and embedded context is emitted as one
standard `user_message_chunk` per content block. Every chunk shares the persisted
user interaction row ID and metadata:

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "sess_abc123",
    "update": {
      "sessionUpdate": "user_message_chunk",
      "messageId": "user_interaction_42",
      "content": {
        "type": "text",
        "text": "Review this file"
      },
      "_meta": {
        "frontman.dev/agentId": "executor",
        "frontman.dev/timestamp": "2026-07-14T12:30:00.123456Z"
      }
    }
  }
}
```

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "sess_abc123",
    "update": {
      "sessionUpdate": "user_message_chunk",
      "messageId": "user_interaction_42",
      "content": {
        "type": "resource",
        "resource": {
          "uri": "file:///home/user/project/lib/example.ex",
          "mimeType": "text/elixir",
          "text": "defmodule Example do\nend\n"
        }
      },
      "_meta": {
        "frontman.dev/agentId": "executor",
        "frontman.dev/timestamp": "2026-07-14T12:30:00.123456Z"
      }
    }
  }
}
```

### Assistant Message

Assistant identity is deterministic across live delivery and replay. Its
`messageId` is the persisted `TurnStarted.id`, followed by `:`, followed by the
zero-based persisted `AgentResponse` ordinal in that turn. For example,
`turn_9f5c:0` is the first response segment and `turn_9f5c:1` is the response
segment after a tool exchange.

The timestamp is captured when the response segment starts and is persisted on
the closing `AgentResponse`; replay uses that persisted timestamp. Every live
chunk in the segment uses the captured value.

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "sess_abc123",
    "update": {
      "sessionUpdate": "agent_message_chunk",
      "messageId": "turn_9f5c:0",
      "content": {
        "type": "text",
        "text": "I found "
      },
      "_meta": {
        "frontman.dev/agentId": "executor",
        "frontman.dev/timestamp": "2026-07-14T12:30:01.000000Z"
      }
    }
  }
}
```

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "sess_abc123",
    "update": {
      "sessionUpdate": "agent_message_chunk",
      "messageId": "turn_9f5c:0",
      "content": {
        "type": "text",
        "text": "two issues."
      },
      "_meta": {
        "frontman.dev/agentId": "executor",
        "frontman.dev/timestamp": "2026-07-14T12:30:01.000000Z"
      }
    }
  }
}
```

Every persisted `AgentResponse` advances the ordinal, including a contentless
response containing only tool calls. Tool calls and tool results do not inherit
message IDs and do not themselves advance the ordinal. Content after a tool
exchange uses the next response ordinal; skipped IDs are valid when an earlier
response had no content chunks.

## Validation And Failure Semantics

When version 1 is negotiated:

- Missing catalog metadata received from a peer, empty identity fields, and
  invalid colors MUST fail session creation or loading visibly. Invalid server
  catalog configuration and historical IDs absent from the current global
  catalog MUST crash.
- A known user or agent chunk with missing or malformed `messageId`, `agentId`,
  or `timestamp` MUST fail the session visibly. It MUST NOT degrade into an
  unknown update.
- An `agentId` absent from the installed catalog MUST fail the session visibly.
- A live chunk without active turn context, a stale-turn chunk, or a response
  close without an active response segment MUST fail visibly.
- Unknown ACP session-update variants remain ignorable for forward compatibility.
- Unrelated well-formed `_meta` keys remain accepted.

For request processing, visible failure means a JSON-RPC error on the associated
request when one remains open. Because JSON-RPC notifications have no response
(<https://www.jsonrpc.org/specification#notification>), a Client detecting an
invalid notification MUST mark the session failed, stop applying updates, and
surface the validation error to the user.

## Generic And Unnegotiated Peers

Without mutual version 1 negotiation, Frontman-specific requirements are
disabled. A Frontman receiver MUST ignore all `frontman.dev` metadata and process
the exchange as generic ACP v1. In particular, ACP v1 permits missing
`messageId`.

A generic ACP client may receive Frontman metadata from an Agent and ignore it,
as ACP `_meta` values are extension data. It still sees standard
`user_message_chunk`, `agent_message_chunk`, `content`, and optional `messageId`
fields. No mode update or `configOptions` entry is required to interpret base ACP
messages.

Example generic session response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "sessionId": "sess_abc123",
    "_meta": {
      "frontman.dev/agents": [
        {
          "id": "executor",
          "name": "executor",
          "displayName": "Executor",
          "description": "Implements approved work",
          "color": "#16A085"
        }
      ],
      "example.net/traceId": "trace-7"
    }
  }
}
```

Generic clients ignore both metadata entries and consume `sessionId`. Frontman
clients negotiated at version 1 validate `frontman.dev/agents` and ignore the
unrelated `example.net/traceId` entry.

## Versioning

Version 1 behavior is immutable once shipped. Additive or breaking changes to
required Frontman metadata use a new positive integer version. Peers negotiate
only versions both support; they MUST NOT infer support from metadata observed
outside initialization.

ACP base-protocol version negotiation remains independent. This extension does
not redefine ACP session modes, session configuration options, content blocks,
or JSON-RPC envelopes.
