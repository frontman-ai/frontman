# Plan 002 execution review

Execution began on 2026-09-06 against `b54232d9`.

## Delegation

The lead did not edit implementation source. Herdr agents worked in isolated Git worktrees.

| Owner | Worktree branch | Responsibility | Current verdict |
|---|---|---|---|
| `wait-swarm` | `refactor/wait-swarm` | Executor policy deletion and canonical errors | Accepted; agent closed |
| `wait-client` | `refactor/wait-client` | Question cancellation and queue contracts | Accepted; agent closed |
| `wait-server` | `refactor/wait-server` | Server correction and integration | Subset accepted; agent closed |
| `wait-review` | Read-only reviewer | Independent race analysis and final review | Subset approved; agent closed |

The first three assignments ran in parallel against an explicit descriptor contract. Only the server owner can integrate their approved commits.

Final integration and acceptance are sequential gates. The lead and independent reviewer both inspect source and rerun checks.

## Accepted component evidence

### Client

Commit: `36852fe29426da7f7c52d45d2e431353c255a333`.

The lead reviewed the reducer and test changes, then independently ran:

- Client tests: 428 passed.
- Frontman client tests: 88 passed.
- Protocol tests: 12 passed.

The independent reviewer repeated those runs and found no actionable defect. Production delta: three lines added, three removed.

Tiqet task `0baa6d2963fc29132be4ae16bbd5d260` is complete.

### Swarm

Commit: `b3b3068b301673b8fe3bf1897d707b05102434cc`.

The lead reviewed executor code, API changes, and regression tests. An independent `make check` run passed 124 tests, formatting, and Credo.

The independent reviewer repeated those checks and found no actionable defect.

The final descriptor callback is `on_error(reason, tool_call)`, including `:timeout` and `{:crashed, exit_reason}`. It returns the canonical application result.

A regression first demonstrated that a task could persist success and then crash before returning. The final callback preserves that stored success.

Tiqet task `35aa273fdf6aaf95563ec2cf006ce5e3` is complete.

## Design rejection

Independent review rejected the proposed admission change before integration.

A task-row transaction followed by a synchronous Runtime call can deadlock. Runtime's abnormal-exit handler can require that same row for terminal persistence.

An outside finishing check also leaves a race between the check and admission. The proposed change did not guarantee another wake after losing admission.

The lead stopped this section. The Swarm owner removed all speculative admission APIs and tests. Baseline runtime admission remains unchanged.

The authorized subset removes timeout-pause policy and corrects human waits, canonical results, and supported cleanup. It does not claim full continuation consolidation.

**Full Plan 002 remains BLOCKED**, not DONE. No-executor cancellation, fresh-history admission, and guaranteed single continuation need a separate sound design.

## Final integration verdict: APPROVE SUBSET

Branch: `refactor/wait-server`.

Worktree: `/home/bluehotdog/dev/frontman/.worktrees/refactor/wait-server`.

Final commit: `ec585f780ef2e5896d806d46ec4ac9a9374ad741`.

Commit sequence:

- `2bbbb18d`: approved Swarm component.
- `5c9cadfd`: approved client component.
- `b99b6b56`: server correction, cleanup, regression tests, and documentation.
- `ec585f78`: bounded synchronization for the preserved Registry handoff test.

### Lead verification

- Server strict compilation, check, and precommit passed. Final server suite: 895 tests passed.
- Integrated Swarm check: 124 tests passed after the test-only correction.
- Integrated ReScript build passed.
- Integrated client, frontman-client, and protocol suites: 428 + 88 + 12 tests passed.
- Whitespace, scoped files, and clean worktree checks passed.

### Independent final verification

The reviewer read the server source and tests, then independently ran integrated checks:

- Server strict compilation: passed.
- Server check: 895 tests passed.
- Swarm check: 124 tests passed.
- Scope, whitespace, and clean worktree: passed.

The reviewer found no actionable defect in the authorized subset. This is not approval of the deferred admission redesign.

### Review correction

The lead's integrated Swarm run initially failed the unchanged final assertion in the handoff test.

The test observed worker death before Registry processed its independent cleanup notification. The reviewer confirmed a test synchronization race, not an introduced admission change.

The executor added a two-second monotonic bound with scheduler yields. It preserved registration during persistence, blocked admission, next-worker completion, and final registry absence.

The owner ran the focused test with 20 varied seeds. Both the lead and reviewer then passed the full Swarm check.

### Deletion and scope

Changed production source contains **348 added lines and 405 removed lines**, a net reduction of **57 lines**. Tests and documentation are excluded from this count.

No production Runtime, Registry, ExecutionWorker, or execution-admission change remains. No new dependency, coordinator process, or persisted lifecycle table was added.

The public Swarm descriptor API changed. Its changelog marks the change as breaking; no package was published.

### Remaining work

Full Plan 002 remains BLOCKED. Tiqet task `54e364db8edb293dab93500dd490f1bf` remains open because continuation consolidation was not delivered.

The client, Swarm, and independent-review tasks are complete. All four team agents were closed and their absence was verified through Herdr.

The worktrees and commits remain available for inspection. No implementation source was edited by the lead, merged to main, or pushed.
