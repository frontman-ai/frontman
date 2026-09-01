# MCP Phase 0 Decisions

## Oracle

The MCP `2026-07-28` TypeScript schema at release commit `5f5440bb26a62e2cf3440b92da5a667efa03b267` is authoritative. Its checksum and immutable URL are recorded without vendoring the commented source. The generated JSON Schema, official examples, and license from the same commit are vendored unchanged for offline validation.

Ajv validates the oracle as JSON Schema 2020-12. No draft downgrade or schema rewrite is permitted. Network reference resolution remains disabled.

The official conformance source archive is pinned at commit `c321dd32035556e6769d3724a8ee97d87c3faaac`. The matching official `0.2.0-alpha.11` npm package is separately checksum-pinned and supplies the executable for the implemented advertised-capability gate described in `conformance.md`.

## Scope

Frontman implements MCP `2026-07-28` only. It does not implement initialization-era negotiation, protocol sessions, deprecated HTTP+SSE, automatic MRTR fulfillment or retry, progress, subscriptions, resources, prompts, sampling, elicitation, or logging in the initial migration. Browser and Phoenix clients normalize an absent `resultType` to `complete`, recognize and validate the core `input_required` result shape, surface it as unsupported, and do not retry. They advertise no input capabilities; initial Frontman servers do not emit `input_required`.

Phoenix-to-browser MCP uses a documented custom Phoenix transport. Browser-to-framework MCP uses sessionless Streamable HTTP at `POST /mcp` with synchronous JSON responses until a real streaming producer exists.

Runtime limits are frozen in `implementation-limits.md`, including measurement, rejection behavior, owners, and exact boundary vectors. Enforcement tests run in each owning implementation phase because Phase 0 deliberately does not create parallel placeholder transports, validators, correlation owners, or persistence code.
