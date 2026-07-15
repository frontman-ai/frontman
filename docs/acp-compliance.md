# ACP v1 Compliance

Frontman agent attribution is an extension of official ACP wire protocol version 1. Base
envelopes are tested offline against the checksum-pinned upstream schema documented in
`libs/frontman-protocol/schemas/acp/upstream/README.md`. Frontman-owned metadata receives
additional strict validation through Sury schemas.

Official sources:

- Schema: https://github.com/agentclientprotocol/agent-client-protocol/blob/a213df5240048f96d2b23f644984bb20c188a234/schema/v1/schema.json
- Extensibility: https://agentclientprotocol.com/protocol/v1/extensibility
- Schema release: https://github.com/agentclientprotocol/agent-client-protocol/releases/tag/schema-v1.19.0

## Behavior Matrix

| Case | Frontman behavior | Evidence |
| --- | --- | --- |
| Attribution advertisement absent | Continue as generic ACP without Frontman validation | `FrontmanClient__ACP__Client.test.res`: generic initialize/load tests |
| Attribution version unsupported | Do not negotiate attribution | `acp_contract_test.exs`: absent or unsupported advertisement |
| Negotiated session catalog missing | Fail session new/load visibly | `FrontmanClient__ACP__Client.test.res`: missing catalog tests |
| Catalog color malformed | Reject metadata | `FrontmanClient__ACP__Types.test.res`: session metadata validation |
| Attributed chunk `agentId` missing or empty | Reject known chunk | `FrontmanClient__ACP__Types.test.res`: message and known chunk validation |
| Attributed chunk references unknown agent | Fail replay/live session | `FrontmanClient__ACP__Client.test.res`: unknown replay agent; client provider catalog lookup |
| Message identity changes agent, role, timestamp, or task | Fail visibly | `Client__TextDeltaBuffer.test.res`: identity mismatch tests |
| Active agent definition conflicts with historical snapshot | Fail catalog resolution | `FrontmanServer.AgentsTest` and channel catalog tests |
| Removed agent has persisted snapshot | Replay archived display metadata unchanged | `acp_history_test.exs`: removed-agent replay |
| Removed legacy agent lacks snapshot/current definition | Fail load before emitting partial history | `acp_history_test.exs`: malformed/legacy history |
| Unrelated `_meta` keys | Accept and ignore | Upstream compliance test and ACP type metadata tests |
| Unknown future `sessionUpdate` | Ignore at runtime for forward compatibility; not valid against closed upstream enum | ACP client unknown-update tests |

## Validation Layers

1. `acp_upstream_compliance_test.exs` validates complete JSON-RPC envelopes against official ACP.
2. Generated schemas under `schemas/acp/` validate Frontman's strict extension contract.
3. Sury runtime parsing rejects malformed known attributed updates without degrading to unknown.
4. Generic, unnegotiated parsing accepts ignorable Frontman metadata without applying it.

Unknown `sessionUpdate` values are intentionally tolerated by Frontman's runtime parser for
forward compatibility. Official stable schema `SessionUpdate` remains a closed enum, so those
values are outside upstream schema conformance.
