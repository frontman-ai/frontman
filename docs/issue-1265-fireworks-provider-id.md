# Spec: Fireworks Provider ID Consistency

## Objective

Use `fireworks_ai` as the canonical Fireworks provider ID from client key submission through persistence, model availability, and prompt execution. Existing users with `fireworks` API-key rows must retain access after deployment.

Production validation on 2026-07-18 found six `fireworks` rows, zero `fireworks_ai` rows, zero users with both rows, and zero interactions containing either Fireworks model prefix. No key values or user identifiers were queried.

## Commands

- Client tests: `make -C libs/client test`
- ReScript build: `make rescript-build`
- Server tests: `make -C apps/frontman_server test`
- Server precommit: `make -C apps/frontman_server precommit`

## Project Structure

- `libs/client/src/state/` contains API-key provider serialization and selected-model storage migration.
- `libs/client/test/` contains reducer and model-refresh regression tests.
- `apps/frontman_server/lib/frontman_server/` contains key lookup and model availability.
- `apps/frontman_server/priv/repo/migrations/` contains persisted provider normalization.
- `apps/frontman_server/test/` contains save-to-model-availability integration coverage.

## Code Style

Use existing provider IDs directly and pattern-match migrations:

```rescript
switch value->String.startsWith("fireworks:") {
| true => "fireworks_ai:" ++ value->String.slice(~start=10, ~end=String.length(value))
| false => value
}
```

Elixir changes follow `agent_docs/elixir-style.md`. SQL migrations remain explicit and collision-safe.

## Testing Strategy

- Update client contract tests to require `fireworks_ai` in save effects and model config.
- Add selected-model storage migration coverage for legacy `fireworks:` values.
- Extend server controller integration coverage from API-key save through `model_config_data/1` and `prepare_llm_args/2`.
- Add migration test only if existing migration-test infrastructure supports it without new machinery.
- Real Fireworks request remains manual follow-up because no valid key is available for this work.

## Boundaries

- Always: preserve encrypted key bytes, normalize existing and blue-green rollout writes, and support legacy browser-selected model values.
- Ask first: change provider validation for every API-key provider or rewrite historical interaction JSON.
- Never: query or log production key values or user identifiers; add a permanent broad alias that lets new `fireworks` rows continue to be created.

## Success Criteria

- Client submits `fireworks_ai` when saving a Fireworks key.
- Existing `fireworks` API-key rows migrate to `fireworks_ai` without data loss.
- Requests from stale clients posting `fireworks` persist and return `fireworks_ai`.
- Saving a Fireworks key exposes a `fireworks_ai` model group whose values use the `fireworks_ai:` prefix.
- Saved key resolves for a canonical Fireworks prompt.
- Legacy browser-selected `fireworks:` model values migrate to `fireworks_ai:`.
- Focused client and server tests pass; ReScript and server quality checks pass.
- Changeset documents user-visible fix.

## Open Questions

None. Production contains no canonical/legacy collisions, so direct normalization is sufficient.
