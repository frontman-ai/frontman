# Tasks

Each task is a small shippable slice, roughly <=500 lines of code changed, excluding generated lockfile noise. If a task grows beyond that, split by domain model first, then adapter/integration second.

## 0. Existing PlayGithub migration map

Spec paths:

- `specs/source-target/github-target-resolution/spec.md`
- `specs/play-github-launch/launch-target/spec.md`
- `specs/play-github-launch/launch-lifecycle/spec.md`
- `specs/sandbox-runtime/sandbox-provisioning/spec.md`
- `specs/preview-access/preview-route/spec.md`

Scope:

- Inventory current PlayGithub implementation and mark each piece as keep, replace, or split.
- Map current `GithubReference` identity to proposed `SourceTarget` and `LaunchTarget` identity.
- Decide whether current `playgithub_sandboxes` remains `Sandbox`, becomes `Launch`, or splits into separate launch/runtime records.
- Define migration path from current status enum and `status_error` to step attempts, `FailureCategory`, retryability, and ready state.
- Define extraction path from direct Daytona calls to `SandboxRuntime` without changing behavior.
- Define whether existing `?command=create|start|clone|install|dev` endpoints are temporary debug API or lifecycle API.
- Map existing sandbox proxy plug behavior to proposed `PreviewAccess` / `PreviewRoute` model.

Not included:

- No new launch behavior.
- No Daytona API behavior change.
- No schema migration unless the chosen mapping requires a tiny compatibility field.

Acceptance criteria:

- Existing PlayGithub route, parser, sandbox, clone, install, dev, and proxy behavior are accounted for.
- PR target support gap is explicitly resolved: implement `/pull/:number`, defer it with changed acceptance criteria, or remove PR target from the first parser task.
- One canonical source of truth is chosen for lifecycle state during migration.
- Follow-up tasks name whether they are adding new code, replacing existing code, or extracting existing code.
- Current focused PlayGithub tests still pass unchanged unless the task intentionally updates semantics.

Suggested tests:

- Compatibility tests for existing `GithubReference` identities and `playgithub_sandboxes` uniqueness.
- Characterization tests for existing command endpoints and proxy host policy.

## 1. PlayGithub route and target parser

Spec paths:

- `specs/source-target/github-target-resolution/spec.md`
- `specs/play-github-launch/launch-target/spec.md`

Scope:

- Verify or add route/controller entry for PlayGithub host/path.
- Parse repository, tree/path, and pull request URL forms into `SourceTarget`, replacing or wrapping existing `GithubReference` parsing per task 0.
- Translate valid `SourceTarget` into stable `LaunchTarget` key compatible with the chosen task 0 identity mapping.
- Reject invalid targets with explicit reason.

Not included:

- No Daytona calls.
- No sandbox persistence.
- No project analysis.

Acceptance criteria:

- Repository target parses.
- Pull request target parses.
- Requested path target parses.
- Invalid target is rejected.
- Same user and target produce same `LaunchTarget` key.

Suggested tests:

- Controller/path parser unit tests.
- `LaunchTarget` key equality tests.
- Regression test for current repository and tree path identities.

## 2. Launch aggregate and persisted lifecycle shell

Spec path:

- `specs/play-github-launch/launch-lifecycle/spec.md`

Scope:

- Add `Launch` state model with statuses, step attempts, failure category, and target key.
- Enforce one active launch per user and `LaunchTarget`, using the source of truth chosen in task 0.
- Implement create/reuse behavior.
- Add lifecycle transition validation with no external side effects.
- Preserve or intentionally migrate existing `playgithub_sandboxes` behavior rather than creating an uncoordinated parallel lifecycle.

Not included:

- No sandbox creation.
- No async orchestration.
- No UI progress page beyond minimal response/projection if needed.

Acceptance criteria:

- New launch can be created.
- Existing active launch is reused.
- Step cannot be skipped.
- Failed step stores `FailureCategory`.

Suggested tests:

- Aggregate transition tests.
- Repository uniqueness test.
- Controller test for create/reuse response.

## 3. SandboxRuntime adapter boundary

Spec path:

- `specs/sandbox-runtime/sandbox-provisioning/spec.md`

Scope:

- Extract or add `SandboxRuntime` contract and Daytona-backed implementation from the existing direct Daytona usage.
- Create sandbox for launch and record provider sandbox id/workspace path.
- Map provider errors into stable sandbox failure categories.
- Keep provider language behind adapter boundary.

Not included:

- No clone command execution.
- No install/start commands.
- No proxying.
- No lifecycle behavior rewrite beyond moving provider calls behind the boundary.

Acceptance criteria:

- Sandbox creation succeeds with provider response.
- Sandbox creation failure maps to `SandboxCreationFailed`.
- Disabled/unconfigured provider does not break unrelated server boot.

Suggested tests:

- Adapter tests with mocked Daytona responses.
- Runtime config test for disabled feature.

## 4. Launch step runner for create-sandbox only

Spec paths:

- `specs/play-github-launch/launch-lifecycle/spec.md`
- `specs/sandbox-runtime/sandbox-provisioning/spec.md`

Scope:

- Add lifecycle runner that advances one step: sandbox creation.
- Record `LaunchStepStarted`, `SandboxCreated`, and `LaunchStepSucceeded`.
- Record retryable failure if sandbox creation fails.
- Make runner idempotent for repeated `create` command or its task 0 replacement.

Not included:

- No clone.
- No project analysis.
- No event outbox yet; direct command path is acceptable for this task.
- No duplicate source of truth beside existing PlayGithub command/status behavior unless task 0 chose a split model.

Acceptance criteria:

- `?command=create` creates sandbox and advances launch to next step.
- Re-running create does not create duplicate sandbox.
- Failure stores stable `FailureCategory` and retryability.

Suggested tests:

- Controller lifecycle tests for create success/failure/retry.

## 5. Repository acquisition and ref resolution

Spec path:

- `specs/source-target/github-target-resolution/spec.md`

Scope:

- Resolve branch/tag/SHA/PR target into `ResolvedCommit` where possible.
- Clone repository into sandbox workspace.
- Record clone success/failure as launch step result.
- Keep first slice public repositories only.

Not included:

- No private repo auth.
- No project analysis.
- No dependency install.

Acceptance criteria:

- Public repo clones into workspace.
- Missing ref fails with stable failure category.
- PR target checkout policy is explicit and records resolved commit.

Suggested tests:

- Ref strategy unit tests.
- Sandbox command mock tests for clone success/failure.

## 6. ProjectAnalyzer for Astro fixtures

Spec path:

- `specs/project-analyzer/project-analysis/spec.md`

Scope:

- Analyze cloned workspace and requested path.
- Detect Astro via project signals.
- Produce `ProjectAnalysis` with project root, package manager, install command, start plan, expected port, and confidence.
- Reject unsupported or low-confidence projects.

Not included:

- No dependency install.
- No adapter install.
- No dev server start.

Acceptance criteria:

- Root Astro project is supported.
- Nested Astro project is supported when requested path points to it.
- Unsupported project is rejected.
- Analysis does not mutate files.

Suggested tests:

- Fixture tests: root Astro, nested Astro, missing Astro, custom dev script.

## 7. Dependency install command step

Spec paths:

- `specs/project-analyzer/project-analysis/spec.md`
- `specs/sandbox-runtime/sandbox-provisioning/spec.md`

Scope:

- Execute `ProjectAnalysis` install command in project root.
- Ensure command stays within workspace boundary.
- Record install success/failure on launch.
- Add timeout and log reference mapping.

Not included:

- No Frontman adapter install.
- No dev server start.

Acceptance criteria:

- Install command uses analyzed project root.
- Install failure records `FailureCategory` and log reference.
- Retry does not skip analysis result validation.

Suggested tests:

- Command construction tests.
- Failure mapping tests.

## 8. Astro Bootstrap idempotent adapter install

Spec path:

- `specs/framework-bootstrap/astro-bootstrap/spec.md`

Scope:

- Install/configure `@frontman-ai/astro` for analyzed Astro project.
- Detect existing adapter and avoid duplicate configuration.
- Record mutation summary and bootstrap result.
- Reject framework mismatch.

Not included:

- No dev server start.
- No broader framework support.

Acceptance criteria:

- Astro adapter installs for supported Astro analysis.
- Re-running bootstrap is idempotent.
- Non-Astro analysis is rejected.

Suggested tests:

- Astro config fixture before/after tests.
- Idempotency test.

## 9. DevServerRuntime start and health check

Spec path:

- `specs/dev-server-runtime/dev-server-start/spec.md`

Scope:

- Start dev server from `StartPlan` in analyzed project root.
- Force host/port behavior needed for sandbox access where appropriate.
- Verify expected port is reachable.
- Record crash/start failure.

Not included:

- No preview proxy route.
- No Frontman session readiness.

Acceptance criteria:

- Dev server starts on expected port.
- Missing port is rejected.
- Unreachable process records `DevServerCrashed` or start failure.

Suggested tests:

- Start command construction tests.
- Health-check success/failure tests with mocked runtime.

## 10. PreviewAccess proxy and readiness

Spec path:

- `specs/preview-access/preview-route/spec.md`

Scope:

- Configure preview route for sandbox dev server.
- Enforce allowed host and proxy target policy.
- Validate app, assets, and Frontman route readiness.
- Publish `PreviewRouteConfigured` only after readiness passes.

Not included:

- No agent task behavior.
- No browser/dev-server tool redesign.

Acceptance criteria:

- Allowed proxy target creates `PreviewRoute`.
- Denied target is rejected.
- Preview readiness gates `LaunchReady`.

Suggested tests:

- Proxy target policy tests.
- Readiness check tests.

## 11. Launch progress and retry UX

Spec path:

- `specs/launch-experience/launch-progress/spec.md`

Scope:

- Show launch progress from `Launch` projection.
- Show step-specific user-facing failure from `FailureCategory`.
- Expose retry action only when `RetryableStepSpecification` allows it.
- Resume after login with strict return target handling.

Not included:

- No new agent task UI.
- No changes to existing Frontman tools.

Acceptance criteria:

- Progress reflects launch state only.
- Retryable failures show retry.
- Non-retryable failures do not show retry.
- Return URL is restricted to allowed PlayGithub/Frontman hosts.

Suggested tests:

- Projection tests.
- Auth return URL tests.
- Retry action tests.

## 12. Event reliability and reconciliation

Spec paths:

- `specs/play-github-launch/launch-lifecycle/spec.md`
- `specs/project-analyzer/project-analysis/spec.md`
- `specs/preview-access/preview-route/spec.md`

Scope:

- Add outbox/idempotency for integration events that cross context boundaries.
- Deduplicate replayed events by idempotency key.
- Add reconciliation for side effect succeeded but launch state not recorded.
- Add dead-letter handling for exhausted event failures.

Not included:

- No new domain capabilities.
- No provider abstraction beyond existing `SandboxRuntime` boundary.

Acceptance criteria:

- Critical events have idempotency keys.
- Replayed events do not duplicate launch transitions.
- Reconciliation can recover sandbox-created and bootstrap-installed facts.
- Reconciliation covers the known side-effect gap where provider sandbox creation can succeed before local launch/runtime state is recorded.

Suggested tests:

- Idempotent replay tests.
- Dead-letter tests.
- Reconciliation tests.

## Recommended Merge Order

0. Existing PlayGithub migration map
1. PlayGithub route and target parser
2. Launch aggregate and persisted lifecycle shell
3. SandboxRuntime adapter boundary
4. Launch step runner for create-sandbox only
5. Repository acquisition and ref resolution
6. ProjectAnalyzer for Astro fixtures
7. Dependency install command step
8. Astro Bootstrap idempotent adapter install
9. DevServerRuntime start and health check
10. PreviewAccess proxy and readiness
11. Launch progress and retry UX
12. Event reliability and reconciliation

## Cut Lines

If any task exceeds roughly 500 LOC:

- Split domain model and persistence from controller/UI wiring.
- Split happy path from failure/retry behavior.
- Split adapter contract from provider implementation.
- Split parser/model tests from lifecycle integration tests.
