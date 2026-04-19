# Boundary Contract Policy

This document defines how we share structs and types across boundaries in
`apps/frontman_server`.

## Why this exists

Boundary enforcement is useful, but replacing `%Struct{}` contracts with loose
`map()` checks just to satisfy boundary rules makes the code less safe.

Our default is:

- Keep strong struct/type contracts when they are part of a stable API.
- Make cross-boundary usage explicit through boundary exports and deps.
- Avoid hidden coupling and dependency cycles.

## Rules

1. Private by default
- Child modules and schemas are private unless intentionally exported.
- If a module is not exported by its boundary owner, do not pattern-match on
  its struct from another boundary.

2. Strong contracts over map fallbacks
- Prefer `%SomeStruct{}` and explicit types when a struct is the intended API.
- Do not replace a stable struct contract with `map()` only to bypass boundary
  checks.

3. Explicit publication process
- If a struct/type must be reused across boundaries:
  - Export it from the owner boundary.
  - Add a one-way dependency from consumer boundary to owner boundary.
  - Keep function specs and pattern matches explicit.
  - Record it in the "Public Contract Registry" below.

4. No dependency cycles
- Never create two-way boundary deps.
- If export + dep introduces a cycle, keep one direction and break the other by:
  - moving simple field extraction to local helpers, or
  - introducing a neutral shared contract module/boundary.

5. `dirty_xrefs` are temporary
- Use only as migration scaffolding.
- New `dirty_xrefs` entries should include a boundary-debt note and follow-up issue.

## Current private contracts (do not consume cross-boundary)

- `FrontmanServer.Accounts.UserIdentity`
- `FrontmanServer.Providers.ApiKey`
- `FrontmanServer.Providers.UserKeyUsage`

Consume these via top-level context APIs (for example `Accounts.scope_user_id/1`,
`Accounts.get_user/1`, `Providers.to_llm_args/2`) until they are intentionally
published.

## PR checklist

Before merging changes that touch boundaries:

- Does this change weaken a struct contract to `map()`? If yes, why is that
  better than exporting a contract?
- If a struct is used across boundaries, is it exported intentionally?
- Are boundary deps one-way and cycle-free?
- Is the contract listed in the registry?
- Did `mix compile --warnings-as-errors` and `MIX_ENV=test mix compile --warnings-as-errors` pass?
