# Dev Server Start

## Requirement: Start Dev Server

A supported project can start a dev server from its `StartPlan`.

### Scenario: Dev server starts on expected port

Given a `StartPlan` with project root, start command, and expected port
When dev server start runs
Then the dev server is reachable on the expected port
And publish `DevServerStarted`.

### Scenario: Start plan missing expected port

Given a `StartPlan` without an expected port
When dev server start runs
Then the dev server is not started
And publish `DevServerCrashed`.

### Scenario: Dev server cannot start

Given a `StartPlan`
And the dev server cannot become reachable
When dev server start runs
Then dev server start fails with a `FailureCategory`
And publish `DevServerCrashed`.

## Requirement: Record Dev Server Crash

A running dev server can become crashed after it has started.

### Scenario: Running dev server crashes

Given a running dev server
When the dev server stops unexpectedly
Then the dev server is marked crashed
And publish `DevServerCrashed`.
