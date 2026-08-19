# Implementation Plan: Provider Availability and Model Resolution

## Overview

Implement issue #1476 in risk-first, test-driven slices. First prove dependency
metadata and current behavior, then replace client credential-derived availability,
then resolve server models once, and finally remove obsolete catalog metadata.

## Architecture Decisions

- ACP model options are the sole client authority for prompt/setup availability.
- Settings credential state remains independent and loads only when Settings opens.
- Provider catalog entries separate picker ID, credential source, and ReqLLM model
  specification. Existing entries use defaults; future runtime entries may override.
- Persist strings at rest and resolve exact catalog entries at execution time.
- `%LLMDB.Model{}` is the execution boundary type through preflight and streaming.
- Image policy is computed from resolved provider and model ID beside preflight.
- Runtime catalog reads use `Application.fetch_env!/2`; tests that mutate env run
  synchronously and restore prior config.

## Task List

### Phase 1: Characterization

#### Task 1: Prove packaged NVIDIA metadata

**Acceptance criteria:**

- Pinned LLMDB resolves `nvidia:moonshotai/kimi-k2.6` with custom config disabled.
- Packaged capabilities, limits, and modalities are recorded, including its
  `262_144` output limit and video input that supersede the stale override.
- Evidence is encoded in a regression test or captured test fixture rather than an
  undocumented manual claim.

**Verification:** focused provider test plus direct packaged-catalog query

**Dependencies:** None

**Files likely touched:**

- `apps/frontman_server/test/frontman_server/providers/prepare_api_key_test.exs`

#### Task 2: Characterize resolved-struct policies

**Acceptance criteria:**

- Failing tests cover OpenRouter OpenAI/Azure strict tool schemas as model structs.
- Failing tests cover direct Anthropic and OpenRouter Anthropic image limits.
- Existing unsupported-image behavior remains asserted.

**Verification:** focused Swarm AI schema and server preflight tests

**Dependencies:** None

**Files likely touched:**

- `apps/swarm_ai/test/swarm_ai/schema_transformer_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/llm_request_preflight_test.exs`

### Checkpoint: Characterization

- Packaged NVIDIA metadata is proven.
- New policy tests fail for expected missing struct behavior only.

### Phase 2: ACP Availability

#### Task 3: Test ACP-derived setup state

**Acceptance criteria:**

- Tests cover no session, config pending, empty models, known usable models, and
  unknown future usable groups.
- Credential status cannot override ACP model availability.
- Session initialization expects no eager credential-status effects.

**Verification:** focused reducer and model-refresh tests fail as expected

**Dependencies:** None

**Files likely touched:**

- `libs/client/test/Client__State__StateReducer.test.res`
- `libs/client/test/Client__ModelsRefresh.test.res`

#### Task 4: Replace setup synchronization

**Acceptance criteria:**

- Setup requirement derives only from active ACP state and received model options.
- Credential-loading selectors/helpers used only by setup are deleted.
- Initial ACP session transition performs no credential requests.
- Settings fetch-on-open and provider auto-selection remain unchanged.

**Verification:** `make rescript-build` and focused client tests pass

**Dependencies:** Task 3

**Files likely touched:**

- `libs/client/src/state/Client__State__StateReducer.res`
- `libs/client/test/Client__State__StateReducer.test.res`
- `libs/client/test/Client__ModelsRefresh.test.res`

### Checkpoint: Client

- Client build and complete client test suite pass.
- Setup modal presentation tests remain unchanged and pass.

### Phase 3: Resolve Once

#### Task 5: Test runtime catalog resolution

**Acceptance criteria:**

- Tests require `prepare_llm_args/3` to return `%LLMDB.Model{}`.
- OAuth/API-key precedence and option merge order remain covered.
- Runtime application-env catalog changes affect resolution without recompilation.
- Invalid selections fail visibly instead of using unknown-provider map lookup.

**Verification:** focused provider tests fail against current string result

**Dependencies:** Task 1

**Files likely touched:**

- `apps/frontman_server/test/frontman_server/providers/prepare_api_key_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/user_api_key_controller_test.exs`

#### Task 6: Implement runtime catalog model resolution

**Acceptance criteria:**

- Catalog reads occur at runtime.
- Exact picker entry resolves once to `%LLMDB.Model{}`.
- Picker group, credential source, and model specification are separate concepts.
- Existing picker output and persisted strings are unchanged.

**Verification:** focused provider and controller tests pass

**Dependencies:** Task 5

**Files likely touched:**

- `apps/frontman_server/config/providers.exs`
- `apps/frontman_server/lib/frontman_server/providers.ex`
- `apps/frontman_server/test/frontman_server/providers/prepare_api_key_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/user_api_key_controller_test.exs`

#### Task 7: Test struct-through-stream execution

**Acceptance criteria:**

- Tests require preflight and `LLMProvider.stream_text/3` to receive the resolved
  model struct.
- No LLM client test depends on unresolved model strings.
- Existing parallel streaming and image behavior remains covered.

**Verification:** focused LLM client and execution tests fail as expected

**Dependencies:** Task 6

**Files likely touched:**

- `apps/frontman_server/test/frontman_server/tasks/execution/llm_client_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/llm_client_parallel_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution_test.exs`
- `apps/frontman_server/test/support/fixtures/llm_provider.ex`

#### Task 8: Pass resolved model through preflight and streaming

**Acceptance criteria:**

- LLM client reads modalities from the struct and performs no model lookup.
- Image limits derive from resolved model identity.
- Same struct reaches ReqLLM through the preserved test seam.
- OpenRouter-hosted OpenAI/Azure structs retain strict tool schemas.

**Verification:** focused LLM client, preflight, execution, image-history, and Swarm
AI schema tests pass

**Dependencies:** Tasks 2 and 7

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server/tasks/execution/llm_client.ex`
- `apps/frontman_server/lib/frontman_server/tasks/execution/llm_provider.ex`
- `apps/frontman_server/lib/frontman_server/tasks/execution/llm_request_preflight.ex`
- `apps/swarm_ai/lib/swarm_ai/schema_transformer.ex`
- related focused tests from Tasks 2 and 7, split into separate edits if needed

### Checkpoint: Execution

- Provider, preflight, image-history, execution, and schema suites pass.
- Search confirms no duplicate `ReqLLM.model/1` call in LLM client.
- Search confirms removed provider/vendor/image lookup helpers have no callers.

### Phase 4: Catalog Cleanup

#### Task 9: Remove obsolete LLMDB bridge

**Acceptance criteria:**

- Generated `config :llm_db, custom` code is deleted.
- `llm_db_provider`, `:packaged`, and stale NVIDIA metadata are deleted.
- Normal provider model entries use display/model pairs.
- Packaged NVIDIA metadata test remains green under normal application load.

**Verification:** focused provider tests and server compile pass

**Dependencies:** Tasks 1 and 6

**Files likely touched:**

- `apps/frontman_server/config/config.exs`
- `apps/frontman_server/config/providers.exs`
- `apps/frontman_server/test/frontman_server/providers/prepare_api_key_test.exs`

#### Task 10: Final verification and changeset

**Acceptance criteria:**

- Client, server, and Swarm AI full checks pass.
- Production diff is net-negative.
- Changeset describes behavior-preserving provider simplification.
- Diff review finds no #1431 implementation or unrelated changes.

**Verification:**

- `make -C libs/client test`
- `make -C apps/frontman_server precommit`
- `make -C apps/swarm_ai precommit`
- `git diff --stat origin/main...HEAD`

**Dependencies:** Tasks 4, 8, and 9

**Files likely touched:**

- `.changeset/<generated-name>.md`

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| OpenRouter OpenAI schemas become flexible | High | Struct-specific tests before changing model type |
| NVIDIA override removed before package parity | High | Load pinned LLMDB with custom config disabled first |
| Runtime env tests race | Medium | `async: false`, restore env in `on_exit/1` |
| Error precedence changes | Medium | Preserve credential precedence tests and document exact invalid-model result |
| Fake test model IDs stop resolving | Low | Replace with real catalog IDs or scoped runtime test catalog |
| Stale client config survives disconnect | Low | Gate on active ACP facade; avoid unrelated lifecycle changes unless test proves need |

## Open Questions

None.
