# Upstream MCP 2026-07-28 Oracle

This directory vendors the official MCP `2026-07-28` generated JSON Schema, examples, and license unchanged. The authoritative commented TypeScript schema is checksum-pinned but not vendored.

## Specification

- Repository: https://github.com/modelcontextprotocol/modelcontextprotocol
- Release: `2026-07-28`
- Commit: `5f5440bb26a62e2cf3440b92da5a667efa03b267`
- TypeScript source: `schema/2026-07-28/schema.ts`
- TypeScript URL: https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.ts
- TypeScript SHA-256: `742750af0bb8c716e7030c4977c992b55d1adc4407e9e66997db5846baedc2cd`
- JSON Schema source: `schema/2026-07-28/schema.json`
- JSON Schema URL: https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.json
- JSON Schema SHA-256: `ef70b61f99b6d2e5e3b46863822eab08dff6a45bedc7a08914e0e5b133f40203`
- Examples source: `schema/2026-07-28/examples`
- License: Apache-2.0; see `LICENSE`
- Local modifications: none

## Conformance Runner

- Repository: https://github.com/modelcontextprotocol/conformance
- Version: `0.2.0-alpha.11`
- Commit: `c321dd32035556e6769d3724a8ee97d87c3faaac`
- Source archive: https://github.com/modelcontextprotocol/conformance/archive/c321dd32035556e6769d3724a8ee97d87c3faaac.tar.gz
- Archive SHA-256: `57ecc92fc89d9a51139713a7ea92e1376929b2a1bcae2b735b4c303e15ed23d9`
- Official npm package: `@modelcontextprotocol/conformance@0.2.0-alpha.11`
- Package SHA-256: `67d28b0d50d64458232945d9b3af75178add5d05819c748ec2c8b26e5cb038c5`
- License: MIT for the pinned commit
- Local modifications: none

The source archive preserves provenance. The official npm package supplies the published executable used by the applicable runtime conformance gate; neither artifact is fetched or updated during verification.

## Verification

Run `make -C libs/frontman-protocol mcp-verify` for the offline oracle gate. It verifies every vendored checksum, loads the unchanged schema with Ajv's JSON Schema 2020-12 validator, validates each official example against the upstream definition named by its parent directory, and checks the complete normative traceability corpus for exact row counts, columns, and unique IDs. Root `make mcp-verify` is configured as the broader serial aggregate and requires `test/e2e/.env` before any expensive gate begins; no complete aggregate run is implied when that preflight fails.

## Refresh

1. Select an official stable MCP release and resolve its tag to an immutable commit.
2. Download the TypeScript schema only to calculate and record its checksum.
3. Replace the generated JSON Schema, examples, and license without modification.
4. Select an official conformance runner commit and replace its source archive without modification.
5. Regenerate `SHA256SUMS` in deterministic path order.
6. Update the provenance fields above.
7. Run `make -C libs/frontman-protocol mcp-verify` without network access.
8. Run root `make mcp-verify` with the credentialed E2E environment available.
