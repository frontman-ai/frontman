# Upstream ACP v1 Schema

This directory vendors the official stable Agent Client Protocol v1 JSON Schema unchanged.

- Repository: https://github.com/agentclientprotocol/agent-client-protocol
- Schema release: `schema-v1.19.0`
- Commit: `a213df5240048f96d2b23f644984bb20c188a234`
- Source: `schema/v1/schema.json`
- Source URL: https://raw.githubusercontent.com/agentclientprotocol/agent-client-protocol/a213df5240048f96d2b23f644984bb20c188a234/schema/v1/schema.json
- SHA-256: `92c1dfcda10dd47e99127500a3763da2b471f9ac61e12b9bf0430c32cf953796`
- License: Apache-2.0; see `LICENSE`
- Local modifications: none

Schema release `1.19.0` describes ACP wire protocol version `1`. These versions are independent.

## Refresh

1. Select a stable `schema-v*` release from the official repository.
2. Resolve its tag to an immutable commit.
3. Download `schema/v1/schema.json` and repository `LICENSE` from that commit.
4. Verify published checksum before replacing files.
5. Update provenance fields above and checksum in `FrontmanServer.ProtocolSchema`.
6. Run `mix test test/protocols/acp_upstream_compliance_test.exs` from `apps/frontman_server`.
7. Run `make -C libs/frontman-protocol check-schemas`.
8. Run `make -C libs/frontman-client check`.
9. Run `make -C libs/client test`.
10. Run `make -C apps/frontman_server precommit`.
11. Run `make reanalyze` from the repository root.

`FrontmanServer.ProtocolSchema` adapts `$defs` to draft-7 `definitions` only in memory because
the test dependency supports draft 7, while this artifact declares draft 2020-12. The pinned
schema uses no other 2020-12-only validation keywords. Vendored `schema.json` remains unchanged.
