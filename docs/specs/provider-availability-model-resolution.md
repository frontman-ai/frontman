# Spec: Provider Availability and Model Resolution

## Objective

Remove Frontman provider logic duplicated by ACP, ReqLLM, and LLMDB while
preserving picker behavior, credential precedence, persisted model strings,
image handling, and Settings behavior. Provider catalogs must be read at runtime
so a later runtime-configured OpenAI-compatible group does not require client or
database changes.

Issue #1476 is the product source of truth. This document records implementation
boundaries and verified repository structure.

## Commands

- ReScript build: `make rescript-build`
- Client tests: `make -C libs/client test`
- Server tests: `make -C apps/frontman_server test`
- Swarm AI tests: `make -C apps/swarm_ai test`
- Server precommit: `make -C apps/frontman_server precommit`
- Swarm AI precommit: `make -C apps/swarm_ai precommit`

Containerized worktrees prefix toolchain commands with `./bin/pod-exec`.

## Project Structure

- `libs/client/src/state/`: setup gating and credential effects
- `libs/client/src/components/frontman/`: model availability UI
- `apps/frontman_server/config/`: curated provider catalog and LLMDB config
- `apps/frontman_server/lib/frontman_server/providers.ex`: model and credential resolution
- `apps/frontman_server/lib/frontman_server/tasks/execution/`: LLM preflight and streaming
- `apps/swarm_ai/lib/swarm_ai/schema_transformer.ex`: provider-specific tool schemas
- matching `test/` directories: focused unit and integration coverage

## Code Style

ReScript control flow uses pattern matching:

```rescript
switch activeSession.configOptions {
| None => false
| Some(options) => !options->hasUsableModel
}
```

Elixir resolves catalog data at runtime and passes typed models across execution:

```elixir
defp providers do
  Application.fetch_env!(:frontman_server, :providers)
end
```

Prefer direct struct matching and `Result`/tagged tuple errors. Do not add silent
fallbacks for unknown provider or model selections.

## Behavioral Contract

### Client setup gate

- No active ACP facade: setup modal hidden.
- Active ACP facade without received model config: setup modal hidden.
- Received model config without usable model options: setup required.
- Any non-empty model group or ungrouped option, including unknown future groups:
  setup not required.
- Opening Settings still fetches API-key and OAuth status.
- Establishing an ACP session does not eagerly fetch credential status.
- Credential save/connect auto-selection after model refresh remains unchanged.

### Server resolution

- Persisted selections remain `"group:model"` strings.
- Execution resolves the selected catalog entry once in `prepare_llm_args/3`.
- Resolution returns `%LLMDB.Model{}` and final request options.
- Credential source, Frontman picker group, and ReqLLM model transport are
  independent catalog concepts.
- OAuth continues to take precedence over API keys exactly as it does now.
- Caller options retain their current precedence over generated auth options.
- `LLMClient`, preflight, the `LLMProvider` test seam, and ReqLLM receive the same
  resolved model struct without another `ReqLLM.model/1` call.

### Image and schema policy

- Unsupported images are stripped from LLMDB input modalities.
- Direct Anthropic models use a 7,680-pixel dimension limit.
- More than 20 images use a 2,000-pixel limit for direct Anthropic and
  OpenRouter-hosted Anthropic models.
- Other models have no Frontman dimension limit.
- OpenRouter-hosted OpenAI and Azure model structs retain strict OpenAI tool
  schema transformation.

### Catalog and LLMDB

- Provider ordering, labels, group IDs, and emitted selected-model strings remain
  unchanged.
- Provider catalog access uses runtime application environment.
- Packaged model tuples contain only display name and model ID unless a ReqLLM
  model override is required.
- Frontman's generated `:llm_db, custom` bridge is removed only after pinned
  LLMDB metadata for NVIDIA Kimi K2.6 is characterized without custom config.
  Packaged metadata is authoritative even where it improves stale Frontman
  overrides: output limit `262_144` instead of `65_536`, plus video input.

## Testing Strategy

- Write failing reducer tests before changing setup selectors or session effects.
- Characterize packaged NVIDIA metadata before deleting its override.
- Write failing provider and LLM client tests before changing model types.
- Add schema transformer tests for resolved OpenRouter OpenAI/Azure structs.
- Retain focused image-history integration coverage.
- Run focused suites after each slice, then complete client, server, and Swarm AI
  checks.

## Boundaries

- Always preserve persisted model strings and catalog ordering.
- Always keep Settings credential fetch actions and effects.
- Always preserve the `LLMProvider` test seam.
- Always make unexpected catalog/model mismatches fail visibly.
- Ask first before adding dependencies, migrations, new APIs, or UI.
- Never implement issue #1431 in this change.
- Never persist `%LLMDB.Model{}` structs in task history.
- Never broaden the picker to every ReqLLM model.

## Success Criteria

- All acceptance criteria in issue #1476 pass.
- Focused reducer, provider, model-refresh, preflight, image, and schema tests pass.
- Full client, server, and Swarm AI checks pass.
- Production code diff removes more lines than it adds.
- Notable change has a changeset.

## Open Questions

None. Runtime custom endpoint implementation remains explicitly out of scope.
