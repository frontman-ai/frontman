# PlayGithub Cloud Launch For Astro

## Why

Frontman currently depends on users having local development environments, which blocks fast browser-first editing for repositories or pull requests users only want to try, inspect, or modify from a URL.

## What Changes

Core capabilities:

- Add `PlayGithubLaunch` lifecycle from `LaunchRequested` to `LaunchReady` or `LaunchFailed`.
- Add `ProjectAnalyzer` to produce `ProjectAnalysis` with framework, project root, package manager, install command, start plan, and confidence.
- Add `FrameworkBootstrap` first playbook for Astro through `Astro Bootstrap`.

Supporting capabilities:

- Add `SourceTarget` resolution for GitHub repository, ref, PR target, requested path, and resolved commit.
- Add `DevServerRuntime` start flow using `StartPlan`.
- Add `PreviewAccess` route readiness so ready means preview works, not only process started.
- Add `LaunchExperience` state projection for progress, failure, and retry.

Generic capabilities:

- Use `SandboxRuntime` as provider wrapper for Daytona sandbox lifecycle.
- Use `SandboxAccessPolicy` for access, host, workspace, and proxy decisions.
- Use `LaunchTelemetry` for lifecycle metrics.

## Impact

Affected capabilities:

- PlayGithub URL intake
- Launch identity and reuse
- Launch lifecycle orchestration
- Source Target resolution
- Sandbox provisioning
- Project Analysis
- Astro Bootstrap
- Dev Server Runtime
- Preview Access
- Launch Progress UX

Aggregate changes:

- Add `Launch`
- Add `SourceTarget`
- Add `Sandbox`
- Add `ProjectAnalysis`
- Add `BootstrapRun`
- Add `DevServerProcess`
- Add `PreviewRoute`
- Add `LaunchProgressView`
- Add `AccessPolicy`

## Goals

- Public Astro repository reaches `LaunchReady` from PlayGithub URL.
- `Launch` never skips lifecycle steps.
- One active `Launch` exists per user and `Launch Target`.
- `ProjectAnalysis` includes framework, project root, package manager, install command, start plan, port, and confidence.
- `LaunchReady` occurs only after preview route readiness passes.
- Failures produce stable `FailureCategory` and retry decision.
- Existing `FrontmanSession` attaches only after `Ready Session`.
