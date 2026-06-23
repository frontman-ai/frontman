# Sandbox Provisioning

## Requirement: Create Sandbox

An authenticated `Launch` can receive a cloud `Sandbox`.

### Scenario: Sandbox created

Given an authenticated `Launch`
And access policy allows sandbox creation
When sandbox creation runs
Then a `Sandbox` is created
And publish `SandboxCreated`.

### Scenario: Sandbox creation denied

Given a `Launch`
And access policy denies sandbox creation
When sandbox creation runs
Then no `Sandbox` is created
And publish `AccessDenied`.

### Scenario: Sandbox creation fails

Given an authenticated `Launch`
And sandbox creation cannot complete
When sandbox creation runs
Then no ready `Sandbox` is recorded
And publish `SandboxCreationFailed`.

## Requirement: Run Runtime Command Within Workspace Boundary

A runtime command can run only within the workspace boundary.

### Scenario: Command is inside workspace

Given a `Sandbox`
And a runtime command inside the workspace boundary
When the runtime command is requested
Then the command is accepted for execution.

### Scenario: Command is outside workspace

Given a `Sandbox`
And a runtime command outside the workspace boundary
When the runtime command is requested
Then the command is rejected
And publish `AccessDenied`.
