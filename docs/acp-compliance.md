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
| Negotiated initialization configuration missing | Fail initialization visibly | `FrontmanClient__ACP__Client.test.res`: missing configuration tests |
| Catalog color malformed or default unknown | Reject initialization metadata | `FrontmanClient__ACP__Types.test.res`: initialization metadata validation |
| Attributed chunk `agentId` missing or empty | Reject known chunk | `FrontmanClient__ACP__Types.test.res`: message and known chunk validation |
| Attributed chunk references unknown agent | Fail replay/live session | `FrontmanClient__ACP__Client.test.res`: unknown replay agent |
| Message identity changes timestamp or task | Fail visibly | `FrontmanClient__ACP__Client.test.res`: session update identity tests |
| Historical agent ID is absent from current global catalog | Crash before emitting partial history | `acp_history_test.exs`: unknown global agent replay |
| Generic ACP peer receives Frontman metadata | Ignore extension metadata and consume standard ACP fields | Upstream compliance and generic initialize tests |
| Unrelated `_meta` keys | Accept and ignore | Upstream compliance test and ACP type metadata tests |
| Unknown future `sessionUpdate` | Ignore at runtime for forward compatibility; not valid against closed upstream enum | ACP client unknown-update tests |

## Validation Layers

1. `acp_upstream_compliance_test.exs` validates complete JSON-RPC envelopes against official ACP.
2. Named ACP definitions in `schemas/generated.json` mirror local implementation types, with compatibility wrappers under `schemas/acp/`; metadata fragment schemas define the strict Frontman extension contract, while full session-update unions also include local behavior.
3. Sury runtime parsing rejects malformed known attributed updates without degrading to unknown.
4. Generic, unnegotiated parsing accepts ignorable Frontman metadata without applying it.

Unknown `sessionUpdate` values are intentionally tolerated by Frontman's runtime parser for
forward compatibility. Official stable schema `SessionUpdate` remains a closed enum, so those
values are outside upstream schema conformance. `state_update` and `error` are proprietary
Frontman session updates and are not presented as official ACP variants.
