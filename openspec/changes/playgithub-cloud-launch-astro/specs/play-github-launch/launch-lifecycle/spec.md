# Launch Lifecycle

## Requirement: Request Cloud Launch

A user can request a cloud launch for a valid `Launch Target`.

### Scenario: New launch is created

Given an authenticated user
And a valid `Launch Target`
And no active `Launch` exists for that user and `Launch Target`
When the user requests a cloud launch
Then a `Launch` is created with requested status
And publish `LaunchRequested`.

### Scenario: Existing launch is reused

Given an authenticated user
And an active `Launch` exists for the same user and `Launch Target`
When the user requests a cloud launch
Then the existing `Launch` is returned
And publish `ExistingLaunchReused`.

## Requirement: Advance Launch Step

A `Launch` advances only through valid lifecycle steps.

### Scenario: Step succeeds in expected order

Given a `Launch` waiting for the current step
When the current step succeeds
Then the `Launch` records the step success
And publish `LaunchStepSucceeded`.

### Scenario: Step attempts to skip lifecycle order

Given a `Launch` waiting for the current step
When a later step is reported as succeeded
Then the `Launch` rejects the transition
And the `Launch` remains unchanged.

### Scenario: Step fails with failure category

Given a `Launch` waiting for the current step
When the current step fails with a `FailureCategory`
Then the `Launch` records the failed step
And publish `LaunchStepFailed`.

## Requirement: Mark Launch Ready

A `Launch` becomes ready only when ready criteria are satisfied.

### Scenario: Ready criteria satisfied

Given a `Launch`
And the dev server has started
And the preview route has been configured
And the ready criteria are satisfied
When readiness is evaluated
Then the `Launch` becomes a `Ready Session`
And publish `LaunchReady`.

### Scenario: Ready criteria not satisfied

Given a `Launch`
And any required ready criterion is missing
When readiness is evaluated
Then the `Launch` is not marked ready.

## Requirement: Retry Failed Launch Step

A failed `Launch` can retry only from the last safe failed step.

### Scenario: Failed step is retryable

Given a `Launch` with a failed retryable step
When retry is requested
Then the `Launch` records a new attempt for that step
And publish `LaunchRetryRequested`.

### Scenario: Failed step is not retryable

Given a `Launch` with a failed non-retryable step
When retry is requested
Then the `Launch` rejects the retry
And the `Launch` remains failed.
