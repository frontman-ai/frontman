# Design

## Architecture

`PlayGithubLaunch` is the core lifecycle context. It owns `Launch` state and decides the next lifecycle step.

`SourceTarget`, `SandboxRuntime`, `ProjectAnalyzer`, `FrameworkBootstrap`, `DevServerRuntime`, and `PreviewAccess` are supplier contexts. They publish facts back to `PlayGithubLaunch`.

Existing `FrontmanSession` remains outside this changeset. PlayGithub ends at `Ready Session`.

## Data Model Mapping

- `Launch` owns lifecycle status, target key, step attempts, failure category, and ready state.
- `SourceTarget` owns canonical GitHub source meaning and resolved commit.
- `Sandbox` owns provider sandbox identity, workspace path, and runtime commands.
- `ProjectAnalysis` owns immutable analysis result for resolved commit and requested path.
- `BootstrapRun` owns adapter install result and mutation summary.
- `DevServerProcess` owns running process state and port.
- `PreviewRoute` owns preview URL and proxy target.
- `LaunchProgressView` is projection only.

## Core Data Flow

1. `SourceTarget` parses raw PlayGithub URL.
2. `PlayGithubLaunch` creates or reuses `Launch`.
3. `SandboxRuntime` creates `Sandbox`.
4. `SourceTarget` resolves ref and source acquisition clones repository.
5. `ProjectAnalyzer` creates `ProjectAnalysis`.
6. `FrameworkBootstrap` runs Astro Bootstrap.
7. `DevServerRuntime` starts dev server from `StartPlan`.
8. `PreviewAccess` configures and validates preview route.
9. `PlayGithubLaunch` evaluates `ReadySessionSpecification`.
10. `LaunchReady` lets existing `FrontmanSession` open.

## Integration Patterns

- `PlayGithubLaunch` to supplier contexts: Customer-Supplier plus Published Language.
- `PlayGithubLaunch` to `SandboxRuntime`: ACL to protect core domain from provider language.
- `PlayGithubLaunch` to `SourceTarget`: ACL for raw URL and GitHub language translation.
- `LaunchExperience` to `PlayGithubLaunch`: OHS plus Published Language.
- Existing `FrontmanSession` to `PreviewAccess`: Conformist.

## Event Reliability

Each aggregate transaction publishes events through Outbox.

Rules:

- One transaction modifies one aggregate.
- Cross-aggregate consistency is eventual.
- Integration events include idempotency keys.
- Consumers deduplicate by event idempotency key.
- Failed consumers retry with backoff.
- Exhausted events move to dead-letter handling with `FailureCategory`.

## Key Idempotency Keys

- `LaunchRequested`: user id + launch target key
- `LaunchStepSucceeded`: launch id + step + attempt number + result ref
- `RefResolved`: source target id + ref strategy + resolved commit
- `ProjectAnalyzed`: resolved commit + requested path + analyzer version
- `FrameworkAdapterInstalled`: launch id + adapter + adapter version + project root
- `PreviewRouteConfigured`: launch id + route id + proxy target

## Ready Criteria

`Ready Session` requires:

- `DevServerStarted`
- `PreviewRouteConfigured`
- Preview route health check passed
- Frontman route reachable
- No failed required launch step
