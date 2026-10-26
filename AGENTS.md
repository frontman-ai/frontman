# Agent Guidelines for Frontman

## Worktrees & Development

Use git worktrees for parallel feature development:

```bash
make worktree-create BRANCH=feature/my-feature
cd .worktrees/feature/my-feature
```

- Use Make targets for development tasks. `yarn changeset` is the exception for changelog entries.
- Development secrets are `op://` references in `apps/frontman_server/envs/.dev.secrets.env`.
- The server Makefile injects them through `op run`; keep the 1Password CLI installed and authenticated.
- If startup fails with WorkOS authentication errors, check `op signin`.
- Use Tailscale to connect to servers.

## Key Principles

- Keep PRs below 500 net-new lines. Prefer smaller changes.
- Reuse existing execution paths. Prefer a small guard over a new abstraction.

## Testing (Mandatory)

- Always prefer writing end-to-end (E2E) and integration tests over unit tests for new behavior and bug fixes.
- Exercise real application paths and dependencies. Assert observable outcomes, not implementation details.
- Add unit tests only for cases that E2E or integration tests cannot reasonably cover. Explain that gap before writing them.
- Do not introduce or use mocks, stubs, fakes, or other test doubles without explicit user permission for the task.
- If a real dependency is unavailable, report the blocker and ask the user before substituting a test double.
- Always read the full test file before adding a new test.

## ReScript

- Use functional style and Result types for expected errors.
- Use flat, namespaced filenames such as `Client__ComponentName.res`.
- Name ReScript test files `*.test.res.mjs`.
- Prefer `switch` over `if/else`, including boolean and option checks.
- Before adding bindings, check `libs/bindings` and existing WebAPI libraries.
- Prefer typed bindings and externals over `%raw`. Keep unavoidable `%raw` limited to small interop boundaries.
- Write JavaScript only with explicit user permission.
- Use `Js.typeof(value)` for runtime type checks.
- Use Sury schemas for JSON parsing and serialization. Prefer `@schema` over manual `JSON.Decode.*` or `Dict.get` parsing.

## Error Handling

- Crash on broken invariants. Use `Option.getOrThrow` or `Result.getOrThrow` for values that must exist.
- Handle expected user and network errors explicitly. Never swallow exceptions or hide bugs with default values.
- Do not add fallback clauses that silently ignore invalid server channel payloads.

## Client State (`libs/client`)

- Route all API calls, state changes, and side effects through `Client__State.Actions` and the StateReducer.
- Read state through `Client__State.useSelector` and selectors.
- Add actions and effects in `Client__State__StateReducer.res`; expose action creators in `Client__State.res`.
- Bypass the reducer only with explicit user permission.

## Changelog & Releases

- Track notable changes with `yarn changeset` fragments in `.changeset/`.
- CI requires a changeset or direct `CHANGELOG.md` update. Use `skip-changelog` only for chore/docs-only PRs.
- Changesets accumulate on `main`. Run `make release` to open a release PR.
- Merging the release PR creates the git tag and GitHub Release.
- The marketing site reads `CHANGELOG.md`. Keep entries in Keep a Changelog format: `## [version] - YYYY-MM-DD`.
- Push branch updates before creating or updating a PR.

## Reference Docs

- `agent_docs/elixir-style.md` — required before writing Elixir code.
- `agent_docs/rescript-guide.md` — ReScript patterns.
